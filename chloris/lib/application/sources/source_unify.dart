import 'package:chloris_engine/chloris_engine.dart';

/// 统一分区：阅读器书源列表只展示这些组。
const unifiedSourceGroups = <String>[
  '小说',
  '轻小说',
  '漫画',
  '听书',
  '出版',
  '正版',
  '影视',
  '其他',
];

/// 启用集分区上限（有活源才填；下限在选优脚本里保证）。
const unifiedGroupCaps = <String, int>{
  '小说': 500,
  '轻小说': 60,
  '漫画': 100,
  '听书': 40,
  '出版': 20,
  '正版': 40,
  '影视': 20,
  '其他': 40,
};

bool isAdultSourceLabel(String raw) =>
    raw.contains('🔞') || raw.contains('18+') || raw.contains('成人');

bool isDictionarySourceLabel(String raw) =>
    raw.contains('词典') ||
    raw.contains('字典') ||
    raw.contains('海词') ||
    raw.contains('翻译') ||
    raw.contains('成语');

String canonicalizeSourceUrl(String url) {
  final t = url.trim();
  if (t.isEmpty) return '';
  final uri = Uri.tryParse(t);
  if (uri == null || uri.host.isEmpty) {
    return t.replaceAll(RegExp(r'/$'), '').toLowerCase();
  }
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  var path = uri.path;
  if (path == '/') {
    path = '';
  } else if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final scheme = uri.scheme.isEmpty ? 'http' : uri.scheme.toLowerCase();
  return '$scheme://$host$path';
}

String displaySourceGroup(BookSource source) {
  final g = source.bookSourceGroup ?? '';
  if (unifiedSourceGroups.contains(g)) return g;
  return unifySourceGroup(source);
}

String sourceHostKey(BookSource source) {
  final uri = Uri.tryParse(source.bookSourceUrl);
  final host = uri?.host ?? source.bookSourceUrl;
  return host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
}

bool isHttpSearch(BookSource source) {
  final u = (source.searchUrl ?? '').trim().toLowerCase();
  return u.startsWith('http://') || u.startsWith('https://');
}

/// 从书源类型 + 原始分组名归到统一分区。
String unifySourceGroup(BookSource source) {
  final raw = '${source.bookSourceGroup ?? ''} ${source.bookSourceName}';
  final t = source.bookSourceType;
  if (t == BookSourceType.audio || raw.contains('听书')) return '听书';
  if (t == BookSourceType.image || raw.contains('漫画')) return '漫画';
  if (t == BookSourceType.video || raw.contains('影视')) return '影视';
  if (raw.contains('轻小说')) return '轻小说';
  if (raw.contains('出版')) return '出版';
  if (raw.contains('正版')) return '正版';
  if (t == BookSourceType.text || raw.contains('小说')) return '小说';
  return '其他';
}

int sourceQualityScore(BookSource source, {int preferred = 0}) {
  var score = preferred;
  if (source.enabled) score += 2;
  if (source.hasSearch) score += 4;
  if (source.hasCompleteRules) score += 6;
  if (isHttpSearch(source)) score += 3;
  if ((source.ruleSearch?.bookList ?? '').trim().isNotEmpty) score += 2;
  if ((source.ruleToc?.chapterList ?? '').trim().isNotEmpty) score += 2;
  if ((source.ruleContent?.content ?? '').trim().isNotEmpty) score += 2;
  return score;
}

bool shouldDropSource(BookSource source) {
  final raw = '${source.bookSourceGroup ?? ''}${source.bookSourceName}';
  if (source.bookSourceUrl.trim().isEmpty) return true;
  if (source.bookSourceName.trim().isEmpty) return true;
  if (isAdultSourceLabel(raw) || isDictionarySourceLabel(raw)) return true;
  if (source.bookSourceType == BookSourceType.file) return true;
  if (!source.hasSearch && !source.hasExploreUrl) return true;
  return false;
}

/// 同 URL 留规则更完整、来源更优先的一条。
List<BookSource> mergeBookSources(List<(BookSource, int)> ranked) {
  final best = <String, (int, BookSource)>{};
  for (final (source, preferred) in ranked) {
    if (shouldDropSource(source)) continue;
    final url = canonicalizeSourceUrl(source.bookSourceUrl);
    if (url.isEmpty) continue;
    final score = sourceQualityScore(source, preferred: preferred);
    final prev = best[url];
    if (prev == null || score >= prev.$1) {
      source.bookSourceUrl = url;
      source.bookSourceGroup = unifySourceGroup(source);
      source.enabled = false;
      best[url] = (score, source);
    }
  }
  return [for (final e in best.values) e.$2];
}

/// 按统一分区裁剪启用集。
List<BookSource> applyGroupQuotas(
  List<BookSource> sources, {
  Map<String, int> caps = unifiedGroupCaps,
}) {
  final unique = <String, BookSource>{};
  for (final s in sources) {
    final key = canonicalizeSourceUrl(s.bookSourceUrl);
    if (key.isEmpty) continue;
    s.bookSourceUrl = key;
    final prev = unique[key];
    if (prev == null || s.weight >= prev.weight) unique[key] = s;
  }
  final buckets = <String, List<BookSource>>{};
  for (final s in unique.values) {
    final g = displaySourceGroup(s);
    s.bookSourceGroup = g;
    buckets.putIfAbsent(g, () => []).add(s);
  }
  final out = <BookSource>[];
  for (final g in unifiedSourceGroups) {
    final list = buckets[g];
    if (list == null || list.isEmpty) continue;
    list.sort((a, b) {
      final w = b.weight.compareTo(a.weight);
      if (w != 0) return w;
      return a.respondTime.compareTo(b.respondTime);
    });
    out.addAll(list.take(caps[g] ?? 12));
  }
  for (var i = 0; i < out.length; i++) {
    out[i].customOrder = i;
    out[i].enabled = true;
  }
  return out;
}

/// 同主机最多保留 [perHost] 条，按 weight / 响应时间排序。
List<BookSource> pickBestPerHost(List<BookSource> sources, {int perHost = 2}) {
  final byHost = <String, List<BookSource>>{};
  for (final s in sources) {
    byHost.putIfAbsent(sourceHostKey(s), () => []).add(s);
  }
  final out = <BookSource>[];
  for (final list in byHost.values) {
    list.sort((a, b) {
      final w = b.weight.compareTo(a.weight);
      if (w != 0) return w;
      return a.respondTime.compareTo(b.respondTime);
    });
    out.addAll(list.take(perHost));
  }
  out.sort((a, b) {
    final g = unifiedSourceGroups
        .indexOf(a.bookSourceGroup ?? '其他')
        .compareTo(unifiedSourceGroups.indexOf(b.bookSourceGroup ?? '其他'));
    if (g != 0) return g;
    final w = b.weight.compareTo(a.weight);
    if (w != 0) return w;
    return a.respondTime.compareTo(b.respondTime);
  });
  for (var i = 0; i < out.length; i++) {
    out[i].customOrder = i;
    out[i].enabled = true;
  }
  return out;
}
