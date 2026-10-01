import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:chloris_engine/chloris_engine.dart';

JsRuntime createPlatformJsRuntime() => FlutterJsRuntime();
void disposePlatformJsRuntime(JsRuntime runtime) {}

@JS('eval')
external JSAny? _browserEval(String code);

@JS('globalThis')
external JSObject get _globalThis;

/// Web：浏览器 eval + 按次隔离的 `java.*` 绑定。
class FlutterJsRuntime implements JsRuntime {
  const FlutterJsRuntime();

  static const _lenient = LenientJsRuntime();
  static final Map<String, JsHostSession> _sessions = {};
  static int _seq = 0;
  static bool _hooked = false;

  static void _ensureHook() {
    if (_hooked) return;
    _hooked = true;
    _globalThis.setProperty(
      '__chlorisJava'.toJS,
      ((JSString hid, JSString method, JSString args) {
        try {
          final id = hid.toDart;
          final session = _sessions[id];
          if (session == null) return ''.toJS;
          final name = method.toDart;
          final raw = jsonDecode(args.toDart);
          final argv = raw is List ? raw.cast<Object?>() : const <Object?>[];
          return _dispatch(session, name, argv).toJS;
        } catch (_) {
          return ''.toJS;
        }
      }).toJS,
    );
  }

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
    // timeout 为尽力而为提示：浏览器 eval 无法从外部中断；保护由
    // JsHostBridge.evalWithDeadline 的 Future.timeout 承担。此处忽略。
    _ensureHook();
    final java = scope.variables['java'];
    final host = java is JavaHost ? java : null;
    final hid = 'h${++_seq}';
    final session = JsHostSession(host);
    _sessions[hid] = session;
    try {
      await session.prefetchLiterals(code);
      final vars = JsHostBridge.serialize(scope);
      Object? last;
      for (var pass = 0; pass < 3; pass++) {
        final script =
            '(function(){ ' +
            JsHostBridge.prelude(
              vars: vars,
              ajaxCache: session.cache,
              hid: hid,
            ) +
            '\n return (function(){ ' +
            code +
            '\n })(); })()';
        try {
          final res = _browserEval(script);
          last = res == null ? null : res.dartify();
        } catch (_) {
          last = null;
        }
        if (!await session.fulfill()) break;
      }
      if (last != null) return last;
      return _lenient.eval(code, scope);
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
