import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../book_detail/chapter_text_cache.dart';
import '../book_detail/toc_cache.dart';
import '../reader/bookmark_provider.dart';
import '../settings/read_record_provider.dart';
import 'reading_progress_provider.dart';

/// Deletes everything Chloris stores about one book.
///
/// Legado gets chapter and search-result cleanup for free from
/// `ON DELETE CASCADE`, and deletes the rest explicitly. Chloris spreads a
/// book's state across KV blobs, two blob caches and drift, and deleting a
/// book used to touch only the shelf list — so progress, bookmarks, read
/// history, the cached catalog and every cached chapter stayed behind forever.
class BookCleanup {
  const BookCleanup(this._ref);

  final Ref _ref;

  /// [sourceUrl] must be the *book source* URL: the chapter text cache is keyed
  /// by `<sourceUrl>|<chapterUrl>`, and one source hosts many books. A mismatch
  /// leaves orphaned cache entries rather than deleting another book's data,
  /// which is the safe direction to fail in.
  Future<void> cleanBook({
    required String bookUrl,
    required String name,
    required String author,
    required String sourceUrl,
  }) async {
    if (bookUrl.isEmpty) return;

    await _ref.read(readingProgressProvider.notifier).remove(bookUrl);
    _ref.read(bookmarkListProvider.notifier).removeByBook(name, author);
    _ref.read(readRecordProvider.notifier).removeByBook(bookUrl);

    // Chapter text must be removed before the catalog that lists its URLs.
    final chapters = TocCache.instance.peek(bookUrl);
    if (chapters != null && chapters.isNotEmpty && sourceUrl.isNotEmpty) {
      await ChapterTextCache.instance.removeChapters(
        sourceUrl,
        chapters.map((c) => c.url),
      );
    }
    await TocCache.instance.remove(bookUrl);
  }
}

final bookCleanupProvider = Provider<BookCleanup>(BookCleanup.new);
