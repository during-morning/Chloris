import 'package:chloris_engine/chloris_engine.dart';

import '../application/online/online_book_port.dart';
import '../core/http/http_session.dart';
import 'engine_facade.dart';

/// Adapter from the Flutter composition root to the pure Dart engine port.
///
/// Session binding stays here so feature providers never need to know how the
/// Web proxy or native HTTP implementation scopes cancellation.
class EngineOnlineBookAdapter implements OnlineBookPort {
  const EngineOnlineBookAdapter(this._facade);

  final EngineFacade _facade;

  @override
  Future<List<SearchBook>> search(
    BookSource source,
    String query, {
    int page = 1,
    bool Function(String name, String author, String? kind)? filter,
  }) => HttpSession.bind(
    'search',
    () => _facade.search(source, query, page: page, filter: filter),
  );

  @override
  Future<List<SearchBook>> explore(
    BookSource source,
    String url, {
    int page = 1,
  }) => HttpSession.bind(
    'explore',
    () => _facade.explore(source, url, page: page),
  );

  @override
  Future<Book> loadBookInfo(BookSource source, Book book) => HttpSession.bind(
    'detail:' + book.bookUrl,
    () => _facade.bookInfo(source, book),
  );

  @override
  Future<List<BookChapter>> loadChapterList(
    BookSource source,
    Book book, {
    int maxPages = 40,
    void Function(List<BookChapter> chapters)? onPartial,
  }) => HttpSession.bind(
    'toc:' + book.bookUrl,
    () => _facade.chapterList(
      source,
      book,
      maxPages: maxPages,
      onPartial: onPartial,
    ),
  );

  @override
  Future<String> loadChapterContent(
    BookSource source,
    Book book,
    BookChapter chapter, {
    String? nextChapterUrl,
    int maxHops = 32,
  }) => HttpSession.bind(
    'content:' + chapter.url,
    () => _facade.content(
      source,
      book,
      chapter,
      nextChapterUrl: nextChapterUrl,
      maxHops: maxHops,
    ),
  );

  @override
  void cancelSession(String sessionId) => _facade.cancelSession(sessionId);
}
