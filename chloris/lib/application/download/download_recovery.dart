import 'package:chloris_engine/chloris_engine.dart';

import '../online/online_reading_use_cases.dart';
import 'download_use_cases.dart';

/// Rebuilds a chapter fetch closure from persisted metadata after a restart.
///
/// Closures themselves cannot survive a process boundary. The queue only
/// stores source/book/chapter identities; this resolver looks up a live
/// [BookSource] and rebinds [LoadOnlineChapterContentUseCase].
DownloadResumeHandler? resolvePersistedDownloadJob({
  required BatchDownloadMetadata? metadata,
  required String bookName,
  required List<BookSource> sources,
  required LoadOnlineChapterContentUseCase content,
}) {
  final meta = metadata;
  if (meta == null || !meta.canResolve) return null;
  BookSource? source;
  for (final candidate in sources) {
    if (candidate.bookSourceUrl == meta.sourceId) {
      source = candidate;
      break;
    }
  }
  if (source == null) return null;
  final byIndex = <int, BatchDownloadChapterRef>{
    for (final chapter in meta.chapters) chapter.index: chapter,
  };
  if (byIndex.isEmpty) return null;
  final book = Book(
    bookUrl: meta.bookUrl,
    tocUrl: meta.tocUrl,
    name: bookName,
    origin: source.bookSourceUrl,
    originName: source.bookSourceName,
  );
  return DownloadResumeHandler(
    fetchChapter: (index) async {
      final ref = byIndex[index];
      if (ref == null || ref.url.trim().isEmpty) {
        throw StateError('missing chapter $index');
      }
      final next = byIndex[index + 1];
      await content(
        source: source!,
        book: book,
        chapter: BookChapter(
          index: ref.index,
          title: ref.title,
          url: ref.url,
          baseUrl: ref.baseUrl,
          bookUrl: book.bookUrl,
        ),
        nextChapterUrl: next?.url.isNotEmpty == true ? next!.url : null,
      );
    },
    hostOf: (index) =>
        Uri.tryParse(byIndex[index]?.url ?? '')?.host ?? source!.bookSourceUrl,
  );
}
