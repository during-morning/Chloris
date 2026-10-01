import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Lazy Chromium service. Every operation owns an isolated BrowserContext.
class BrowserWorker {
  BrowserWorker({this.scriptPath, this.nodePath = 'node'});
  final String? scriptPath;
  final String nodePath;
  Process? _process;
  Future<Process>? _starting;
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  Future<Process> _ensure() => _starting ??= _start().catchError((Object e) {
    _starting = null;
    throw e;
  });
  Future<Process> _start() async {
    final path =
        scriptPath ??
        Platform.environment['CHLORIS_BROWSER_WORKER'] ??
        'tool/browser_worker/worker.mjs';
    if (!await File(path).exists())
      throw UnsupportedError('未安装 Chromium 解析服务，请配置 CHLORIS_BROWSER_WORKER');
    final process = _process = await Process.start(nodePath, [path]);
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          try {
            final data = jsonDecode(line) as Map<String, dynamic>;
            if (data['v'] != 1) return;
            final pending = _pending.remove(data['id']);
            if (pending == null) return;
            if (data['error'] != null) {
              pending.completeError(StateError('${data['error']}'));
            } else {
              pending.complete(
                Map<String, dynamic>.from(data['result'] as Map),
              );
            }
          } catch (_) {}
        });
    process.stderr.drain<void>();
    unawaited(
      process.exitCode.then((code) {
        if (identical(_process, process)) {
          _process = null;
          _starting = null;
          for (final p in _pending.values) {
            p.completeError(StateError('Chromium 解析进程退出（$code）'));
          }
          _pending.clear();
        }
      }),
    );
    return process;
  }

  Future<Map<String, dynamic>> run(
    Map<String, dynamic> input, {
    bool allowPrivate = false,
  }) async {
    final process = await _ensure();
    final id = input['id'] as String;
    if (_pending.containsKey(id)) throw StateError('解析操作重复');
    if (_pending.length >= 2) throw StateError('解析服务繁忙，请稍后重试');
    final result = Completer<Map<String, dynamic>>();
    _pending[id] = result;
    process.stdin.writeln(
      jsonEncode({...input, 'v': 1, 'allowPrivate': allowPrivate}),
    );
    try {
      return await result.future.timeout(
        const Duration(seconds: 21),
        onTimeout: () {
          cancel(id);
          throw TimeoutException('网页解析超时');
        },
      );
    } finally {
      _pending.remove(id);
    }
  }

  void cancel(String id) {
    _process?.stdin.writeln(jsonEncode({'v': 1, 'type': 'cancel', 'id': id}));
    final p = _pending.remove(id);
    p?.completeError(StateError('网页解析已取消'));
  }

  Future<void> dispose() async {
    final p = _process;
    if (p == null) return;
    _process = null;
    _starting = null;
    await p.stdin.close();
    await p.exitCode.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        p.kill();
        return -1;
      },
    );
    for (final c in _pending.values) {
      c.completeError(StateError('解析服务已关闭'));
    }
    _pending.clear();
  }
}
