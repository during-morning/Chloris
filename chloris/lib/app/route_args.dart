import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/foundation.dart';

/// Typed payloads for GoRouter top-level routes. Keeping these objects out of
/// the router itself avoids making feature pages depend on router internals.
class BookDetailRouteArgs {
  const BookDetailRouteArgs({required this.source, required this.searchBook});

  final BookSource source;
  final SearchBook searchBook;
}

class ChapterRouteArgs {
  const ChapterRouteArgs({
    required this.source,
    required this.book,
    required this.chapter,
    this.chapters = const [],
    this.searchBook,
  });

  final BookSource source;
  final Book book;
  final BookChapter chapter;
  final List<BookChapter> chapters;
  final SearchBook? searchBook;
}

class TocRouteArgs {
  const TocRouteArgs({
    required this.book,
    required this.chapters,
    required this.onOpenChapter,
  });

  final Book book;
  final List<BookChapter> chapters;
  final ValueChanged<int> onOpenChapter;
}
