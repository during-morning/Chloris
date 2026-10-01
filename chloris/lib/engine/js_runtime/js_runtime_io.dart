import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_js/flutter_js.dart';

import '../../core/http/http_session.dart';

JsRuntime createPlatformJsRuntime() =>
    Platform.isMacOS ? MacIsolatedJsRuntime() : FlutterJsRuntime();

void disposePlatformJsRuntime(JsRuntime runtime) {
  if (runtime is MacIsolatedJsRuntime) unawaited(runtime.dispose());
}

/// flutter_js（QuickJS / JavaScriptCore）+ `java.*` 真绑定。
class FlutterJsRuntime implements JsRuntime {
  static const _undefinedMarker = '__CHLORIS_UNDEFINED_RESULT_7E6A__';

  FlutterJsRuntime() : _rt = getJavascriptRuntime() {
    _rt.onMessage('chlorisJava', (args) {
      try {
        final map = args is String
            ? jsonDecode(args)
            : args is Map
            ? args
            : jsonDecode(args.toString());
        if (map is! Map) return '';
        final id = map['id']?.toString() ?? '';
        final session = _sessions[id];
        if (session == null) return '';
        final name = map['m']?.toString() ?? '';
        final raw = map['a'];
        final argv = raw is List ? raw.cast<Object?>() : const <Object?>[];
        return _dispatch(session, name, argv);
      } catch (_) {
        return '';
      }
    });
  }

  final JavascriptRuntime _rt;
  final LenientJsRuntime _lenient = const LenientJsRuntime();
  final Map<String, JsHostSession> _sessions = {};
  int _seq = 0;

  static String _dispatch(
    JsHostSession session,
    String name,
    List<Object?> argv,
  ) {
    if (name == 'ajax') {
      final url = argv.isEmpty ? '' : argv.first.toString();
      final hit = session.ajaxHit(url);
      if (hit != null) return hit;
      session.ajaxMiss(url);
      return '';
    }
    if (JsHostSession.isNetwork(name) && name != 'ajax') {
      final hit = session.objectHit(name, argv);
      if (hit != null) return hit;
      session.objectMiss(name, argv);
      return '';
    }
    final host = session.host;
    if (host == null) return '';
    return (host.invokeSync(name, argv) ?? '').toString();
  }

  @override
  Future<Object?> eval(String code, JsScope scope, {Duration? timeout}) async {
    // flutter_js exposes native string results through a null-terminated C
    // buffer, so an empty JS string is indistinguishable from no result.
    final expression = code.trim();
    if (expression == "''" || expression == '""') return '';
    if (expression == 'undefined') return scope.variables['result'];
    // timeout 是尽力而为的提示：flutter_js 的 QuickJS 绑定不暴露
    // VM 级中断（deadline/interrupt handler），无法在 Dart 侧强制取消。
    // 调用方的保护由 JsHostBridge.evalWithDeadline 的 Future.timeout 承担
    // （到点释放调用方并打 js_deadline 告警），此处忽略该参数。
    final java = scope.variables['java'];
    final host = java is JavaHost ? java : null;
    final hid = 'h${++_seq}';
    final session = JsHostSession(host);
    _sessions[hid] = session;
    try {
      await session.prefetchLiterals(code);
      final vars = JsHostBridge.serialize(scope);
      Object? last;
      var sawError = false;
      for (var pass = 0; pass < 3; pass++) {
        final script =
            '${JsHostBridge.prelude(vars: vars, ajaxCache: session.cache, hid: hid)}\nvar __chlorisEvalResult = eval(${jsonEncode(code)});\n'
            'typeof __chlorisEvalResult === "undefined" ? '
            '"$_undefinedMarker" : __chlorisEvalResult';
        try {
          final res = _rt.evaluate(script, sourceUrl: 'rule.js');
          if (res.isError) {
            sawError = true;
            last = null;
          } else {
            sawError = false;
            final str = res.stringResult;
            last = str == _undefinedMarker ? null : str;
          }
        } catch (_) {
          sawError = true;
          last = null;
        }
        if (!await session.fulfill()) break;
      }
      if (!sawError && last != null) return last;
      return await _lenient.eval(code, scope);
    } catch (_) {
      return _lenient.eval(code, scope);
    } finally {
      _sessions.remove(hid);
    }
  }

  @override
  Future<String> evalToString(String code, JsScope scope) async =>
      (await eval(code, scope))?.toString() ?? '';
}

/// Runs macOS rule JavaScript in two isolated JavaScriptCore processes. A
/// timed-out evaluation kills its process, so a synchronous infinite loop can
/// neither pin Flutter's UI isolate nor poison the next evaluation.
class MacIsolatedJsRuntime implements JsRuntime, JsSessionLifecycle {
  MacIsolatedJsRuntime({String? helperPath, this.processCount = 2})
    : _helperPath = helperPath ?? _bundledHelperPath() {
    if (processCount < 1)
      throw ArgumentError.value(processCount, 'processCount');
    _workers = List.generate(
      processCount,
      (_) => _JavaScriptHelper(_helperPath),
    );
  }

