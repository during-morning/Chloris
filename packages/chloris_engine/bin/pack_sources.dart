import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';

Directory _findRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    final isRepo = Directory('${dir.path}/reference/开源阅读').existsSync() &&
        File('${dir.path}/packages/chloris_engine/pubspec.yaml').existsSync();
    if (isRepo) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) return Directory.current;
    dir = parent;
  }
}

void main() {
  final root = _findRoot();
  final srcDir = Directory('${root.path}/reference/开源阅读/书源管理');
  final files = [
    '【最推荐】超级精选书源（强烈推荐！）最强.json',
    '国内小说网文整合@小霖子.json',
    '【阅读】轻小说书源@小霖子.json',
    '【阅读】漫画书源@小霖子.json',
    '【阅读】总书源@小霖子.json',
    'data.json',
  ];

  final byUrl = <String, BookSource>{};
  final enabledUrls = <String>{};
  for (final name in files) {
    final f = File('${srcDir.path}/$name');
    if (!f.existsSync()) continue;
    final list =
        BookSource.listFromJson(jsonDecode(f.readAsStringSync()));
    for (final s in list) {
      if (s.bookSourceType != BookSourceType.text &&
          s.bookSourceType != BookSourceType.audio &&
          s.bookSourceType != BookSourceType.image) {
        continue;
      }
      if (s.bookSourceUrl.isEmpty || s.bookSourceName.isEmpty) continue;
      final key = s.bookSourceUrl
          .replaceAll(RegExp(r'/$'), '')
          .toLowerCase();
      if (!byUrl.containsKey(key)) {
        byUrl[key] = s;
      }
      if (name.startsWith('【最推荐】') && s.hasCompleteRules) {
        enabledUrls.add(key);
      }
    }
  }

  final out = byUrl.entries.map((e) {
    final s = e.value;
    s.enabled = enabledUrls.contains(e.key);
    return s.toJson();
  }).toList();
  final destDir = Directory('${root.path}/chloris/assets/sources');
  destDir.createSync(recursive: true);
  File('${destDir.path}/default_book_sources.json').writeAsStringSync(
    const JsonEncoder().convert(out),
  );

  final replaceFiles = [
    '${root.path}/reference/开源阅读/净化替换规则/【阅读】净化规则@小霖子.json',
    '${root.path}/reference/开源阅读/净化替换规则/净化规则by烏雲【V3版】20.03.15.json',
  ];
  final replaces = <int, ReplaceRule>{};
  for (final path in replaceFiles) {
    final f = File(path);
    if (!f.existsSync()) continue;
    for (final r in ReplaceRule.listFromJson(
        jsonDecode(f.readAsStringSync()))) {
      replaces[r.id ?? r.name.hashCode] = r;
    }
  }
  File('${destDir.path}/default_replace_rules.json').writeAsStringSync(
    const JsonEncoder().convert(
      replaces.values.map((e) => e.toJson()).toList(),
    ),
  );

  final tocFiles = [
    '${root.path}/reference/开源阅读/目录规则/整合目录规则@小霖子.json',
    '${root.path}/reference/legado-E-main/app/src/main/assets/defaultData/txtTocRule.json',
  ];
  final tocs = <String, TxtTocRule>{};
  for (final path in tocFiles) {
    final f = File(path);
    if (!f.existsSync()) continue;
    for (final r in TxtTocRule.listFromJson(
        jsonDecode(f.readAsStringSync()))) {
      tocs['${r.name}|${r.rule}'] = r;
    }
  }
  File('${destDir.path}/default_txt_toc_rules.json').writeAsStringSync(
    const JsonEncoder().convert(
      tocs.values.map((e) => e.toJson()).toList(),
    ),
  );

  // 订阅源（RSS）去重打包
  final rssFile =
      File('${root.path}/reference/开源阅读/订阅源/【阅读】小霖子整合订阅.json');
  if (rssFile.existsSync()) {
    final rssByUrl = <String, Map<String, dynamic>>{};
    for (final e in jsonDecode(rssFile.readAsStringSync()) as List) {
      if (e is! Map) continue;
      final m = e.map((k, v) => MapEntry(k.toString(), v)).cast<String, dynamic>();
      final url = m['sourceUrl']?.toString() ?? '';
      if (url.isEmpty) continue;
      rssByUrl.putIfAbsent(url, () => m);
    }
    File('${destDir.path}/default_rss_sources.json').writeAsStringSync(
      const JsonEncoder().convert(rssByUrl.values.toList()),
    );
  }

  // 字典规则去重打包
  final dictFile =
      File('${root.path}/reference/开源阅读/字典规则/字典规则@小霖子.json');
  if (dictFile.existsSync()) {
    final dictByName = <String, Map<String, dynamic>>{};
    for (final e in jsonDecode(dictFile.readAsStringSync()) as List) {
      if (e is! Map) continue;
      final m = e.map((k, v) => MapEntry(k.toString(), v)).cast<String, dynamic>();
      final name = m['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      dictByName.putIfAbsent(name, () => m);
    }
    File('${destDir.path}/default_dict_rules.json').writeAsStringSync(
      const JsonEncoder().convert(dictByName.values.toList()),
    );
  }

  stdout.writeln(
    'packed sources=${out.length} enabled=${enabledUrls.length} '
    'replace=${replaces.length} toc=${tocs.length}',
  );
}
