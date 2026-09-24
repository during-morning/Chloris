import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  Object? run(String code, [Map<String, Object?> extra = const {}]) {
    return LenientJsRuntime.interpretJs(
      code,
      JsScope(variables: extra),
    );
  }

  test('key concat', () {
    expect(
      run("'https://x.com?q='+key+'&p=1'", {'key': '三体'}),
      contains(Uri.encodeQueryComponent('三体')),
    );
  });

  test('result.replace', () {
    expect(run("result.replace('a','b')", {'result': 'a-a'}), 'b-b');
  });

  test('result.substring', () {
    expect(run('result.substring(1,3)', {'result': 'abcd'}), 'bc');
  });

  test('java.put/get', () async {
    final host = JavaHost(
      http: _NoHttp(),
      cookieStore: CookieStore(),
    );
    final rt = const LenientJsRuntime();
    await rt.eval("java.put('k','v')", JsScope(variables: {'java': host}));
    final got = await rt.eval("java.get('k')", JsScope(variables: {'java': host}));
    expect(got, 'v');
  });

  test('java.md5Encode', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final got = await const LenientJsRuntime().eval(
      "java.md5Encode('a')",
      JsScope(variables: {'java': host}),
    );
    expect(got, '0cc175b9c0f1b6a831c399e269772661');
  });

  test('java.md5Encode16', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final got = await const LenientJsRuntime().eval(
      "java.md5Encode16('a')",
      JsScope(variables: {'java': host}),
    );
    expect(got, 'c0f1b6a831c399e2');
  });

  test('java.base64Encode', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final got = await const LenientJsRuntime().eval(
      "java.base64Encode('a')",
      JsScope(variables: {'java': host}),
    );
    expect(got, 'YQ==');
  });

  test('java.base64Decode', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final got = await const LenientJsRuntime().eval(
      "java.base64Decode('YQ==')",
      JsScope(variables: {'java': host}),
    );
    expect(got, 'a');
  });

  test('java.sha256Encode', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final got = await const LenientJsRuntime().eval(
      "java.sha256Encode('a')",
      JsScope(variables: {'java': host}),
    );
    expect(
      got,
      'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
    );
  });

  test('java.getCookie', () async {
    final store = CookieStore();
    store.set('https://a.com', 'k=v; x=y');
    final host = JavaHost(http: _NoHttp(), cookieStore: store);
    final got = await const LenientJsRuntime().eval(
      "java.getCookie('https://a.com','k')",
      JsScope(variables: {'java': host}),
    );
    expect(got, 'v');
  });

  test('java.hexEncodeToString', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final got = await const LenientJsRuntime().eval(
      "java.hexEncodeToString('a')",
      JsScope(variables: {'java': host}),
    );
    expect(got, '61');
  });

  test('java.hexDecodeToString', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final got = await const LenientJsRuntime().eval(
      "java.hexDecodeToString('61')",
      JsScope(variables: {'java': host}),
    );
    expect(got, 'a');
  });

  test('encodeURIComponent(key)', () {
    final enc = Uri.encodeQueryComponent('a b');
    expect(run('encodeURIComponent(key)', {'key': 'a b'}).toString(), enc);
  });

  test('java.invoke dispatches md5 and put/get', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    expect(await host.invoke('md5Encode', ['a']), '0cc175b9c0f1b6a831c399e269772661');
    await host.invoke('put', ['k', 'v']);
    expect(await host.invoke('get', ['k']), 'v');
    expect(host.invokeSync('base64Encode', ['a']), 'YQ==');
  });

  test('JsHostSession fulfills dynamic ajax on the second pass', () async {
    final host = JavaHost(http: _AjaxHttp(), cookieStore: CookieStore());
    final session = JsHostSession(host);
    session.ajaxMiss('https://example.com/x');
    expect(session.ajaxHit('https://example.com/x'), isNull);
    expect(await session.fulfill(), isTrue);
    expect(session.ajaxHit('https://example.com/x'), 'hello');
    expect(session.pending, isEmpty);
  });

  test('java.ajax', () async {
    final host = JavaHost(http: _AjaxHttp(), cookieStore: CookieStore());
    final got = await const LenientJsRuntime().eval(
      "java.ajax('https://example.com/x')",
      JsScope(variables: {'java': host}),
    );
    expect(got, 'hello');
  });

  test('java.htmlFormatStr', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final got = await const LenientJsRuntime().eval(
      "java.htmlFormatStr('<p>hi</p>')",
      JsScope(variables: {'java': host}),
    );
    expect(got.toString(), contains('hi'));
    expect(got.toString(), isNot(contains('<p>')));
  });

  group('rule evaluators ride the async bridge', () {
    // These four are rule evaluators rather than network calls, but they are
    // just as async. They used to be absent from networkMethods, so _dispatch
    // handed them to invokeSync, which has no case for them and fell through
    // to `default: return ''` -- every book source using them silently
    // resolved to an empty string.
    test('networkMethods covers the four rule evaluators', () {
      for (final name in const [
        'getString',
        'getStringList',
        'getElement',
        'getElements',
      ]) {
        expect(JsHostSession.isNetwork(name), isTrue, reason: name);
      }
    });

    test('JsHostSession resolves getStringList on the second pass', () async {
      final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
      final rule = AnalyzeRule(jsRuntime: const NoJsRuntime(), javaHost: host)
        ..setContent('<ul><li>A</li><li>B</li></ul>');
      expect(host.analyzeRule, same(rule));

      final session = JsHostSession(host);
      final args = <Object?>['tag.li@text'];
      expect(session.objectHit('getStringList', args), isNull);
      session.objectMiss('getStringList', args);
      expect(session.pending, isNotEmpty);

      expect(await session.fulfill(), isTrue);
      final cached = session.objectHit('getStringList', args);
      expect(cached, isNotNull);
      expect(jsonDecode(cached!), ['A', 'B']);
    });

    test('encodeResult degrades parser nodes instead of throwing', () {
      // getElements yields parser nodes. jsonEncode used to throw on them, and
      // that exception escaped fulfill() and dropped the entire script into
      // the lenient fallback.
      final node = _FakeNode('<li>A</li>');
      expect(JsHostSession.encodeResult([node]), '["<li>A</li>"]');
      expect(JsHostSession.encodeResult({'a': node}), '{"a":"<li>A</li>"}');
      expect(JsHostSession.encodeResult('plain'), '"plain"');
      expect(JsHostSession.encodeResult(null), 'null');
    });
  });

  group('encodeURI matches Java URLEncoder', () {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());

    test('escapes reserved delimiters and uses + for space', () {
      // Legado-E names this encodeURI but implements URLEncoder.encode, so
      // / ? : & = are escaped rather than preserved.
      expect(host.encodeURI('a b/c?d=1&e'), 'a+b%2Fc%3Fd%3D1%26e');
    });

    test('keeps . - * _ unescaped like Java', () {
      expect(host.encodeURI('a.-*_'), 'a.-*_');
    });

    test('percent-encodes non-ASCII as UTF-8 bytes', () {
      expect(host.encodeURI('中'), '%E4%B8%AD');
    });

    test('empty stays empty', () {
      expect(host.encodeURI(''), '');
    });
  });
}

class _FakeNode {
  _FakeNode(this.markup);
  final String markup;
  @override
  String toString() => markup;
}

class _AjaxHttp implements HttpPort {
  @override
  Future<StrResponse> send(HttpRequestSpec spec) async =>
      StrResponse(url: spec.url, body: 'hello');

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async =>
      Uint8List(0);

  @override
  void cancelInFlight() {}
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
