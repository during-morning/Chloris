import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';

import '../../application/online/online_book_port.dart';
import '../../application/online/online_reading_use_cases.dart';
import '../../app/providers.dart';
import '../library/online_shelf_provider.dart';
import 'auto_source_switch.dart';
import 'chapter_text_cache.dart';
import 'toc_cache.dart';

class BookDetailData {
  const BookDetailData({required this.book, required this.chapters});

  final Book book;
  final List<BookChapter> chapters;
}

class BookDetailArgs {
  const BookDetailArgs(this.source, this.searchBook);

  final BookSource source;
  final SearchBook searchBook;

  @override
  bool operator ==(Object other) =>
      other is BookDetailArgs &&
      other.source.bookSourceUrl == source.bookSourceUrl &&
      other.searchBook.bookUrl == searchBook.bookUrl;

  @override
  int get hashCode => Object.hash(source.bookSourceUrl, searchBook.bookUrl);
}

/// Stable identity for a chapter request plus the next-page boundary used by
/// Legado's continuation extractor. Keeping the boundary in the request key
/// prevents a multi-page chapter from accidentally consuming the next
/// catalog entry.
class ChapterContentArgs {
  const ChapterContentArgs(
    this.source,
    this.book,
    this.chapter, {
    this.nextChapterUrl,
  });

  final BookSource source;
  final Book book;
  final BookChapter chapter;
  final String? nextChapterUrl;

  @override
  bool operator ==(Object other) =>
      other is ChapterContentArgs &&
      other.source.bookSourceUrl == source.bookSourceUrl &&
      other.book.bookUrl == book.bookUrl &&
      other.chapter.url == chapter.url &&
      other.nextChapterUrl == nextChapterUrl;

  @override
  int get hashCode => Object.hash(
    source.bookSourceUrl,
    book.bookUrl,
    chapter.url,
    nextChapterUrl,
  );
}

final tocPartialProvider = StateProvider.autoDispose
    .family<List<BookChapter>, BookDetailArgs>((ref, args) => const []);

final chapterCatalogStoreProvider = Provider<ChapterCatalogStore>((ref) {
  return TocCache.instance;
});

final chapterContentStoreProvider = Provider<ChapterContentStore>((ref) {
  return ChapterTextCache.instance;
});

final loadOnlineCatalogUseCaseProvider = Provider<LoadOnlineCatalogUseCase>(
  (ref) => LoadOnlineCatalogUseCase(
    ref.watch(onlineBookPortProvider),
    ref.watch(chapterCatalogStoreProvider),
  ),
);

final loadOnlineChapterContentUseCaseProvider =
    Provider<LoadOnlineChapterContentUseCase>(
      (ref) => LoadOnlineChapterContentUseCase(
        ref.watch(onlineBookPortProvider),
        ref.watch(chapterContentStoreProvider),
      ),
    );

final refreshOnlineBookUseCaseProvider = Provider<RefreshOnlineBookUseCase>(
  (ref) => RefreshOnlineBookUseCase(
    ref.watch(loadOnlineBookInfoUseCaseProvider),
    ref.watch(loadOnlineCatalogUseCaseProvider),
  ),
);

/// 详情头：失败时回退搜索结果，不挡封面/书名。
final bookInfoProvider = FutureProvider.autoDispose
    .family<Book, BookDetailArgs>((ref, args) async {
      final source = args.source;
      final searchBook = args.searchBook;
      final fallback = searchBook.toBook();
      try {
        // Let the detail route paint before HTML/JS work blocks the UI.
        await Future<void>.delayed(const Duration(milliseconds: 280));
        return await ref.watch(loadOnlineBookInfoUseCaseProvider)(
          source,
          fallback,
        );
      } catch (_) {
        return fallback;
      }
    });

