import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';

import 'online_book_port.dart';

typedef CatalogUpdate = void Function(List<BookChapter> chapters);

class SearchOnlineBooksUseCase {
  const SearchOnlineBooksUseCase(this._port);

  final OnlineBookPort _port;

  Future<List<SearchBook>> call(
    BookSource source,
    String query, {
    int page = 1,
    bool Function(String name, String author, String? kind)? filter,
  }) async {
    try {
      return await _port.search(source, query, page: page, filter: filter);
    } catch (error) {
      throw DomainError.from(
        error,
        stage: DomainErrorStage.search,
        sourceId: source.bookSourceUrl,
      );
    }
  }

  void cancel() => _port.cancelSession('search');
}

class ExploreOnlineBooksUseCase {
  const ExploreOnlineBooksUseCase(this._port);

  final OnlineBookPort _port;

  Future<List<SearchBook>> call(
    BookSource source,
    String url, {
    int page = 1,
  }) async {
    try {
      return await _port.explore(source, url, page: page);
    } catch (error) {
      throw DomainError.from(
        error,
        stage: DomainErrorStage.search,
        sourceId: source.bookSourceUrl,
      );
    }
  }
}

class LoadOnlineBookInfoUseCase {
  const LoadOnlineBookInfoUseCase(this._port);

  final OnlineBookPort _port;

  Future<Book> call(BookSource source, Book seed) async {
    try {
      final book = await _port.loadBookInfo(source, seed);
      _validateBookIdentity(source, seed, book);
      return book;
    } catch (error) {
      throw DomainError.from(
        error,
        stage: DomainErrorStage.detail,
        sourceId: source.bookSourceUrl,
        bookId: seed.bookUrl,
      );
    }
  }
}

class LoadOnlineCatalogUseCase {
  const LoadOnlineCatalogUseCase(this._port, this._store);

  final OnlineBookPort _port;
  final ChapterCatalogStore _store;

  Future<List<BookChapter>> call({
    required BookSource source,
    required Book seed,
    String? cacheKey,
    int maxPages = 1,
    CatalogUpdate? onPartial,
    bool useCache = true,
  }) async {
    final primaryKey = cacheKey?.trim().isNotEmpty == true
        ? cacheKey!.trim()
        : seed.bookUrl;
    await _store.ensureLoaded();
    if (useCache) {
      await _store.hydrate(primaryKey);
      final cached = _store.take(primaryKey);
      if (cached != null && cached.length >= 2) return cached;
    }

    if (seed.tocUrl.isEmpty) seed.tocUrl = primaryKey;
    try {
      final chapters = await _port.loadChapterList(
        source,
        seed,
        maxPages: maxPages,
        onPartial: onPartial,
      );
      final valid = _validateCatalog(chapters);
      if (valid.isEmpty) {
        throw DomainError(
          code: 'toc_empty',
          stage: DomainErrorStage.toc,
          message: '目录为空或站点无响应',
          sourceId: source.bookSourceUrl,
          bookId: seed.bookUrl,
          retryable: true,
          suggestedAction: '请重试或更换书源',
        );
      }
      if (valid.length >= 5) {
        await _store.put(seed.bookUrl, valid);
        if (primaryKey != seed.bookUrl) await _store.put(primaryKey, valid);
      }
      return valid;
    } catch (error) {
      throw DomainError.from(
        error,
        stage: DomainErrorStage.toc,
        sourceId: source.bookSourceUrl,
        bookId: seed.bookUrl,
      );
    }
  }

  Future<void> expandInBackground({
    required BookSource source,
    required Book seed,
    required int currentLength,
    String? cacheKey,
    CatalogUpdate? onExpanded,
    int maxPages = 40,
  }) async {
    if ((source.getTocRule().nextTocUrl ?? '').trim().isEmpty) return;
    try {
      final more = await call(
        source: source,
        seed: seed,
        cacheKey: cacheKey,
        maxPages: maxPages,
        useCache: false,
      );
      if (more.length > currentLength) onExpanded?.call(more);
    } catch (_) {
      // The foreground catalog remains usable. A later explicit retry exposes
      // the classified error instead of replacing already rendered chapters.
    }
  }

  Future<void> ensureLoaded() => _store.ensureLoaded();

  List<BookChapter>? take(String bookUrl) => _store.take(bookUrl);

  List<BookChapter>? peek(String bookUrl) => _store.peek(bookUrl);

  Future<void> invalidate(String bookUrl) async {
    _store.skipNext(bookUrl);
    await _store.remove(bookUrl);
  }
}

class LoadOnlineChapterContentUseCase {
  const LoadOnlineChapterContentUseCase(this._port, this._store);

  final OnlineBookPort _port;
  final ChapterContentStore _store;

  static const _mediaCachePrefix = '\u0000media-chapter-v1:';

  String _restoreCachedChapter(String cached, BookChapter chapter) {
    if (!cached.startsWith(_mediaCachePrefix)) return cached;
    try {
      final data = jsonDecode(cached.substring(_mediaCachePrefix.length));
      if (data is Map && data['content'] is String) {
        if (data['variable'] is String) chapter.variable = data['variable'];
        if (data['resourceUrl'] is String) {
          chapter.resourceUrl = data['resourceUrl'];
        }
        return data['content'] as String;
      }
    } catch (_) {}
    // A damaged metadata envelope should be refetched, never shown as text.
    return '';
  }