  final String _helperPath;
  final int processCount;
  late final List<_JavaScriptHelper> _workers;
  final LenientJsRuntime _lenient = const LenientJsRuntime();
  final Map<String, JsHostSession> _sessions = {};
  int _sequence = 0;
  bool _disposed = false;

  final _operationWorkers = <String, Set<_JavaScriptHelper>>{};
  final _cancelled = <String>{};
  @override
  void cancelSession(String id) {
    _cancelled.add(id);
    if (_cancelled.length > 1024) _cancelled.remove(_cancelled.first);
    for (final worker in _operationWorkers[id] ?? <_JavaScriptHelper>{}) {
      unawaited(worker.terminate());
    }
  }

  static String _bundledHelperPath() {
    final executable = File(Platform.resolvedExecutable).absolute;
    final contents = executable.parent.parent;
    return contents.uri.resolve('Helpers/chloris-js').toFilePath();
  }

  @override
  Future<Object?> eval(String code, JsScope scope, {Duration? timeout}) async {
    if (_disposed) throw StateError('macOS JS runtime 已释放');
    final expression = code.trim();
    if (expression == "''" || expression == '""') return '';
    if (expression == 'undefined') return scope.variables['result'];
    final deadline = timeout ?? const Duration(seconds: 15);
    final deadlineAt = DateTime.now().add(deadline);
    final watch = Stopwatch()..start();
    final java = scope.variables['java'];
    final session = JsHostSession(java is JavaHost ? java : null);
    final hid = 'mac-${++_sequence}';
    _sessions[hid] = session;
    final sessionId = HttpSession.current ?? '';
    final background = isBackgroundHttpSession(sessionId);
    final worker = _workers[background && _workers.length > 1 ? 1 : 0];
    if (_cancelled.contains(sessionId)) throw StateError('JS 操作已取消');
    _operationWorkers.putIfAbsent(sessionId, () => {}).add(worker);
    try {
      await session.prefetchLiterals(code).timeout(deadline);
      final vars = JsHostBridge.serialize(scope);
      Object? last;
      var sawError = false;
      for (var pass = 0; pass < 3; pass++) {
        final remaining = deadline - watch.elapsed;
        if (remaining <= Duration.zero) {
          throw TimeoutException('JS execution deadline expired', deadline);
        }
        final script =
            '${JsHostBridge.prelude(vars: vars, ajaxCache: session.cache, hid: hid)}\n'
            'var __chlorisEvalResult = eval(${jsonEncode(code)});\n'
            'typeof __chlorisEvalResult === "undefined" ? "${FlutterJsRuntime._undefinedMarker}" : __chlorisEvalResult';
        final result = await worker.evaluate(
          script,
          deadline: deadlineAt,
          onHostCall: _answerHostCall,
        );
        if (!result.ok) {
          sawError = true;
          last = null;
        } else {
          sawError = false;
          last = result.value == FlutterJsRuntime._undefinedMarker
              ? null
              : result.value;
        }
        final fulfillRemaining = deadline - watch.elapsed;
        if (!await session.fulfill().timeout(
          fulfillRemaining.isNegative ? Duration.zero : fulfillRemaining,
        )) {
          break;
        }
      }
      if (!sawError && last != null) return last;
      return await _lenient.eval(code, scope);
    } on TimeoutException {
      rethrow;
    } finally {
      _sessions.remove(hid);
      _operationWorkers[sessionId]?.remove(worker);
      if (_operationWorkers[sessionId]?.isEmpty == true)
        _operationWorkers.remove(sessionId);
    }
  }

  void _answerHostCall(
    _JavaScriptHelper worker,
    String evaluationId,
    String payload,
  ) {
    String value = '';
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final hid = decoded['id']?.toString() ?? '';
        final session = _sessions[hid];
        if (session != null) {
          final method = decoded['m']?.toString() ?? '';
          final rawArgs = decoded['a'];
          final args = rawArgs is List
              ? rawArgs.cast<Object?>()
              : const <Object?>[];
          value = FlutterJsRuntime._dispatch(session, method, args);
        }
      }
    } catch (_) {}
    worker.respond(evaluationId, value);
  }

  Future<void> dispose() async {
    _disposed = true;
    await Future.wait(_workers.map((worker) => worker.terminate()));
    _sessions.clear();
  }

  @override
  Future<String> evalToString(String code, JsScope scope) async =>
      (await eval(code, scope))?.toString() ?? '';
}

class _JavaScriptHelperResult {
  const _JavaScriptHelperResult(this.ok, this.value);
  final bool ok;
  final String value;
}

class _JavaScriptHelper {
  _JavaScriptHelper(this.path);

  final String path;
  Process? _process;
  StreamSubscription<String>? _stdout;
  StreamSubscription<String>? _stderr;
  Completer<_JavaScriptHelperResult>? _result;
  String? _activeId;
  Timer? _deadline;
  Future<void> _writes = Future<void>.value();
  Future<void> _evaluationQueue = Future<void>.value();

