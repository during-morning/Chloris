import 'package:chloris_engine/chloris_engine.dart';

import 'search_models.dart';
import 'search_schedule.dart';

String normalizeSearchText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[\u3000\s\-_:：，,。.!！?？]+'), '')
    .replaceAll('臺', '台')
    .replaceAll('台灣', '台湾')
    .replaceAll('萬', '万')
    // Common variants seen in source titles/authors.  This is deliberately a
    // small, deterministic fold rather than a broad locale transliteration;
    // it keeps merge identities stable across platforms.
    .replaceAll('繁體', '繁体')
    .replaceAll('後', '后')
    .replaceAll('與', '与')
    .replaceAll('國', '国')
    .replaceAll('學', '学')
    .replaceAll('說', '说')
    .replaceAll('傳', '传');

final _chapterLikeName = RegExp(
  r'^(第[0-9零一二三四五六七八九十百千万两]+[页章节回话部集卷篇]|目录|正文|内容简介|章节目录|最新章节)([：:\s].*)?$',
);

final _siteLikeName = RegExp(
  r'(小说网|电子书|阅读网|书城|书屋|文学网|^UC小说$|^笔趣阁$|^顶点小说$|^起点$|^番茄$|^七猫$)',
);

int searchMatchScore(SearchBook book, String query) {
  final n = normalizeSearchText(book.name);
  final a = normalizeSearchText(book.author);
  final intro = normalizeSearchText(book.intro ?? '');
  final k = normalizeSearchText(query);
  if (k.isEmpty) return 0;
  if (n == k) return 1000;
  if (n.startsWith(k) || k.startsWith(n)) return 850;
  final ni = n.indexOf(k);
  if (ni >= 0) return 700 - ni.clamp(0, 100);
  if (k.contains(n) && n.length >= 2) return 650;
  if (a == k) return 520;
  if (a.contains(k) || (a.length >= 2 && k.contains(a))) return 300;
  final kind = normalizeSearchText(book.kind ?? '');
  if (kind == k && k.isNotEmpty) return 340;
  if (kind.contains(k) && k.isNotEmpty) return 320;
  if (intro.contains(k)) return 120;
  return 0;
}

/// Legado's BookList/SearchModel bucket order.  Keep this separate from the
/// user-facing score: an exact author match belongs to the same `equal`
/// bucket as an exact title, while a kind/tag hit must stay ahead of a loose
/// title/author containment hit.
int searchMatchBucket(SearchBook book, String query) {
  final k = normalizeSearchText(query);
  if (k.isEmpty) return 3;
  final n = normalizeSearchText(book.name);
  final a = normalizeSearchText(book.author);
  if (n == k || a == k) return 0; // equal
  final kind = normalizeSearchText(book.kind ?? '');
  if (kind.contains(k)) return 1; // tags/kind
  if (n.contains(k) || a.contains(k)) return 2; // contains
  return 3; // other
}

/// How much of [query] is covered by name/author (LCS / query length).
double searchMatchRatio(SearchBook book, String query) {
  final k = normalizeSearchText(query);
  if (k.isEmpty) return 1;
  final n = normalizeSearchText(book.name);
  final a = normalizeSearchText(book.author);
  final nr = _coverRatio(n, k);
  final ar = _coverRatio(a, k);
  return nr > ar ? nr : ar;
}

double _coverRatio(String text, String query) {
  if (text.isEmpty || query.isEmpty) return 0;
  if (text.contains(query)) return 1;
  if (query.contains(text) && text.length >= 2) {
    return text.length / query.length;
  }
  return _lcsLen(text, query) / query.length;
}

int _lcsLen(String a, String b) {
  if (a.length > 48) a = a.substring(0, 48);
  if (b.length > 48) b = b.substring(0, 48);
  final m = a.length;
  final n = b.length;
  var prev = List<int>.filled(n + 1, 0);
  var curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      curr[j] = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1)
          ? prev[j - 1] + 1
          : (prev[j] > curr[j - 1] ? prev[j] : curr[j - 1]);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}