  Future<String> call({
    required BookSource source,
    required Book book,
    required BookChapter chapter,
    String? nextChapterUrl,
    int maxHops = 32,
    bool useCache = true,
  }) async {
    await _store.ensureLoaded();
    if (useCache) {
      final cached = _store is AsyncChapterContentStore
          ? await (_store as AsyncChapterContentStore).read(
              source.bookSourceUrl,
              chapter.url,
            )
          : _store.get(source.bookSourceUrl, chapter.url);
      final needsMediaMetadata =
          book.isAudio &&
          (source.getContentRule().subContent ?? '').isNotEmpty &&
          chapter.getVariable('lyric').isEmpty &&
          cached?.startsWith(_mediaCachePrefix) != true;
      if (cached != null && !needsMediaMetadata) {
        final content = _restoreCachedChapter(cached, chapter);
        if (content.trim().isNotEmpty) return content;
      }
    }
    _validateChapterIdentity(source, book, chapter);
    try {
      final content = await _port.loadChapterContent(
        source,
        book,
        chapter,
        nextChapterUrl: nextChapterUrl,
        maxHops: maxHops,
      );
      if (content.trim().isEmpty) {
        throw DomainError(
          code: 'content_empty',
          stage: DomainErrorStage.content,
          message: '章节正文为空',
          sourceId: source.bookSourceUrl,
          bookId: book.bookUrl,
          chapterId: chapter.url,
          retryable: true,
          suggestedAction: '请重试、重新登录或更换书源',
        );
      }
      // Lyrics are produced while loading content, after the catalog was
      // cached. Persist them alongside audio content so reopening a chapter
      // or using a prefetched chapter does not lose subContent metadata.
      final cached = book.isAudio || book.isVideo
          ? '$_mediaCachePrefix${jsonEncode({'content': content, 'variable': chapter.variable, 'resourceUrl': chapter.resourceUrl})}'
          : content;
      await _store.put(source.bookSourceUrl, chapter.url, cached);
      return content;
    } catch (error) {
      throw DomainError.from(
        error,
        stage: DomainErrorStage.content,
        sourceId: source.bookSourceUrl,
        bookId: book.bookUrl,
        chapterId: chapter.url,
      );
    }
  }

  Future<void> prefetch({
    required BookSource source,
    required Book book,
    required BookChapter chapter,
    String? nextChapterUrl,
  }) async {
    try {
      await call(
        source: source,
        book: book,
        chapter: chapter,
        nextChapterUrl: nextChapterUrl,
      );
    } catch (_) {
      // Prefetch is speculative and must never replace the foreground state.
    }
  }

  Future<void> invalidate(BookSource source, BookChapter chapter) =>
      _store.remove(source.bookSourceUrl, chapter.url);
}

class RefreshOnlineBookUseCase {
  const RefreshOnlineBookUseCase(this._info, this._catalog);

  final LoadOnlineBookInfoUseCase _info;
  final LoadOnlineCatalogUseCase _catalog;

  Future<(Book, List<BookChapter>)> call({
    required BookSource source,
    required Book book,
  }) async {
    final info = await _info(source, book);
    final chapters = await _catalog(
      source: source,
      seed: info,
      cacheKey: info.bookUrl,
      maxPages: 40,
      useCache: false,
    );
    return (info, chapters);
  }
}

void _validateBookIdentity(BookSource source, Book seed, Book result) {
  if (result.bookUrl.trim().isEmpty) result.bookUrl = seed.bookUrl;
  if (result.origin.trim().isEmpty) result.origin = source.bookSourceUrl;
  if (result.origin != source.bookSourceUrl) {
    throw DomainError(
      code: 'book_identity_mismatch',
      stage: DomainErrorStage.detail,
      message: '书籍详情来源与当前书源不一致',
      sourceId: source.bookSourceUrl,
      bookId: seed.bookUrl,
      recoverable: false,
      suggestedAction: '请返回搜索结果并重新选择书源',
    );
  }
}

List<BookChapter> _validateCatalog(List<BookChapter> chapters) {
  final seen = <String>{};
  return ChapterListHygiene.sanitize(chapters)
      .where((chapter) {
        final title = chapter.title.trim();
        final url = chapter.url.trim();
        if (title.isEmpty || url.isEmpty) return false;
        if (!seen.add(url)) return false;
        return true;
      })
      .toList(growable: false);
}

void _validateChapterIdentity(
  BookSource source,
  Book book,
  BookChapter chapter,
) {
  if (source.bookSourceUrl.trim().isEmpty ||
      book.bookUrl.trim().isEmpty ||
      chapter.url.trim().isEmpty) {
    throw DomainError(
      code: 'chapter_identity_missing',
      stage: DomainErrorStage.content,
      message: '章节身份不完整，无法安全读取正文',
      sourceId: source.bookSourceUrl,
      bookId: book.bookUrl,
      chapterId: chapter.url,
      recoverable: false,
      suggestedAction: '请返回目录并重新打开章节',
    );
  }
}
