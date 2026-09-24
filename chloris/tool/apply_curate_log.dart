// dart run tool/apply_curate_log.dart
// 把实搜日志落成默认书源（探测进程退出码异常时的补写）。
import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris/features/sources/source_unify.dart';

const originFiles = <(String, int)>[
  ('/Volumes/Software/ChlorisA/reference/开源阅读/书源管理/【最推荐】超级精选书源（强烈推荐！）最强.json', 40),
  ('/Volumes/Software/ChlorisA/reference/开源阅读/书源管理/data.json', 25),
  ('/Volumes/Software/ChlorisA/reference/开源阅读/书源管理/【阅读】轻小说书源@小霖子.json', 20),
  ('/Volumes/Software/ChlorisA/reference/开源阅读/书源管理/国内小说网文整合@小霖子.json', 15),
  ('/Volumes/Software/ChlorisA/reference/开源阅读/书源管理/【阅读】漫画书源@小霖子.json', 12),
  ('/Volumes/Software/ChlorisA/reference/开源阅读/书源管理/【阅读】总书源@小霖子.json', 8),
  ('tool/archive/default_book_sources.all.json', 5),
];

final _ok = RegExp(r'^OK (\d+)ms n=(\d+) q=(\S+) \[([^\]]+)\] (.+)$');

Future<void> main() async {
  final ranked = <(BookSource, int)>[];
  for (final (path, preferred) in originFiles) {
    final file = File(path);
    if (!file.existsSync()) continue;
    for (final s in BookSource.listFromJson(jsonDecode(await file.readAsString()))) {
      ranked.add((s, preferred));
    }
  }
  final merged = mergeBookSources(ranked);
  final byKey = <String, List<BookSource>>{};
  final byName = <String, List<BookSource>>{};
  for (final s in merged) {
    byKey.putIfAbsent('${s.bookSourceGroup}|${s.bookSourceName}', () => []).add(s);
    byName.putIfAbsent(s.bookSourceName, () => []).add(s);
  }

  final alive = <BookSource>[];
  final seen = <String>{};
  for (final line in await File('/tmp/curate_sources.log').readAsLines()) {
    final m = _ok.firstMatch(line);
    if (m == null) continue;
    final elapsed = int.parse(m[1]!);
    final hitCount = int.parse(m[2]!);
    final group = m[4]!;
    final name = m[5]!;
    var matches = [
      ...?byKey['$group|$name'],
    ].where((s) => !seen.contains(s.bookSourceUrl)).toList();
    if (matches.isEmpty) {
      matches = (byName[name] ?? const <BookSource>[])
          .where((s) => !seen.contains(s.bookSourceUrl))
          .toList();
    }
    if (matches.isEmpty) continue;
    matches.sort((a, b) => sourceQualityScore(b).compareTo(sourceQualityScore(a)));
    final source = matches.first;
    if (!seen.add(source.bookSourceUrl)) continue;
    source.enabled = true;
    source.respondTime = elapsed;
    source.weight = 50 +
        (source.hasCompleteRules ? 30 : 0) +
        (isHttpSearch(source) ? 15 : 0) +
        (hitCount > 20 ? 20 : hitCount);
    if (elapsed > 8000) source.weight -= 10;
    alive.add(source);
  }

  final picked = pickBestPerHost(alive, perHost: 2);
  final counts = <String, int>{};
  for (final s in picked) {
    counts[s.bookSourceGroup ?? '其他'] =
        (counts[s.bookSourceGroup ?? '其他'] ?? 0) + 1;
  }
  final jsonOut = const JsonEncoder.withIndent('  ')
      .convert(picked.map((s) => s.toJson()).toList());
  await File('assets/sources/verified_book_sources.json').writeAsString(jsonOut);
  await File('assets/sources/default_book_sources.json').writeAsString(jsonOut);
  await File('tool/archive/default_book_sources.all.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(
      merged.map((s) => s.toJson()).toList(),
    ),
  );
  stdout.writeln('alive=${alive.length} picked=${picked.length} groups=$counts');
}