/// 基础单字（我/你/的）：几乎每本书都能“匹配”，不能按书名分排序或 40% 过滤。
bool isBasicSingleCharQuery(String query) => query.trim().length == 1;

List<(BookSource, SearchBook)> mergeSearchRows(
  List<SourceSearchResult> rows,
  String query, {
  bool precise = false,
}) {
  final byOrigin = <String, BookSource>{};
  var merged = <SearchBook>[];
  for (final r in rows) {
    byOrigin[r.source.bookSourceUrl] = r.source;
    final usable = r.books
        .where((b) => isUsableSearchBook(b, query: query))
        .toList();
    for (final b in usable) {
      if (b.origin.trim().isEmpty) {
        b.origin = r.source.bookSourceUrl;
        if (b.originName.trim().isEmpty) b.originName = r.source.bookSourceName;
        b.originOrder = r.source.customOrder;
      }
    }
    if (usable.isEmpty) continue;
    merged = SearchMerge.merge(existing: merged, incoming: usable, key: query);
  }
  final single = isBasicSingleCharQuery(query);
  merged.sort((a, b) {
    if (single) {
      final sa = byOrigin[a.origin];
      final sb = byOrigin[b.origin];
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
    final byScore = searchMatchScore(
      b,
      query,
    ).compareTo(searchMatchScore(a, query));
    if (byScore != 0) return byScore;
    return a.bookUrl.compareTo(b.bookUrl);
  });
  if (precise) {
    merged = merged
        .where((b) => keepSearchBook(b, query, precise: true))
        .toList();
  }
  return [
    for (final b in merged)
      (
        byOrigin[b.origin] ??
            BookSource(bookSourceUrl: b.origin, bookSourceName: b.originName),
        b,
      ),
  ];
}

bool isUsableSearchBook(SearchBook book, {String query = ''}) {
  final name = book.name.trim();
  final url = book.bookUrl.trim();
  if (name.length < 2 || url.isEmpty) return false;
  final lower = name.toLowerCase();
  const placeholders = {
    '未知书籍',
    '未知',
    '无标题',
    '暂无数据',
    '搜索结果',
    '详情页',
    'book',
    'null',
    'undefined',
  };
  if (placeholders.contains(lower) ||
      lower.contains('验证码') ||
      lower.contains('登录') ||
      lower.contains('词典') ||
      lower.contains('字典') ||
      isChromeBookName(name) ||
      (isChromeBookUrl(url) && name.length <= 8)) {
    return false;
  }
  if (_chapterLikeName.hasMatch(name) || _siteLikeName.hasMatch(name)) {
    return false;
  }
  final originName = book.originName.trim();
  if (originName.isNotEmpty && name == originName) return false;
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.hasScheme || url.startsWith('/'))) return false;
  final hasPath = uri.path.isNotEmpty && uri.path != '/';
  final hasQuery = uri.hasQuery && uri.query.trim().isNotEmpty;
  if (!hasPath && !hasQuery) return false;
  return true;
}

/// Legado precise search keeps name/author/kind contains. Non-precise keeps
/// the `other` bucket so a source that returned books is not emptied by LCS.
bool keepSearchBook(SearchBook book, String query, {bool precise = false}) {
  if (!precise) return true;
  return searchMatchBucket(book, query) <= 2;
}

/// BookList-level filter used by precise search, matching Legado's
/// name/author/kind containment check before a source result is kept.
bool Function(String name, String author, String? kind)? preciseSearchFilter(
  String query, {
  bool precise = false,
}) {
  if (!precise) return null;
  return (name, author, kind) => keepSearchBook(
    SearchBook(
      bookUrl: 'https://filter.local/?q=1',
      name: name,
      author: author,
      kind: kind,
    ),
    query,
    precise: true,
  );
}
