import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/book_detail/book_detail_provider.dart';
import '../../features/library/online_shelf_provider.dart';
import '../../features/library/reading_progress_provider.dart';
import '../../features/sources/source_library_provider.dart';
import '../../app/providers.dart';
import 'api_contract.dart';
import 'server_backend.dart';

/// Wires the HTTP API to the running application.
///
/// Every method delegates to the same providers the UI uses, so a remote client
/// sees the shelf and reading state the user sees. Deliberately no caching and
/// no second implementation of scraping: the catalog and content routes go
/// through the same use cases as the reader.
class AppServerBackend implements ServerBackend {
  AppServerBackend(this._ref);

  final Ref _ref;

  OnlineShelfItem? _shelfItem(String bookUrl) {
    for (final item in _ref.read(onlineShelfProvider)) {
      if (item.bookUrl == bookUrl) return item;
    }
    return null;
  }

  OnlineShelfItem _requireShelfItem(String bookUrl) {
    final item = _shelfItem(bookUrl);
    if (item == null) {
      throw DomainError(
        code: 'book_not_on_shelf',
        stage: DomainErrorStage.detail,
        message: '书架中没有这本书',
        bookId: bookUrl,
        recoverable: false,
        suggestedAction: '先把书加入书架，或检查 bookUrl 是否一致',
      );
    }
    return item;
  }

  @override
  Future<List<Map<String, dynamic>>> search(
    String sourceUrl,
    String query, {
    int page = 1,
  }) async {
    final sources = await _ref.read(allSourcesProvider.future);
    final source = sources.cast<BookSource?>().firstWhere(
      (s) => s?.bookSourceUrl == sourceUrl,
      orElse: () => null,
    );
    if (source == null) {
      throw DomainError(
        code: 'source_not_found',
        stage: DomainErrorStage.search,
        message: '找不到书源: $sourceUrl',
        sourceId: sourceUrl,
        recoverable: false,
      );
    }
    final books = await _ref.read(searchOnlineBooksUseCaseProvider)(
      source,
      query,
      page: page,
    );
    return [for (final book in books) book.toJson()];
  }

  Future<BookSource> _requireSource(String sourceUrl) async {
    final sources = await _ref.read(allSourcesProvider.future);
    final source = sources.cast<BookSource?>().firstWhere(
      (s) => s?.bookSourceUrl == sourceUrl,
      orElse: () => null,
    );
    if (source == null) {
      throw DomainError(
        code: 'source_not_found',
        stage: DomainErrorStage.search,
        message: '找不到书源: $sourceUrl',
        sourceId: sourceUrl,
        recoverable: false,
      );
    }
    return source;
  }

  @override
  Future<List<Map<String, dynamic>>> explore(
    String sourceUrl,
    String url, {
    int page = 1,
  }) async {
    final source = await _requireSource(sourceUrl);
    final books = await _ref.read(exploreOnlineBooksUseCaseProvider)(
      source,
      url,
      page: page,
    );
    return [for (final book in books) book.toJson()];
  }

  @override
  Future<Map<String, dynamic>> bookInfo(
    String sourceUrl,
    Map<String, dynamic> rawBook,
  ) async {
    final source = await _requireSource(sourceUrl);
    final seed = Book.fromJson(rawBook);
    final book = await _ref.read(loadOnlineBookInfoUseCaseProvider)(source, seed);
    return book.toJson();
  }

  Future<List<Map<String, dynamic>>> bookshelf() async => [
    for (final item in _ref.read(onlineShelfProvider))
      {
        'bookUrl': item.bookUrl,
        'name': item.searchBook.name,
        'author': item.searchBook.author,
        'origin': item.source.bookSourceUrl,
        'originName': item.source.bookSourceName,
        'kind': item.searchBook.kind,
        'intro': item.searchBook.intro,
        'coverUrl': item.searchBook.coverUrl,
        'latestChapterTitle': item.searchBook.latestChapterTitle,
      },
  ];

  @override
  Future<void> saveBook(Map<String, dynamic> book) async {
    final searchBook = SearchBook.fromJson(book);
    if (searchBook.bookUrl.isEmpty) {
      throw const DomainError(
        code: 'book_url_missing',
        stage: DomainErrorStage.persist,
        message: '缺少 bookUrl',
        recoverable: false,
      );
    }
    final sources = await _ref.read(allSourcesProvider.future);
    final origin = book['origin']?.toString() ?? '';
    final source = sources
        .where((s) => s.bookSourceUrl == origin)
        .cast<BookSource?>()
        .firstWhere((s) => s != null, orElse: () => null);
    if (source == null) {
      throw DomainError(
        code: 'source_not_found',
        stage: DomainErrorStage.persist,
        message: '找不到书源: $origin',
        sourceId: origin,
        recoverable: false,
        suggestedAction: '先通过 /saveBookSource 导入该书源',
      );
    }
    _ref.read(onlineShelfProvider.notifier).add(source, searchBook);
  }

  @override
  Future<void> deleteBook(String bookUrl) async {
    _ref.read(onlineShelfProvider.notifier).remove(bookUrl);
  }

  @override
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    final body = BookProgressBody.fromJson(progress);
    if (body.bookUrl.isEmpty) return;
    _ref
        .read(readingProgressProvider.notifier)
        .save(
          bookUrl: body.bookUrl,
          chapterIndex: body.chapterIndex,
          chapterTitle: body.chapterTitle,
          chapterPos: body.chapterPos,
        );
  }

  @override
  Future<List<Map<String, dynamic>>> chapterList(
    String bookUrl, {
    bool refresh = false,
  }) async {
    final item = _requireShelfItem(bookUrl);
    final chapters = await _ref.read(loadOnlineCatalogUseCaseProvider)(
      source: item.source,
      seed: item.searchBook.toBook(),
      useCache: !refresh,
    );
    return [
      for (final c in chapters)
        {
          'url': c.url,
          'title': c.title,
          'index': c.index,
          'isVolume': c.isVolume,
          'isVip': c.isVip,
          'isPay': c.isPay,
        },
    ];
  }

  @override
  Future<Map<String, dynamic>> bookContent(
    String bookUrl,
    int chapterIndex,
  ) async {
    final item = _requireShelfItem(bookUrl);
    final book = item.searchBook.toBook();
    final chapters = await _ref.read(loadOnlineCatalogUseCaseProvider)(
      source: item.source,
      seed: book,
    );
    final chapter = chapters.cast<BookChapter?>().firstWhere(
      (c) => c?.index == chapterIndex,
      orElse: () => null,
    );
    if (chapter == null) {
      throw DomainError(
        code: 'chapter_not_found',
        stage: DomainErrorStage.content,
        message: '目录中没有第 $chapterIndex 章',
        bookId: bookUrl,
        recoverable: false,
      );
    }
    final content = await _ref.read(loadOnlineChapterContentUseCaseProvider)(
      source: item.source,
      book: book,
      chapter: chapter,
    );
    return {
      'bookUrl': bookUrl,
      'index': chapterIndex,
      'title': chapter.title,
      'content': content,
    };
  }

  @override
  Future<Uint8List?> cover(String bookUrl) async {
    final item = _shelfItem(bookUrl);
    final url = item?.searchBook.coverUrl;
    if (url == null || url.isEmpty) return null;
    return _fetch(url);
  }

  @override
  Future<Uint8List?> image(String url) async => _fetch(url);

  Future<Uint8List?> _fetch(String url) async {
    try {
      final bytes = await _ref.read(httpPortProvider).getBytes(url);
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }
}

final appServerBackendProvider = Provider<AppServerBackend>(
  AppServerBackend.new,
);
