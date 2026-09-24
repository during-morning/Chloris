import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/route_args.dart';
import '../../app/widgets/follow_route.dart';
import '../library/reading_progress_provider.dart';
import '../local/local_book_service.dart';
import '../local/local_import_screen.dart';
import '../settings/read_record_provider.dart';
import 'book_detail_screen.dart';
import 'book_detail_provider.dart';

/// True when a cached TOC is complete enough to skip the detail page.
bool tocAllowsDirectRead(List<BookChapter>? chapters) =>
    chapters != null && chapters.length >= 2;

/// Tap opens [BookDetailScreen].
///
/// Pass [directRead] to resume the reader when TOC cache has ≥2 chapters
/// (shelf continue-reading). Otherwise, or on cache miss, go to detail.
/// [forceDetail] is kept for call-site compatibility; detail is the default.
Future<void> openOnlineBook(
  BuildContext context,
  WidgetRef ref, {
  required BookSource source,
  required SearchBook searchBook,
  bool forceDetail = true,
  bool directRead = false,
}) async {
  if (directRead) {
    final catalog = ref.read(loadOnlineCatalogUseCaseProvider);
    await catalog.ensureLoaded();
    final chapters = catalog.take(searchBook.bookUrl);
    if (tocAllowsDirectRead(chapters)) {
      if (!context.mounted) return;
      await _openCachedReader(context, ref, source, searchBook, chapters!);
      return;
    }
  }
  if (!context.mounted) return;
  try {
    await context.push(
      '/book/detail',
      extra: BookDetailRouteArgs(source: source, searchBook: searchBook),
    );
  } catch (_) {
    // Keep helpers usable in isolated widget tests that do not install a
    // GoRouter ancestor.
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      FollowPageRoute(
        builder: (_) =>
            BookDetailScreen(source: source, searchBook: searchBook),
      ),
    );
  }
}

Future<void> _openCachedReader(
  BuildContext context,
  WidgetRef ref,
  BookSource source,
  SearchBook searchBook,
  List<BookChapter> chapters,
) async {
  final book = searchBook.toBook();
  final prog = ref.read(readingProgressProvider)[book.bookUrl];
  var idx = prog?.chapterIndex ?? book.durChapterIndex;
  if (idx < 0 || idx >= chapters.length) idx = 0;
  book.durChapterIndex = idx;
  book.durChapterTitle = chapters[idx].title;
  ref
      .read(readingProgressProvider.notifier)
      .save(
        bookUrl: book.bookUrl,
        chapterIndex: idx,
        chapterTitle: chapters[idx].title,
        chapterPos: prog?.chapterPos ?? 0,
      );
  ref
      .read(readRecordProvider.notifier)
      .add(
        bookName: book.name,
        chapterTitle: chapters[idx].title,
        bookUrl: book.bookUrl,
      );
  try {
    await context.push(
      '/reader',
      extra: ChapterRouteArgs(
        source: source,
        book: book,
        chapter: chapters[idx],
        chapters: chapters,
        searchBook: searchBook,
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      FollowPageRoute(
        builder: (_) => ChapterContentScreen(
          source: source,
          book: book,
          chapter: chapters[idx],
          chapters: chapters,
          searchBook: searchBook,
        ),
      ),
    );
  }
}

void openLocalBook(
  BuildContext context,
  WidgetRef ref,
  LocalBookBundle bundle, {
  bool forceToc = false,
}) {
  if (forceToc || bundle.chapters.isEmpty) {
    Navigator.of(context, rootNavigator: true).push(
      FollowPageRoute(builder: (_) => LocalBookChaptersPage(bundle: bundle)),
    );
    return;
  }
  final prog = ref.read(readingProgressProvider)[bundle.book.bookUrl];
  var idx = prog?.chapterIndex ?? 0;
  if (idx < 0 || idx >= bundle.chapters.length) idx = 0;
  openLocalReader(context, bundle, bundle.chapters[idx]);
}