/// 目录：先缓存，再联网；与 [bookInfoProvider] 并行。
final bookTocProvider = FutureProvider.autoDispose
    .family<List<BookChapter>, BookDetailArgs>((ref, args) async {
      final source = args.source;
      final searchBook = args.searchBook;
      // Do not wait for bookInfo — header and TOC race.
      final seed = searchBook.toBook();
      if (seed.tocUrl.isEmpty) {
        seed.tocUrl = searchBook.tocUrl.isNotEmpty
            ? searchBook.tocUrl
            : searchBook.bookUrl;
      }
      // First frame: header + skeleton. Then one-book cache / network.
      await Future<void>.delayed(Duration.zero);
      final useCase = ref.read(loadOnlineCatalogUseCaseProvider);
      final partial = ref.read(tocPartialProvider(args).notifier);
      var lastPartial = DateTime.fromMillisecondsSinceEpoch(0);
      late final List<BookChapter> chapters;
      try {
        chapters = await useCase(
          source: source,
          seed: seed,
          cacheKey: searchBook.bookUrl,
          maxPages: 1,
          onPartial: (part) {
            if (part.isEmpty) return;
            final now = DateTime.now();
            if (now.difference(lastPartial).inMilliseconds < 80) return;
            lastPartial = now;
            partial.state = List<BookChapter>.from(part);
          },
        );
      } on DomainError catch (error) {
        if (error.code == 'toc_empty') {
          ref
              .read(onlineShelfProvider.notifier)
              .removeCandidate(source.bookSourceUrl, searchBook.bookUrl);
          return const <BookChapter>[];
        }
        rethrow;
      }
      if (chapters.isNotEmpty) partial.state = chapters;
      unawaited(() async {
        // First-page TOC and the opening chapter share the interactive
        // HTTP lane. Wait until that first paint has a chance to fetch
        // before walking remaining catalog pages.
        await Future<void>.delayed(const Duration(milliseconds: 1600));
        await useCase.expandInBackground(
          source: source,
          seed: seed,
          cacheKey: searchBook.bookUrl,
          currentLength: chapters.length,
          onExpanded: (more) {
            partial.state = more;
          },
        );
      }());
      return chapters;
    });

/// 详情 + 目录（兼容旧调用；详情页不要用它挡整页）。
final bookDetailProvider = FutureProvider.autoDispose
    .family<BookDetailData, BookDetailArgs>((ref, args) async {
      final book = await ref.watch(bookInfoProvider(args).future);
      final chapters = await ref.watch(bookTocProvider(args).future);
      return BookDetailData(book: book, chapters: chapters);
    });

/// 单章正文。
final chapterContentProvider = FutureProvider.autoDispose
    .family<String, ChapterContentArgs>((ref, args) async {
      final source = args.source;
      final book = args.book;
      final chapter = args.chapter;
      return ref.read(loadOnlineChapterContentUseCaseProvider)(
        source: source,
        book: book,
        chapter: chapter,
        nextChapterUrl: args.nextChapterUrl,
      );
    });

