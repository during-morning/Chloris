import 'package:chloris_engine/chloris_engine.dart';

import '../../core/http/channel_ws_port.dart';
import '../../services/web/api_client.dart';
import 'online_book_port.dart';

/// [OnlineBookPort] backed by a Chloris server instead of the local engine.
///
/// This is the piece that makes the Web build a renderer: the browser asks the
/// server for the catalogue and the body text rather than running rules itself.
/// Nothing above this class changes — the UI already depends on the port, not
/// on the engine — which is the payoff of the existing layering.
class HttpOnlineBookPort implements OnlineBookPort {
  const HttpOnlineBookPort(this._client, {this.serverToken = ''});

  final ChlorisApiClient _client;
  final String serverToken;

  static DomainError _unsupported(String what) => DomainError(
    code: 'capability_missing',
    stage: DomainErrorStage.search,
    message: '$what 尚未在服务端契约中提供',
    recoverable: false,
    retryable: false,
    suggestedAction: '检查服务端 capability matrix，或切换到本地引擎',
  );

  /// The WebSocket endpoint needs the same token as the HTTP API when the
  /// source URL points at the local Chloris server. Third-party Legado
  /// endpoints are still sent no headers unless a token was configured.
  @override
  Future<List<SearchBook>> search(
    BookSource source,
    String query, {
    int page = 1,
    bool Function(String name, String author, String? kind)? filter,
  }) async {
    if (!source.webSocketSearch) throw _unsupported('在线搜索');
    final url = source.webSocketUrl;
    if (url == null || url.trim().isEmpty) throw _unsupported('在线搜索');
    return searchOverWebSocket(
      port: const ChannelWsPort(),
      source: source,
      query: query,
      page: page,
      filter: filter,
      headers: serverToken.isEmpty
          ? const {}
          : {
              'Authorization': 'Bearer $serverToken',
              'X-Chloris-Token': serverToken,
            },
    );
  }

  @override
  Future<List<SearchBook>> explore(
    BookSource source,
    String url, {
    int page = 1,
  }) async {
    final books = await _client.explore(source.bookSourceUrl, url, page: page);
    return books;
  }

  @override
  Future<Book> loadBookInfo(BookSource source, Book book) async {
    return _client.bookInfo(source.bookSourceUrl, book);
  }

  @override
  Future<List<BookChapter>> loadChapterList(
    BookSource source,
    Book book, {
    int maxPages = 40,
    void Function(List<BookChapter> chapters)? onPartial,
  }) async {
    final chapters = await _client.chapterList(book.bookUrl);
    if (chapters.isEmpty) {
      throw DomainError(
        code: 'toc_empty',
        stage: DomainErrorStage.toc,
        message: '服务端返回空目录',
        bookId: book.bookUrl,
        sourceId: source.bookSourceUrl,
        recoverable: true,
        retryable: true,
        suggestedAction: '刷新目录，或检查该书源在服务端是否仍然可用',
      );
    }
    onPartial?.call(chapters);
    return chapters;
  }

  @override
  Future<String> loadChapterContent(
    BookSource source,
    Book book,
    BookChapter chapter, {
    String? nextChapterUrl,
    int maxHops = 32,
  }) async {
    final result = await _client.bookContent(book.bookUrl, chapter.index);
    final content = result.content;
    if (content.trim().isEmpty) {
      throw DomainError(
        code: 'content_empty',
        stage: DomainErrorStage.content,
        message: '服务端返回空正文',
        bookId: book.bookUrl,
        chapterId: chapter.url,
        sourceId: source.bookSourceUrl,
        recoverable: true,
        retryable: true,
        suggestedAction: '重试本章，或换源',
      );
    }
    return content;
  }

  @override
  void cancelSession(String sessionId) {
    // Requests are short lived and owned by the server; there is nothing to
    // cancel on this side.
  }
}

/// Catalog cache for the HTTP port.
///
/// The server owns the durable catalogue, so this is a memory-only buffer that
/// keeps the reader responsive between requests. It deliberately does not
/// persist: a second source of truth on the client is what the plan removes.
class HttpChapterCatalogStore implements ChapterCatalogStore {
  final Map<String, List<BookChapter>> _mem = {};
  final Set<String> _skip = {};

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> hydrate(String bookUrl) async {}

  @override
  List<BookChapter>? peek(String bookUrl) => _mem[bookUrl];

  @override
  List<BookChapter>? take(String bookUrl) {
    if (_skip.remove(bookUrl)) return null;
    return _mem[bookUrl];
  }

  @override
  Future<void> put(String bookUrl, List<BookChapter> chapters) async {
    _mem[bookUrl] = chapters;
  }

  @override
  Future<void> remove(String bookUrl) async {
    _mem.remove(bookUrl);
  }

  @override
  void skipNext(String bookUrl) => _skip.add(bookUrl);
}

/// Body cache for the HTTP port. Memory-only for the same reason.
class HttpChapterContentStore implements ChapterContentStore {
  final Map<String, String> _mem = {};

  String _key(String sourceId, String chapterUrl) => '$sourceId|$chapterUrl';

  @override
  Future<void> ensureLoaded() async {}

  @override
  String? get(String sourceId, String chapterUrl) =>
      _mem[_key(sourceId, chapterUrl)];

  @override
  Future<void> put(String sourceId, String chapterUrl, String content) async {
    _mem[_key(sourceId, chapterUrl)] = content;
  }

  @override
  Future<void> remove(String sourceId, String chapterUrl) async {
    _mem.remove(_key(sourceId, chapterUrl));
  }
}
