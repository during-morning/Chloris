import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('looksLikeLoginWall matches captcha and login copy', () {
    expect(looksLikeLoginWall('<div>请登录后继续</div>'), isTrue);
    expect(looksLikeLoginWall('输入验证码'), isTrue);
    expect(looksLikeLoginWall('GeeTest widget'), isTrue);
    expect(looksLikeLoginWall('<html><body>目录</body></html>'), isFalse);
    expect(looksLikeLoginWall(null), isFalse);
    expect(looksLikeLoginWall(''), isFalse);
  });

  test('prepareWebViewDocument injects base, boot, and optional image proxy', () {
    final doc = prepareWebViewDocument(
      html:
          '<html><head></head><body><img src="https://cdn.example/c.jpg"></body></html>',
      baseUrl: 'https://book.example/path/',
      javaScript: 'document.title',
      sourceRegex: r'\.jpg$',
      proxyImages: true,
      messageId: 'wv1',
    );
    expect(doc, contains('<base href="https://book.example/path/">'));
    expect(doc, contains('chloris-wv-done'));
    expect(doc, contains('wv1'));
    expect(doc, contains('/proxy/img?u='));
    expect(doc, contains('document.title'));
  });

  test('prepareWebViewDocument wraps fragment and interactive boot', () {
    final doc = prepareWebViewDocument(
      html: '<form action="/login"></form>',
      baseUrl: 'https://a.com',
      interactive: true,
      messageId: 'in1',
    );
    expect(doc, contains('<base href="https://a.com">'));
    expect(doc, contains('chloris-wv-submit'));
    expect(doc, contains('chloris-wv-nav'));
    expect(doc, contains('in1'));
  });

  test('sourceByOrigin matches exact url then unique host', () {
    final a = BookSource(bookSourceUrl: 'https://a.com', bookSourceName: 'A');
    final b = BookSource(
      bookSourceUrl: 'https://b.com/src',
      bookSourceName: 'B',
    );
    final c = BookSource(
      bookSourceUrl: 'https://dup.com/one',
      bookSourceName: 'C1',
    );
    final d = BookSource(
      bookSourceUrl: 'https://dup.com/two',
      bookSourceName: 'C2',
    );
    final all = [a, b, c, d];
    expect(sourceByOrigin(all, 'https://a.com')?.bookSourceName, 'A');
    expect(sourceByOrigin(all, 'https://b.com/other')?.bookSourceName, 'B');
    expect(sourceByOrigin(all, 'https://dup.com/x'), isNull);
    expect(sourceByOrigin(all, ''), isNull);
    expect(sourceByOrigin(all, null), isNull);
  });

  test(
    'AnalyzeUrl evaluates through WebViewPort when sourceRegex is set',
    () async {
      final port = _RecordingPort();
      port.result = const WebViewResult(
        body: 'WV_BODY',
        url: 'https://a.com/x',
        cookie: 'k=v',
      );
      final analyze = AnalyzeUrl(
        mUrl: 'https://a.com/x',
        http: _HtmlHttp('<html>raw</html>'),
        jsRuntime: const LenientJsRuntime(),
        source: BookSource(bookSourceUrl: 'https://a.com'),
        cookieStore: CookieStore(),
        webViewPort: port,
      );
      final res = await analyze.getStrResponse(sourceRegex: r'\.jpg$');
      expect(port.calls, isNotEmpty);
      expect(port.calls.first.interactive, isFalse);
      expect(res.body, 'WV_BODY');
      expect(analyze.cookieStore!.get('https://a.com'), contains('k=v'));
    },
  );

  test('login wall opens interactive WebView once', () async {
    final port = _RecordingPort();
    port.result = const WebViewResult(
      body: '<html>ok</html>',
      url: 'https://a.com/login',
      cookie: 'session=1',
    );
    final cookies = CookieStore();
    final analyze = AnalyzeUrl(
      mUrl: 'https://a.com/list',
      http: _HtmlHttp('<html>请登录后继续</html>'),
      jsRuntime: const LenientJsRuntime(),
      source: BookSource(
        bookSourceUrl: 'https://a.com',
        loginUrl: 'https://a.com/login',
      ),
      cookieStore: cookies,
      webViewPort: port,
      allowInteractiveLogin: true,
    );
    final res = await analyze.getStrResponse();
    expect(port.calls.single.interactive, isTrue);
    expect(port.calls.single.url, 'https://a.com/login');
    expect(res.body, '<html>ok</html>');
    expect(cookies.get('https://a.com'), contains('session=1'));
  });

  test('search path does not open interactive login by default', () async {
    final port = _RecordingPort();
    port.result = const WebViewResult(
      body: '<html>ok</html>',
      url: 'https://a.com/login',
      cookie: 'session=1',
    );
    final analyze = AnalyzeUrl(
      mUrl: 'https://a.com/list',
      http: _HtmlHttp('<html>请登录后继续</html>'),
      jsRuntime: const LenientJsRuntime(),
      source: BookSource(
        bookSourceUrl: 'https://a.com',
        loginUrl: 'https://a.com/login',
      ),
      cookieStore: CookieStore(),
      webViewPort: port,
    );
    final res = await analyze.getStrResponse();
    expect(port.calls, isEmpty);
    expect(res.body, contains('请登录'));
  });

  test(
    'loginCheckJs preserves response when JS stringifies it as an object',
    () async {
      final analyze = AnalyzeUrl(
        mUrl: 'https://a.com/list',
        http: _HtmlHttp('<html>raw</html>'),
        jsRuntime: const _ObjectStringRuntime(),
        source: BookSource(
          bookSourceUrl: 'https://a.com',
          loginCheckJs: 'result',
        ),
      );
      final res = await analyze.getStrResponse();
      expect(res.body, '<html>raw</html>');
    },
  );
}

class _ObjectStringRuntime implements JsRuntime {
  const _ObjectStringRuntime();

  @override
  Future<Object?> eval(String code, JsScope scope, {Duration? timeout}) async => '[object Object]';

  @override
  Future<String> evalToString(String code, JsScope scope) async =>
      '[object Object]';
}

class _RecordingPort implements WebViewPort {
  final calls = <WebViewRequest>[];
  WebViewResult? result;

  @override
  Future<WebViewResult?> run(WebViewRequest request) async {
    calls.add(request);
    return result;
  }
}

class _HtmlHttp implements HttpPort {
  _HtmlHttp(this.html);
  final String html;

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    return StrResponse(url: spec.url, body: html);
  }

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async {
    return Uint8List(0);
  }

  @override
  void cancelInFlight() {}
}
