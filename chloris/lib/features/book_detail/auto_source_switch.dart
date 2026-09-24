import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';

import '../../application/online/online_reading_use_cases.dart';
import '../../core/search/source_fanout.dart';
import '../../app/providers.dart';
import '../../core/search/search_match.dart';
import '../search/search_provider.dart';
import '../../core/search/search_schedule.dart';
import '../sources/source_library_provider.dart';

/// 自动换源（无头）：点开书发现当前源目录为空时，搜索其它源、
/// 按与换源面板相同的相关性打分挑最优候选，并**实取目录验证**，
/// 通过后才交给调用方执行切换。
class AutoSourceHit {
  const AutoSourceHit(this.source, this.searchBook, this.score);

  final BookSource source;
  final SearchBook searchBook;
  final double score;
}

double autoSourceScore(SearchBook b, String bookName, String bookAuthor) {
  final byName = searchMatchScore(b, bookName).toDouble();
  if (byName >= 300) return byName;
  if (searchMatchRatio(b, bookName) >= 0.5) return 400;
  final author = bookAuthor.trim();
  if (author.length >= 2) {
    final byAuthor = searchMatchScore(b, author).toDouble();
    if (byAuthor >= 520 &&
        normalizeSearchText(b.name).contains(normalizeSearchText(bookName))) {
      return byAuthor;
    }
  }
  return byName;
}

bool autoSourceAccept(SearchBook b, String bookName, String bookAuthor) {
  if (!isUsableSearchBook(b, query: bookName)) return false;
  return autoSourceScore(b, bookName, bookAuthor) >= 300;
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
  int maxVerify = 5,
  bool Function()? isCancelled,
}) async {
  final cancelled = isCancelled ?? () => false;
  final hits = <AutoSourceHit>[];

  void consider(BookSource s, SearchBook b) {
    if (s.bookSourceUrl == currentSourceUrl) return;
    if (b.bookUrl == currentBookUrl) return;
    if (!autoSourceAccept(b, bookName, bookAuthor)) return;
    final sc = autoSourceScore(b, bookName, bookAuthor);
    final i = hits.indexWhere((e) => e.source.bookSourceUrl == s.bookSourceUrl);
    if (i >= 0) {
      if (sc > hits[i].score) hits[i] = AutoSourceHit(s, b, sc);
      return;
    }
    hits.add(AutoSourceHit(s, b, sc));
  }

  final all = await ref.read(allSourcesProvider.future);
  if (cancelled()) return null;
  final enabled = all
      .where((s) => s.enabled && s.hasSearch)
      .toList(growable: false);
  await SourceLatencyStore.ensureLoaded();
  SourceLatencyStore.applyTo(enabled);

  final byUrl = <String, BookSource>{for (final s in all) s.bookSourceUrl: s};
  for (final origin in seedBook.origins) {
    final src = byUrl[origin];
    if (src == null) continue;
    final url = seedBook.originUrls[origin] ?? seedBook.bookUrl;
    consider(src, _copyForOrigin(seedBook, src, url));
  }
  for (final s in enabled) {
    final cached = SearchHitCache.instance.take(bookName, 1, s.bookSourceUrl);
    if (cached == null) continue;
    for (final b in cached) {
      consider(s, b);
    }
  }

  final already = <String>{
    currentSourceUrl,
    for (final h in hits) h.source.bookSourceUrl,
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

  hits.sort((a, b) => b.score.compareTo(a.score));
  // 逐个实取目录验证，最多 [maxVerify] 个。
  for (final hit in hits.take(maxVerify)) {
    if (cancelled()) return null;
    try {
      final seed = hit.searchBook.toBook();
      if (seed.tocUrl.isEmpty) {
        seed.tocUrl = hit.searchBook.tocUrl.isNotEmpty
            ? hit.searchBook.tocUrl
            : hit.searchBook.bookUrl;
      }
      final chapters = await catalog(
        source: hit.source,
        seed: seed,
        cacheKey: hit.searchBook.bookUrl,
        maxPages: 1,
      );
      if (chapters.length >= 2) return hit;
    } catch (_) {
      // 该候选目录取不到，试下一个。
      continue;
    }
  }
  return null;
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
