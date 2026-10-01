import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';

import '../../application/online/online_reading_use_cases.dart';
import '../../core/search/source_fanout.dart';
import '../../app/providers.dart';
import '../../core/search/source_switch_service.dart';
import '../search/search_provider.dart';
import '../../core/search/search_schedule.dart';
import '../sources/source_library_provider.dart';

/// 自动换源（无头）：点开书发现当前源目录为空时，搜索其它源、
/// 按与换源面板相同的相关性打分挑最优候选，并**实取目录验证**，
/// 通过后才交给调用方执行切换。
class AutoSourceHit {
  const AutoSourceHit(this.source, this.searchBook, this.score, this.decision);

  final BookSource source;
  final SearchBook searchBook;
  final double score;
  final SourceSwitchDecision decision;
}

/// 搜索全部可用源并返回**已验证目录非空**的最优候选；找不到返回 null。
///
/// 验证是必须的：搜索命中只代表「搜到了同名书」，不代表这个源的目录/正文
/// 还活着——那正是触发自动换源的原因，不能换个源还是空的。
Future<AutoSourceHit?> findVerifiedAlternativeSource(
  WidgetRef ref, {
  required String bookName,
  required String bookAuthor,
  required String currentSourceUrl,
  required String currentBookUrl,
  required SearchBook seedBook,
  required LoadOnlineCatalogUseCase catalog,
  LoadOnlineChapterContentUseCase? content,
  int? maxVerify,
  bool Function()? isCancelled,
}) async {
  final cancelled = isCancelled ?? () => false;
  final candidates = <SourceSwitchCandidate>[];
  final service = SourceSwitchService(
    verify: (candidate) async {
      final seed = candidate.book.toBook();
      if (seed.tocUrl.isEmpty) {
        seed.tocUrl = candidate.book.tocUrl.isNotEmpty
            ? candidate.book.tocUrl
            : candidate.book.bookUrl;
      }
      final chapters = await catalog(
        source: candidate.source,
        seed: seed,
        cacheKey: candidate.book.bookUrl,
        maxPages: 1,
      );
      if (chapters.isEmpty) {
        return SourceVerification(
          level: SourceVerificationLevel.none,
          chapterCount: chapters.length,
          failureCode: 'toc_empty',
        );
      }
      if (content != null) {
        try {
          final text = await content(
            source: candidate.source,
            book: seed,
            chapter: chapters.first,
            nextChapterUrl: chapters.length > 1 ? chapters[1].url : null,
          );
          return SourceVerification(
            level: text.trim().isEmpty
                ? SourceVerificationLevel.none
                : SourceVerificationLevel.l2Content,
            chapterCount: chapters.length,
            contentLength: text.trim().length,
            failureCode: text.trim().isEmpty ? 'content_empty' : null,
          );
        } catch (_) {
          return SourceVerification(
            level: SourceVerificationLevel.none,
            chapterCount: chapters.length,
            failureCode: 'content_empty',
          );
        }
      }
      return SourceVerification(
        level: SourceVerificationLevel.l1Catalog,
        chapterCount: chapters.length,
      );
    },
  );

  void consider(BookSource s, SearchBook b) {
    if (s.bookSourceUrl == currentSourceUrl) return;
    if (b.bookUrl == currentBookUrl) return;
    final candidate = service.candidate(
      s,
      b,
      bookName: bookName,
      bookAuthor: bookAuthor,
    );
    if (candidate != null) candidates.add(candidate);
  }

  final all = await ref.read(allSourcesProvider.future);
  if (cancelled()) return null;
  final enabled = all
      .where((s) => s.enabled && s.hasSearch)
      .toList(growable: false);
  await SourceLatencyStore.ensureLoaded();
  SourceLatencyStore.applyTo(enabled);
  await SearchHitCache.ensureLoaded();

  final byUrl = <String, BookSource>{for (final s in all) s.bookSourceUrl: s};
  for (final origin in seedBook.origins) {
    final src = byUrl[origin];
    if (src == null) continue;
    final url = seedBook.originUrls[origin] ?? seedBook.bookUrl;
    consider(src, _copyForOrigin(seedBook, src, url));
  }
  for (final s in enabled) {
    final cached = SearchHitCache.instance.takeForSource(s, bookName);
    if (cached == null) continue;
    for (final b in cached) {
      consider(s, b);
    }
  }

  final already = <String>{
    currentSourceUrl,
    for (final h in service.rank(candidates)) h.source.bookSourceUrl,
  };
  final queue = orderSearchSources(
    enabled.where((s) => !already.contains(s.bookSourceUrl)).toList(),
  );
  final searchUseCase = ref.read(searchOnlineBooksUseCaseProvider);
  await SourceFanout.run(
    sources: queue,
    query: bookName,
    page: 1,
    search: (s) => searchUseCase(s, bookName),
    isCancelled: cancelled,
    waitForCache: false,
    // 自动换源要「最优候选」，但不必扫完：拿到一个精确命中（≥800）即可收。
    earlyStop: false,
    onRow: (row) {
      if (cancelled()) return;
      for (final b in row.books) {
        consider(row.source, b);
      }
    },
  );
  if (cancelled()) return null;

  final selected = await service.select(
    candidates,
    maxVerify: maxVerify ?? candidates.length,
    isCancelled: cancelled,
  );
  if (selected == null) return null;
  return AutoSourceHit(
    selected.candidate.source,
    selected.candidate.book,
    selected.candidate.score.toDouble(),
    selected.decision,
  );
}

SearchBook _copyForOrigin(SearchBook b, BookSource src, String url) {
  return SearchBook(
    bookUrl: url,
    origin: src.bookSourceUrl,
    originName: src.bookSourceName,
    type: b.type,
    name: b.name,
    author: b.author,
    kind: b.kind,
    coverUrl: b.coverUrl,
    intro: b.intro,
    wordCount: b.wordCount,
    latestChapterTitle: b.latestChapterTitle,
    tocUrl: b.tocUrl,
  );
}
