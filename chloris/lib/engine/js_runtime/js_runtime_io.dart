import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_js/flutter_js.dart';

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