  Future<Process> _start() async {
    final active = _process;
    if (active != null) return active;
    if (!await File(path).exists()) {
      throw StateError('找不到已嵌入的 macOS JS helper: $path');
    }
    final process = await Process.start(path, const [], runInShell: false);
    _process = process;
    _stdout = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _onLine,
          onError: (Object error, StackTrace stack) {
            _fail(error);
          },
        );
    _stderr = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((_) {});
    unawaited(
      process.exitCode.then((code) {
        if (identical(_process, process)) {
          _process = null;
          _fail(StateError('macOS JS helper exited with status $code'));
        }
      }),
    );
    return process;
  }

  Future<_JavaScriptHelperResult> evaluate(
    String script, {
    required DateTime deadline,
    required void Function(_JavaScriptHelper, String, String) onHostCall,
  }) {
    final result = Completer<_JavaScriptHelperResult>();
    var expiredWhileQueued = false;
    final remainingAtEnqueue = deadline.difference(DateTime.now());
    final queuedDeadline = Timer(
      remainingAtEnqueue.isNegative ? Duration.zero : remainingAtEnqueue,
      () {
        expiredWhileQueued = true;
        if (!result.isCompleted) {
          result.completeError(
            TimeoutException(
              'macOS JavaScript evaluation timed out',
              remainingAtEnqueue,
            ),
          );
        }
      },
    );
    _evaluationQueue = _evaluationQueue.catchError((Object _) {}).then((
      _,
    ) async {
      if (expiredWhileQueued || result.isCompleted) return;
      queuedDeadline.cancel();
      try {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw TimeoutException(
            'macOS JavaScript evaluation timed out',
            remaining,
          );
        }
        final value = await _evaluateNow(
          script,
          timeout: remaining,
          onHostCall: onHostCall,
        );
        if (!result.isCompleted) result.complete(value);
      } catch (error, stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<_JavaScriptHelperResult> _evaluateNow(
    String script, {
    required Duration timeout,
    required void Function(_JavaScriptHelper, String, String) onHostCall,
  }) async {
    final process = await _start();
    if (_result != null)
      throw StateError('JS helper already has an active evaluation');
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
    final completer = Completer<_JavaScriptHelperResult>();
    _result = completer;
    _activeId = id;
    _deadline = Timer(timeout, () {
      if (identical(_result, completer)) {
        _fail(
          TimeoutException('macOS JavaScript evaluation timed out', timeout),
        );
        unawaited(terminate());
      }
    });
    _onHostCall = onHostCall;
    try {
      await _write(process, {
        'version': 1,
        'action': 'evaluate',
        'id': id,
        'script': script,
      });
      return await completer.future;
    } finally {
      if (identical(_result, completer)) {
        _deadline?.cancel();
        _deadline = null;
        _result = null;
        _activeId = null;
        _onHostCall = null;
      }
    }
  }

  void Function(_JavaScriptHelper, String, String)? _onHostCall;

  void _onLine(String line) {
    final activeId = _activeId;
    if (activeId == null) return;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map || decoded['version'] != 1) return;
      final id = decoded['id']?.toString();
      if (id != activeId) return;
      switch (decoded['type']) {
        case 'host':
          _onHostCall?.call(
            this,
            activeId,
            decoded['payload']?.toString() ?? '',
          );
        case 'result':
          final ok = decoded['ok'] == true;
          _complete(
            _JavaScriptHelperResult(ok, decoded['value']?.toString() ?? ''),
          );
        case 'protocolError':
          _fail(
            StateError(
              decoded['message']?.toString() ?? 'JS helper protocol error',
            ),
          );
      }
    } catch (error) {
      _fail(StateError('Invalid JS helper response: $error'));
    }
  }

  void respond(String evaluationId, String value) {
    final process = _process;
    if (process == null || evaluationId != _activeId) return;
    unawaited(
      _write(process, {
        'version': 1,
        'type': 'hostResult',
        'id': evaluationId,
        'value': value,
      }),
    );
  }

  Future<void> _write(Process process, Map<String, Object?> message) {
    final bytes = utf8.encode('${jsonEncode(message)}\n');
    final next = _writes.then((_) async {
      if (!identical(_process, process))
        throw StateError('JS helper was restarted');
      process.stdin.add(bytes);
      await process.stdin.flush();
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  void _complete(_JavaScriptHelperResult value) {
    final completer = _result;
    if (completer == null || completer.isCompleted) return;
    _deadline?.cancel();
    _deadline = null;
    completer.complete(value);
  }

  void _fail(Object error) {
    final completer = _result;
    if (completer != null && !completer.isCompleted) {
      _deadline?.cancel();
      _deadline = null;
      completer.completeError(error);
    }
  }

  Future<void> terminate() async {
    final process = _process;
    _process = null;
    _deadline?.cancel();
    _deadline = null;
    _fail(StateError('macOS JS helper terminated'));
    await _stdout?.cancel();
    await _stderr?.cancel();
    _stdout = null;
    _stderr = null;
    if (process != null) {
      process.kill(ProcessSignal.sigkill);
      try {
        await process.exitCode.timeout(const Duration(seconds: 1));
      } catch (_) {}
    }
  }
}