/// 阅读中某章正文为空（[LoadOnlineChapterContentUseCase] 抛
/// `content_empty`）时，自动换源的引擎。
///
/// 流程与详情页的 [_applySourceSwitch] 对齐，但把目录缓存失效范围扩展到
/// **新旧两个 `bookUrl`**，并用「章节标题精确匹配」在新源目录里定位原章节；
/// 找不到同名标题则夹到 `min(原索引, 新目录长度-1)`。
///
/// 返回 `null` 表示没有可用的已验证候选（调用方应提示「没有找到可用的其它源」）；
/// 否则返回 [AutoSwitchResult]，调用方需用其重建阅读页（把 `source/book/chapters/
/// chapter` 换成新源的，并把阅读器定位到 [AutoSwitchResult.alignedChapterIndex]）。
///
/// 「每个阅读会话只触发一次」的防循环标志位由调用方（reader 会话页）持有，本函数
/// 不内置——避免换源后仍为空时再次触发形成死循环。
Future<AutoSwitchResult?> autoSwitchSourceForEmptyChapter(
  WidgetRef ref, {
  required String bookName,
  required String bookAuthor,
  required BookSource currentSource,
  required Book currentBook,
  required SearchBook seedBook,
  required List<BookChapter> currentChapters,
  required BookChapter emptyChapter,
  int? maxVerify,
  bool Function()? isCancelled,
}) async {
  final hit = await findVerifiedAlternativeSource(
    ref,
    bookName: bookName,
    bookAuthor: bookAuthor,
    currentSourceUrl: currentSource.bookSourceUrl,
    currentBookUrl: currentBook.bookUrl,
    seedBook: seedBook,
    catalog: ref.read(loadOnlineCatalogUseCaseProvider),
    content: ref.read(loadOnlineChapterContentUseCaseProvider),
    maxVerify: maxVerify,
    isCancelled: isCancelled,
  );
  if (hit == null) return null;

  // 换源：与原 _applySourceSwitch 一致，但缓存失效覆盖新旧 bookUrl。
  final sb = hit.searchBook;
  sb.origin = hit.source.bookSourceUrl;
  sb.originName = hit.source.bookSourceName;
  for (final e in seedBook.originUrls.entries) {
    sb.addOrigin(e.key, e.value);
  }
  sb.addOrigin(currentSource.bookSourceUrl, seedBook.bookUrl);

  final catalog = ref.read(loadOnlineCatalogUseCaseProvider);
  final stale = <String>{sb.bookUrl, currentBook.bookUrl, seedBook.bookUrl};
  await Future.wait([for (final url in stale) catalog.invalidate(url)]);

  ref
      .read(onlineShelfProvider.notifier)
      .replaceBook(seedBook.bookUrl, hit.source, sb);

  // 重新加载新源目录，并定位原章节。
  final newBook = sb.toBook();
  if (newBook.tocUrl.isEmpty) {
    newBook.tocUrl = sb.tocUrl.isNotEmpty ? sb.tocUrl : sb.bookUrl;
  }
  final newChapters = await catalog(
    source: hit.source,
    seed: newBook,
    cacheKey: sb.bookUrl,
    maxPages: 40,
    useCache: false,
  );
  var aligned = newChapters.indexWhere(
    (c) => c.title.trim() == emptyChapter.title.trim(),
  );
  if (aligned < 0) {
    final orig = currentChapters.indexWhere((c) => c.url == emptyChapter.url);
    final maxIdx = newChapters.isEmpty ? 0 : newChapters.length - 1;
    aligned = orig < 0 ? 0 : orig.clamp(0, maxIdx);
  }
  return AutoSwitchResult(
    source: hit.source,
    searchBook: sb,
    book: newBook,
    chapters: newChapters,
    alignedChapterIndex: newChapters.isEmpty
        ? 0
        : aligned.clamp(0, newChapters.length - 1),
  );
}

/// [autoSwitchSourceForEmptyChapter] 的成功结果：调用方据此重建阅读页。
class AutoSwitchResult {
  const AutoSwitchResult({
    required this.source,
    required this.searchBook,
    required this.book,
    required this.chapters,
    required this.alignedChapterIndex,
  });

  final BookSource source;
  final SearchBook searchBook;
  final Book book;
  final List<BookChapter> chapters;
  final int alignedChapterIndex;
}

/// 预取下一章进缓存（不占用 Riverpod autoDispose 生命周期）。
Future<void> prefetchChapterContentFor(
  WidgetRef ref,
  BookSource source,
  Book book,
  BookChapter chapter, {
  String? nextChapterUrl,
}) async {
  await ref
      .read(loadOnlineChapterContentUseCaseProvider)
      .prefetch(
        source: source,
        book: book,
        chapter: chapter,
        nextChapterUrl: nextChapterUrl,
      );
}

Future<(Book, List<BookChapter>)> refreshOnlineToc(
  WidgetRef ref, {
  required BookSource source,
  required Book book,
}) async {
  return ref.read(refreshOnlineBookUseCaseProvider)(source: source, book: book);
}

Future<String> fetchChapterTextFor(
  WidgetRef ref,
  BookSource source,
  Book book,
  BookChapter chapter, {
  String? nextChapterUrl,
}) async {
  return ref.read(loadOnlineChapterContentUseCaseProvider)(
    source: source,
    book: book,
    chapter: chapter,
    nextChapterUrl: nextChapterUrl,
  );
}
