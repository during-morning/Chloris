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
    WebViewPort? webView,
    this.filePort = const UnsupportedFilePort(),
    this.hostEnvironment = const DefaultHostEnvironment(),
  })  : jsRuntime = jsRuntime ?? const NoJsRuntime(),
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

  final HttpPort http;
  final JsRuntime jsRuntime;
  final CookieStore cookieStore;

  /// Rule-script file access. The caller attaches a real port on platforms
  /// that have a file system; the default reports the capability as absent.
  final FilePort filePort;

  /// Platform interactions and settings exposed to rule scripts.
  final HostEnvironment hostEnvironment;
  late final WebBook webBook;

  Future<List<SearchBook>> search(
    BookSource source,
    String key, {
    int page = 1,
    bool Function(String name, String author, String? kind)? filter,
  }) =>
      webBook
          .searchBook(source, key, page: page, filter: filter)
          .timeout(EngineLimits.searchTimeout);

  Future<List<SearchBook>> explore(
    BookSource source,
    String url, {
    int page = 1,
  }) =>
      webBook
          .exploreBook(source, url, page: page)
          .timeout(EngineLimits.searchTimeout);

  Future<Book> bookInfo(BookSource source, Book book) =>
      webBook.getBookInfo(source, book).timeout(EngineLimits.tocTimeout);

  Future<List<BookChapter>> chapterList(
    BookSource source,
    Book book, {
    int maxPages = 40,
    void Function(List<BookChapter> chapters)? onPartial,
  }) =>
      webBook
          .getChapterList(
            source,
            book,
            maxPages: maxPages,
            onPartial: onPartial,
          )
          .timeout(EngineLimits.tocTimeout);

  Future<String> content(
    BookSource source,
    Book book,
    BookChapter chapter, {
    String? nextChapterUrl,
    int maxHops = 32,
  }) =>
      webBook
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
    final h = http;
    if (h is PackageHttpPort) {
      h.cancelSession(session);
    } else if (h is ProxyHttpPort) {
      h.cancelSession(session);
    }
  }
}
