import 'package:chloris_engine/chloris_engine.dart';

import 'search_match.dart';
import 'search_models.dart';
import 'search_schedule.dart';

/// Incremental identity merge so search UI does not LCS the full set every frame.
class IncrementalSearchMerge {
  IncrementalSearchMerge(this.query);

  final String query;
  final _index = <String, SearchBook>{};
  final _byOrigin = <String, BookSource>{};
  final _score = <String, int>{};
  final _ratio = <String, double>{};
  List<(BookSource, SearchBook)>? _snap;
  bool _snapPrecise = false;

  void add(SourceSearchResult row) {
    _byOrigin[row.source.bookSourceUrl] = row.source;
    final usable = row.books
        .where((b) => isUsableSearchBook(b, query: query))
        .toList();
    if (usable.isEmpty) return;
    var changed = false;
    for (final n in usable) {
      if (n.origin.trim().isEmpty) {
        n.origin = row.source.bookSourceUrl;
        if (n.originName.trim().isEmpty) {
          n.originName = row.source.bookSourceName;
        }
        n.originOrder = row.source.customOrder;
      }
      final id = SearchMerge.identity(n);
      final same = _index[id];
      if (same != null) {
        final before = same.origins.length;
        if (n.origin.trim().isNotEmpty) {
          same.addOrigin(n.origin, n.bookUrl);
        }
        var enriched = same.origins.length != before;
        if ((same.coverUrl ?? '').isEmpty && (n.coverUrl ?? '').isNotEmpty) {
          same.coverUrl = n.coverUrl;
          enriched = true;
        }
        if ((same.intro ?? '').isEmpty && (n.intro ?? '').isNotEmpty) {
          same.intro = n.intro;
          enriched = true;
        }
        if ((same.kind ?? '').isEmpty && (n.kind ?? '').isNotEmpty) {
          same.kind = n.kind;
          enriched = true;
        }
        if ((same.latestChapterTitle ?? '').isEmpty) {
          if ((n.latestChapterTitle ?? '').isNotEmpty) {
            same.latestChapterTitle = n.latestChapterTitle;
            enriched = true;
          }
        }
        if (same.tocUrl.isEmpty && n.tocUrl.isNotEmpty) {
          same.tocUrl = n.tocUrl;
          enriched = true;
        }
        if ((same.wordCount ?? '').isEmpty && (n.wordCount ?? '').isNotEmpty) {
          same.wordCount = n.wordCount;
          enriched = true;
        }
        if ((same.variable ?? '').isEmpty && (n.variable ?? '').isNotEmpty) {
          same.variable = n.variable;
          enriched = true;
        }
        if ((same.infoHtml ?? '').isEmpty && (n.infoHtml ?? '').isNotEmpty) {
          same.infoHtml = n.infoHtml;
          enriched = true;
        }
        if ((same.tocHtml ?? '').isEmpty && (n.tocHtml ?? '').isNotEmpty) {
          same.tocHtml = n.tocHtml;
          enriched = true;
        }
        if (enriched) changed = true;
      } else {
        _index[id] = n;
        _score[id] = searchMatchScore(n, query);
        _ratio[id] = searchMatchRatio(n, query);
        changed = true;
      }
    }
    if (changed) _snap = null;
  }

  bool enoughHits({bool scoped = false, int minHits = 0, int minScore = 0}) {
    if (scoped || minHits <= 0) return false;
    var n = 0;
    for (final e in _score.entries) {
      if (e.value >= minScore) n++;
      if (n >= minHits) return true;
    }
    return false;
  }

  List<(BookSource, SearchBook)> snapshot({bool precise = false}) {
    if (_snap != null && _snapPrecise == precise) return _snap!;
    final single = isBasicSingleCharQuery(query);
    var books = _index.values.toList();
    books.sort((a, b) {
      if (single) {
        final sa = _byOrigin[a.origin];
        final sb = _byOrigin[b.origin];
        final byWeight = (sb?.weight ?? 0).compareTo(sa?.weight ?? 0);
        if (byWeight != 0) return byWeight;
        final ra = sa != null ? effectiveRespondTime(sa) : unsetRespondTimeMs;
        final rb = sb != null ? effectiveRespondTime(sb) : unsetRespondTimeMs;
        final byTime = ra.compareTo(rb);
        if (byTime != 0) return byTime;
        final byOrigins = b.origins.length.compareTo(a.origins.length);
        if (byOrigins != 0) return byOrigins;
        return a.bookUrl.compareTo(b.bookUrl);
      }
      final byBucket = searchMatchBucket(
        a,
        query,
      ).compareTo(searchMatchBucket(b, query));
      if (byBucket != 0) return byBucket;
      final byOrigins = b.origins.length.compareTo(a.origins.length);
      if (byOrigins != 0) return byOrigins;
      final ida = SearchMerge.identity(a);
      final idb = SearchMerge.identity(b);
      final byScore = (_score[idb] ?? 0).compareTo(_score[ida] ?? 0);
      if (byScore != 0) return byScore;
      return a.bookUrl.compareTo(b.bookUrl);
    });
    if (precise) {
      books = books
          .where((b) => keepSearchBook(b, query, precise: true))
          .toList();
    }
    final out = [
      for (final b in books)
        (
          _byOrigin[b.origin] ??
              BookSource(bookSourceUrl: b.origin, bookSourceName: b.originName),
          b,
        ),
    ];
    _snap = out;
    _snapPrecise = precise;
    return out;
  }
}
