import '../models/book.dart';
import '../net/network_utils.dart';

/// Single policy for TOC quality: chrome removal, merge, and “unusable”
/// detection. WebBook and the app catalog UseCase must share this so a
/// short polluted list cannot bypass engine cleanup and get cached.
class ChapterListHygiene {
  const ChapterListHygiene._();

  /// Drop site navigation mistaken for chapters.
  ///
  /// Unambiguous chrome titles (`登录`, `首页`, `目录`…) are always removed,
  /// even on two- or three-entry lists. Fuzzy URL-based drops only apply
  /// once a list is large enough that those links are site chrome rather
  /// than a short legitimate TOC.
  static List<BookChapter> sanitize(List<BookChapter> chapters) {
    if (chapters.isEmpty) return chapters;
    final withoutNames = <BookChapter>[];
    for (final chapter in chapters) {
      final title = chapter.title.trim();
      if (isChromeChapterName(title) || isChromeBookName(title)) continue;
      withoutNames.add(chapter);
    }
    if (withoutNames.length < 5) return withoutNames;

    final cleaned = <BookChapter>[];
    var removed = chapters.length - withoutNames.length;
    for (final chapter in withoutNames) {
      final title = chapter.title.trim();
      if (title.length <= 12 && isChromeBookUrl(chapter.url)) {
        removed++;
        continue;
      }
      cleaned.add(chapter);
    }
    if (removed < 2 || cleaned.length < 2) return withoutNames;
    return cleaned;
  }

  static List<BookChapter> merge(
    List<BookChapter> a,
    List<BookChapter> b,
  ) {
    final seen = <String>{};
    final out = <BookChapter>[];
    for (final ch in [...a, ...b]) {
      final k = ch.url.isEmpty ? ch.title : ch.url;
      if (k.isEmpty || !seen.add(k)) continue;
      out.add(ch);
    }
    return out;
  }

  /// True when the parsed list is almost certainly a category/nav miss
  /// and the caller should retry a fallback URL or HTML scan.
  static bool isUnusable(List<BookChapter> chapters, String tocUrl) {
    if (chapters.isEmpty) return true;
    // A single leftover entry after chrome removal is still a miss.
    if (chapters.length == 1) return true;
    if (chapters.length < 5) {
      final t = chapters.first.title;
      if (t.length <= 6 && !RegExp(r'第.+(章|回|节)').hasMatch(t)) {
        return true;
      }
    }
    final unique = <String>{};
    for (final ch in chapters) {
      if (ch.url.isNotEmpty && ch.url != tocUrl) unique.add(ch.url);
    }
    return unique.length < 2;
  }
}
