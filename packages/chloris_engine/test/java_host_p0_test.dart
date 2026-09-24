import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  JavaHost host({
    HttpPort? http,
    RuleData? ruleData,
    Book? book,
    BookChapter? chapter,
    BookSource? source,
    WebViewPort? webView,
    JsRuntime? jsRuntime,
  }) {
    final h = JavaHost(
      http: http ?? _NoHttp(),
      cookieStore: CookieStore(),
      jsRuntime: jsRuntime,
      source: source,
      book: book,
      chapter: chapter,
      ruleData: ruleData,
      webViewPort: webView,
    );
    if (ruleData != null || source != null || book != null) {
      AnalyzeRule(
          jsRuntime: jsRuntime ?? const NoJsRuntime(),
          ruleData: ruleData,
          source: source,
          javaHost: h,
        )
        ..setBook(book)
        ..setChapter(chapter);
    }
    return h;
  }

  test('put/get via RuleData', () async {
    final data = RuleData();
    final h = host(ruleData: data);
    await h.invoke('put', ['token', 'abc']);
    expect(data.get('token'), 'abc');
    expect(await h.invoke('get', ['token']), 'abc');
    expect(h.get('token'), 'abc');
  });

  test('put/get chain chapter then book then ruleData', () {
    final data = RuleData();
    data.put('k', 'fromRule');
    final book = Book(bookUrl: 'b', name: '仙逆');
    book.putVariable('k', 'fromBook');
    final chapter = BookChapter(url: 'c', title: '第一章');
    final h = host(ruleData: data, book: book, chapter: chapter);
    expect(h.get('k'), 'fromBook');
    h.put('k', 'fromChapter');
    expect(chapter.getVariable('k'), 'fromChapter');
    expect(h.get('k'), 'fromChapter');
    expect(h.get('bookName'), '仙逆');
    expect(h.get('title'), '第一章');
  });

  test('encodeURI', () async {
    final h = host();
    // Legado-E names this encodeURI but implements Java's URLEncoder.encode,
    // so a space becomes '+' rather than '%20'.
    expect(h.encodeURI('a b'), 'a+b');
    expect(await h.invoke('encodeURI', ['仙逆']), '%E4%BB%99%E9%80%86');
  });

  test('encodeURI escapes URI delimiters like URLEncoder', () {
    final h = host();
    // JS encodeURI would preserve / ? : & = #. Legado's implementation does
    // not, and book sources build query strings on that assumption, so
    // following the JS spec here silently yields a different URL.
    expect(
      h.encodeURI('https://example.com/a?q=中 文&x=1#p'),
      'https%3A%2F%2Fexample.com%2Fa%3Fq%3D%E4%B8%AD+%E6%96%87%26x%3D1%23p',
    );
  });

  test('encodeURI keeps Java-safe characters unescaped', () {
    final h = host();
    // URLEncoder leaves A-Za-z0-9 and . - * _ alone.
    expect(h.encodeURI('aZ0.-*_'), 'aZ0.-*_');
    // Characters Dart's encodeQueryComponent keeps but Java escapes.
    expect(h.encodeURI("!'()~"), '%21%27%28%29%7E');
    expect(h.encodeURI(''), '');
  });

  test('toNumChapter', () {
    final h = host();
    expect(h.toNumChapter('第十二章 起'), '第12章 起');
    expect(h.toNumChapter('第3章'), '第3章');
    expect(h.toNumChapter('前言'), '前言');
  });

  test('t2s and s2t', () async {
    final h = host();
    expect(h.t2s('中國'), '中国');
    expect(h.s2t('阅读'), '閱讀');
    expect(await h.invoke('t2s', ['閱讀']), '阅读');
  });

  test('randomUUID', () async {
    final h = host();
    final u = await h.invoke('randomUUID', []);
    expect(
      u,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(h.randomUUID(), isNot(h.randomUUID()));
  });

  test('unknown invoke logs java.missing and returns empty', () async {
    DebugLog.clear();
    final h = host();
    expect(await h.invoke('definitelyMissing', ['x']), '');
    expect(DebugLog.forTag('java.missing.definitelyMissing'), isNotEmpty);
  });

  test('connect returns body and code', () async {
    final h = host(http: _AjaxHttp(), jsRuntime: const LenientJsRuntime());
    final res = await h.invoke('connect', ['https://example.com/x']);
    expect(res, isA<Map>());
    final map = res as Map;
    expect(map['body'], 'hello');
    expect(map['code'], 200);
  });

  test('ajax inherits source header through AnalyzeUrl', () async {
    final http = _RecordingHttp();
    final h = host(
      http: http,
      jsRuntime: const LenientJsRuntime(),
      source: BookSource(
        bookSourceUrl: 'https://ex.com',
        header: '{"X-Test":"1"}',
      ),
    );
    expect(await h.ajax('https://ex.com/a'), 'ok');
    expect(http.lastHeaders['X-Test'], '1');
  });

  test('webView without port logs missing and returns empty', () async {
    DebugLog.clear();
    final h = host();
    expect(await h.webView('<p>x</p>', 'https://ex.com', 'document.body'), '');
    expect(DebugLog.forTag('java.missing.webView'), isNotEmpty);
  });

  test('androidId is a stable placeholder', () async {
    final h = host();
    expect(h.androidId(), 'chloris0000000000');
    expect(await h.invoke('androidId', []), 'chloris0000000000');
    expect(h.invokeSync('androidId', []), 'chloris0000000000');
  });

  test('getZipStringContent extracts a named file from zip bytes', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('inner.txt', 5, utf8.encode('hello')));
    final zip = ZipEncoder().encode(archive)!;
    final h = host();
    expect(
      await h.getZipStringContent(base64Encode(zip), 'inner.txt'),
      'hello',
    );
    expect(
      await h.invoke('getZipStringContent', [base64Encode(zip), 'inner.txt']),
      'hello',
    );
    final bytes = await h.getZipByteArrayContent(base64Encode(zip), 'inner.txt');
    expect(utf8.decode(bytes!), 'hello');
  });

  test('webViewGetSource sniffs a matching URL from html', () async {
    final h = host();
    final html =
        '<html><script src="https://cdn.ex/app.js"></script>'
        '<a href="https://cdn.ex/play.m3u8">play</a></html>';
    expect(
      await h.webViewGetSource(html, null, null, r'.*\.m3u8$'),
      'https://cdn.ex/play.m3u8',
    );
    expect(
      await h.invoke('webViewGetOverrideUrl', [html, '', '', r'.*\.m3u8$']),
      'https://cdn.ex/play.m3u8',
    );
  });
}

class _AjaxHttp implements HttpPort {
  @override
  Future<StrResponse> send(HttpRequestSpec spec) async =>
      StrResponse(url: spec.url, body: 'hello');

  @override
  Future<Uint8List> getBytes(
    String url, {
    Map<String, String>? headers,
  }) async => Uint8List(0);

  @override
  void cancelInFlight() {}
}

class _RecordingHttp implements HttpPort {
  Map<String, String> lastHeaders = const {};

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    lastHeaders = spec.headers;
    return StrResponse(url: spec.url, body: 'ok');
  }

  @override
  Future<Uint8List> getBytes(
    String url, {
    Map<String, String>? headers,
  }) async => Uint8List(0);

  @override
  void cancelInFlight() {}
}

class _NoHttp implements HttpPort {
  @override
  Future<StrResponse> send(HttpRequestSpec spec) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> getBytes(
    String url, {
    Map<String, String>? headers,
  }) async => throw UnimplementedError();

  @override
  void cancelInFlight() {}
}
