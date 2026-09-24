import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

/// Captures the scope the engine builds, without running any JavaScript.
class _Capture implements JsRuntime {
  JsScope? lastScope;
  String? lastCode;

  @override
  Future<Object?> eval(String code, JsScope scope, {Duration? timeout}) async {
    lastScope = scope;
    lastCode = code;
    return null;
  }

  @override
  Future<String> evalToString(String code, JsScope scope) async {
    lastScope = scope;
    lastCode = code;
    return '';
  }
}

void main() {
  group('rule scope bindings', () {
    test('every variable Legado exposes is present', () async {
      final rt = _Capture();
      final rule = AnalyzeRule(jsRuntime: rt)
        ..setContent('<p>x</p>', 'https://e.test/1');
      await rule.evalJs('result', 'v');

      final vars = rt.lastScope!.variables;
      for (final name in const [
        'result',
        'baseUrl',
        'book',
        'chapter',
        'source',
        'src',
        'cookie',
        'nextChapterUrl',
        'fromBookInfo',
        'key',
        'page',
        'java',
        // Previously missing: a script referencing any of these raised
        // ReferenceError, which the runtime swallowed into "return the input".
        'title',
        'rssArticle',
        'speakText',
        'speakSpeed',
        'infoMap',
      ]) {
        expect(vars.containsKey(name), isTrue, reason: 'missing binding: $name');
      }
    });

    test('the newly bound variables are empty rather than undefined', () async {
      final rt = _Capture();
      final rule = AnalyzeRule(jsRuntime: rt)..setContent('<p>x</p>');
      await rule.evalJs('result', 'v');
      final vars = rt.lastScope!.variables;
      expect(vars['speakText'], '');
      expect(vars['speakSpeed'], '');
      expect(vars['infoMap'], isEmpty);
      expect(vars['rssArticle'], isNull);
      expect(vars['title'], '');
    });
  });

  group('cache facade', () {
    test('the prelude defines the full CacheManager surface', () {
      final prelude = JsHostBridge.prelude(vars: const {});
      for (final method in const [
        'put',
        'get',
        'delete',
        'putMemory',
        'getFromMemory',
        'deleteMemory',
        'putFile',
        'getFile',
      ]) {
        expect(prelude, contains('$method: function'), reason: method);
      }
      expect(prelude, contains('var cache = {'));
    });

    test('cache round-trips through the host', () {
      final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
      expect(host.cacheGet('missing'), '');
      // ⚠️ 第二参是 onlyDisk 布尔量，**不是**默认值（Legado CacheManager.kt:98）。
      // 旧实现把它当默认值，本测试曾断言 `cacheGet('missing','fallback') ==
      // 'fallback'`。那是 Chloris 独有语义，与 Legado 书源不兼容，已按 P2 修正：
      // 传非 true 的第二参不再被当作缺省值。
      expect(host.cacheGet('missing', 'fallback'), '');
      expect(host.cachePut('k', 'v'), 'v');
      expect(host.cacheGet('k'), 'v');
      expect(host.cacheDelete('k'), '');
      expect(host.cacheGet('k'), '');
    });

    test('onlyDisk 只读 disk 层，deleteMemory 之后 get 仍能从 disk 层命中', () {
      final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
      // put 同时落内存层与 disk 层（CacheManager.kt:58-70）。
      host.cachePut('k', 'v');
      expect(host.cacheGet('k'), 'v');
      expect(host.cacheGet('k', true), 'v');
      // deleteMemory 只清内存层，disk 层仍在 —— 与 Legado 的 get(key) 回退一致。
      host.cacheDeleteMemory('k');
      expect(host.cacheGetFromMemory('k'), '');
      expect(host.cacheGet('k'), 'v');
      // putMemory 只写内存层，不影响 disk 层。
      host.cachePutMemory('m', 'mem');
      expect(host.cacheGetFromMemory('m'), 'mem');
      expect(host.cacheGet('m', true), '');
    });

    test('cache is not the same store as java.put/get', () {
      final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
      host.cachePut('shared', 'from-cache');
      host.put('shared', 'from-vars');
      expect(host.cacheGet('shared'), 'from-cache');
      expect(host.get('shared'), 'from-vars');
    });

    test('cache methods are reachable through invokeSync', () {
      final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
      expect(host.invokeSync('cachePut', ['a', 'b']), 'b');
      expect(host.invokeSync('cacheGet', ['a']), 'b');
      expect(host.invokeSync('cacheGetFromMemory', ['nope']), '');
      expect(host.invokeSync('cacheDeleteMemory', ['a']), '');
      expect(host.invokeSync('cacheGet', ['a']), 'b'); // disk 层仍在
      expect(host.invokeSync('cacheDelete', ['a']), '');
      expect(host.invokeSync('cacheGet', ['a']), '');
      // cache.put 第三参是 saveTime（秒），0 表示不过期。
      expect(host.invokeSync('cachePut', ['t', 'x', 60]), 'x');
      expect(host.invokeSync('cacheGet', ['t', true]), 'x');
    });
  });

  group('degradation reporting', () {
    tearDown(() {
      LenientJsRuntime.onDegrade = null;
      LenientJsRuntime.strict = true;
    });

    test('unsupported JS throws instead of quietly returning the input', () {
      final events = <JsDegradation>[];
      LenientJsRuntime.onDegrade = events.add;

      // Not one of the interpreter's supported shapes. It used to come back
      // unchanged, so the caller cached the unevaluated input as content.
      expect(
        () => LenientJsRuntime.interpretJs(
          r"result.split('/').map(x => x.trim())",
          JsScope(variables: const {'result': 'a/b'}),
        ),
        throwsA(
          isA<DomainError>().having(
            (e) => e.code,
            'code',
            'js_unsupported',
          ),
        ),
      );
      expect(events, hasLength(1));
      expect(events.single.code, 'js_unsupported');
      expect(events.single.rule, contains('split'));
    });

    test('non-strict mode keeps the old best-effort return', () {
      LenientJsRuntime.strict = false;
      final out = LenientJsRuntime.interpretJs(
        r"result.split('/').map(x => x.trim())",
        JsScope(variables: const {'result': 'a/b'}),
      );
      expect(out, 'a/b');
    });

    test('a supported shape reports nothing and does not throw', () {
      final events = <JsDegradation>[];
      LenientJsRuntime.onDegrade = events.add;
      final out = LenientJsRuntime.interpretJs(
        'result.substring(1,3)',
        JsScope(variables: const {'result': 'abcd'}),
      );
      expect(out, 'bc');
      expect(events, isEmpty);
    });
  });
}

class _NoHttp implements HttpPort {
  @override
  Future<StrResponse> send(HttpRequestSpec spec) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async =>
      throw UnimplementedError();

  @override
  void cancelInFlight() {}
}
