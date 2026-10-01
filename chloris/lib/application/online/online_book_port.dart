import 'package:chloris_engine/chloris_engine.dart';

/// Platform-neutral gateway used by the online-reading application layer.
///
/// Implementations may use the pure Dart engine, a Web proxy, or a native
/// adapter. Use cases depend on this contract instead of Flutter or Riverpod.
abstract interface class OnlineBookPort {
  Future<List<SearchBook>> search(
    BookSource source,
    String query, {
    int page = 1,
    bool Function(String name, String author, String? kind)? filter,
  });

  Future<List<SearchBook>> explore(
    BookSource source,
    String url, {
    int page = 1,
  });

  Future<Book> loadBookInfo(BookSource source, Book book);

  Future<List<BookChapter>> loadChapterList(
    BookSource source,
    Book book, {
    int maxPages = 40,
    void Function(List<BookChapter> chapters)? onPartial,
  });

  Future<String> loadChapterContent(
    BookSource source,
    Book book,
    BookChapter chapter, {
    String? nextChapterUrl,
    int maxHops = 32,
  });

  void cancelSession(String sessionId);
}

/// Persistent catalog cache boundary.
abstract interface class ChapterCatalogStore {
  Future<void> ensureLoaded();
  Future<void> hydrate(String bookUrl);
  List<BookChapter>? take(String bookUrl);
  List<BookChapter>? peek(String bookUrl);
  Future<void> put(String bookUrl, List<BookChapter> chapters);
  Future<void> remove(String bookUrl);
  void skipNext(String bookUrl);
}

/// Persistent per-chapter body cache boundary.
abstract interface class ChapterContentStore {
  Future<void> ensureLoaded();
  String? get(String sourceId, String chapterUrl);
  Future<void> put(String sourceId, String chapterUrl, String content);
  Future<void> remove(String sourceId, String chapterUrl);
}

/// Optional cold-read capability for persistent stores. Implementations that
/// only keep an in-memory cache can continue to use the synchronous [get].
abstract interface class AsyncChapterContentStore {
  Future<String?> read(String sourceId, String chapterUrl);
}
