import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';

import 'proxy_http_port.dart';

/// 统一引擎入口：装配 HTTP、JS 运行时、Cookie 与 WebBook。
/// 纯 Dart（不依赖 Flutter），便于单测与跨平台复用。
class EngineFacade {
  EngineFacade({
    required this.http,
    JsRuntime? jsRuntime,
    CookieStore? cookieStore,
    this.webView,
    this.filePort = const UnsupportedFilePort(),
    this.hostEnvironment = const DefaultHostEnvironment(),
  }) : jsRuntime = jsRuntime ?? const NoJsRuntime(),
       cookieStore = cookieStore ?? CookieStore() {
    webBook = WebBook(
      http: http,
      jsRuntime: this.jsRuntime,
      cookieStore: this.cookieStore,
      webViewPort: webView,
      filePort: filePort,
      hostEnvironment: hostEnvironment,
    );
  }

  final WebViewPort? webView;
  final HttpPort http;
  final JsRuntime jsRuntime;
  final CookieStore cookieStore;

  /// Rule-script file access. The caller attaches a real port on platforms
  /// that have a file system; the default reports the capability as absent.
  final FilePort filePort;

  /// Platform interactions and settings exposed to rule scripts.
  final HostEnvironment hostEnvironment;
  late final WebBook webBook;

  /// Resolve a media rule without fetching the audio bytes. The player owns
  /// streaming and range requests; the engine supplies rule options/cookies.
  Future<
    ({String url, Map<String, String> headers, String method, String? body})
  >
  prepareAudioRequest(
    String url, {
    required BookSource source,
    required Book book,
    required BookChapter chapter,
    Map<String, String> headers = const {},
  }) async {
    final request = AnalyzeUrl(
      mUrl: url,
      http: http,
      jsRuntime: jsRuntime,
      source: source,
      book: book,
      chapter: chapter,
      baseUrl: chapter.baseUrl.isEmpty ? chapter.url : chapter.baseUrl,
      cookieStore: cookieStore,
      javaHost: webBook.javaHost,
      headerMapF: headers,
    );
    await request.init();
    final result = <String, String>{};
    for (final entry in request.headerMap.entries) {
      result.removeWhere(
        (key, _) => key.toLowerCase() == entry.key.toLowerCase(),
      );
      result[entry.key] = entry.value;
    }
    final cookiePairs = <String, String>{};
    for (final raw in [
      cookieStore.get(source.bookSourceUrl),
      cookieStore.get(request.url),
      ...result.entries
          .where((e) => e.key.toLowerCase() == 'cookie')
          .map((e) => e.value),
    ]) {
      for (final pair in raw.split(';')) {
        final split = pair.indexOf('=');
        if (split > 0)
          cookiePairs[pair.substring(0, split).trim()] = pair
              .substring(split + 1)
              .trim();
      }
    }
    if (cookiePairs.isNotEmpty) {
      result.removeWhere((key, _) => key.toLowerCase() == 'cookie');
      result['Cookie'] = cookiePairs.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
    }
    for (final entry in headers.entries) {
      var value = entry.value;
      if (entry.key.toLowerCase() == 'cookie') {
        final pairs = <String, String>{};
        for (final raw in [
          ...result.entries
              .where((e) => e.key.toLowerCase() == 'cookie')
              .map((e) => e.value),
          entry.value,
        ]) {
          for (final cookie in raw.split(';')) {
            final separator = cookie.indexOf('=');
            if (separator > 0) {
              pairs[cookie.substring(0, separator).trim()] = cookie
                  .substring(separator + 1)
                  .trim();
            }
          }
        }
        value = pairs.entries.map((e) => '${e.key}=${e.value}').join('; ');
      }
      result.removeWhere(
        (key, _) => key.toLowerCase() == entry.key.toLowerCase(),
      );
      result[entry.key] = value;
    }
    bool contains(String name) =>
        result.keys.any((key) => key.toLowerCase() == name.toLowerCase());
    if (!contains('User-Agent')) {
      result['User-Agent'] =
          EngineLimits.userAgent ??
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36';
    }
    if (!contains('Referer')) {
      result['Referer'] = chapter.baseUrl.isEmpty
          ? chapter.url
          : chapter.baseUrl;
    }
    return (
      url: request.url,
      method: request.method,
      body: request.body,
      headers: Map<String, String>.unmodifiable(result),
    );
  }

  Future<({String url, Map<String, String> headers})> prepareMediaRequest(
    String url, {
    required BookSource source,
    required Book book,
    required BookChapter chapter,
    Map<String, String> headers = const {},
  }) async {
    final r = await prepareAudioRequest(
      url,
      source: source,
      book: book,
      chapter: chapter,
      headers: headers,
    );
    return (url: r.url, headers: r.headers);
  }

  Future<List<SearchBook>> search(
    BookSource source,
    String key, {
    int page = 1,
    bool Function(String name, String author, String? kind)? filter,
  }) => webBook
      .searchBook(source, key, page: page, filter: filter)
      .timeout(EngineLimits.searchTimeout);

  Future<List<SearchBook>> explore(
    BookSource source,
    String url, {
    int page = 1,
  }) => webBook
      .exploreBook(source, url, page: page)
      .timeout(EngineLimits.searchTimeout);

  Future<Book> bookInfo(BookSource source, Book book) =>
      webBook.getBookInfo(source, book).timeout(EngineLimits.tocTimeout);

  Future<List<BookChapter>> chapterList(
    BookSource source,
    Book book, {
    int maxPages = 40,
    void Function(List<BookChapter> chapters)? onPartial,
  }) => webBook
      .getChapterList(source, book, maxPages: maxPages, onPartial: onPartial)
      .timeout(EngineLimits.tocTimeout);

  Future<String> content(
    BookSource source,
    Book book,
    BookChapter chapter, {
    String? nextChapterUrl,
    int maxHops = 32,
  }) => webBook
      .getContent(
        source,
        book,
        chapter,
        nextChapterUrl: nextChapterUrl,
        maxHops: maxHops,
      )
      .timeout(
        Duration(
          seconds: (EngineLimits.contentTimeout.inSeconds + 15).clamp(30, 90),
        ),
      );

  Future<Uint8List> loadImage(
    String url, {
    BookSource? source,
    Book? book,
    bool isCover = true,
    Map<String, String>? headers,
  }) async {
    final bytes = await http.getBytes(url, headers: headers);
    final js = ImageDecoder.decodeJs(source, isCover: isCover);
    if (js == null) return bytes;
    return ImageDecoder.decode(
      bytes: bytes,
      src: url,
      js: js,
      jsRuntime: jsRuntime,
      javaHost: webBook.javaHost,
      book: book,
      source: source,
    );
  }

  void cancelInFlight() => http.cancelInFlight();

  void cancelSession(String session) {
    if (jsRuntime is JsSessionLifecycle)
      (jsRuntime as JsSessionLifecycle).cancelSession(session);
    final browser = webView;
    if (browser is SessionAwareWebView) {
      (browser as SessionAwareWebView).cancelSession(session);
    }
    final h = http;
    if (h is PackageHttpPort) {
      h.cancelSession(session);
    } else if (h is ProxyHttpPort) {
      h.cancelSession(session);
    }
  }
}
