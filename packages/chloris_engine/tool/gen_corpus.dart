/// 生成 legado 规则语料库（golden corpus）。
///
/// 真实规则来源：chloris/assets/sources/*.json 中的默认/已验证书源。
/// 从每个书源的 ruleSearch / ruleBookInfo / ruleToc / ruleContent / ruleExplore
/// 抽取规则字符串，用「当前引擎行为快照」（RuleCompiler 编译出的 RuleProgram
/// IR）作为回归基线——这是防未来回归的快照，不是等价性证明。
///
/// 用法（在 packages/chloris_engine 下）：
///   dart run tool/gen_corpus.dart
/// 可重复运行；输出写入 test/golden/legado_rule_corpus.json。
library;

import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';

const String kBaseline = 'self-2026-09-12';

/// 简单的路径拼接（避免引入 path 包依赖）。仅在绝对路径 + '/' 分隔下使用。
String joinPath(String base, List<String> parts) =>
    [base, ...parts].join('/');

/// 每个阶段对应的规则对象字段（来自 lib/src/models/rules.dart）。
const Map<String, Map<String, List<String>>> kStageFields = {
  'search': {
    'ruleSearch': [
      'checkKeyWord',
      'bookList',
      'name',
      'author',
      'intro',
      'kind',
      'lastChapter',
      'updateTime',
      'bookUrl',
      'coverUrl',
      'wordCount',
    ],
  },
  'detail': {
    'ruleBookInfo': [
      'init',
      'name',
      'author',
      'intro',
      'kind',
      'lastChapter',
      'updateTime',
      'coverUrl',
      'tocUrl',
      'wordCount',
      'canReName',
      'downloadUrls',
    ],
  },
  'toc': {
    'ruleToc': [
      'preUpdateJs',
      'chapterList',
      'chapterName',
      'chapterUrl',
      'formatJs',
      'isVolume',
      'isVip',
      'isPay',
      'updateTime',
      'nextTocUrl',
    ],
  },
  'content': {
    'ruleContent': [
      'content',
      'subContent',
      'title',
      'nextContentUrl',
      'webJs',
      'sourceRegex',
      'replaceRegex',
      'imageStyle',
      'imageDecode',
      'payAction',
      'callBackJs',
    ],
  },
  'explore': {
    'ruleExplore': [
      'bookList',
      'name',
      'author',
      'intro',
      'kind',
      'lastChapter',
      'updateTime',
      'bookUrl',
      'coverUrl',
      'wordCount',
    ],
  },
};

/// 后端推断（对齐 Legado 规则约定）：
/// 以 `/` 开头（含 `//`）为 XPath；`@xpath:`/`@json:`/`$` 为对应后端；
/// `@js:`/`@webjs:` 为内嵌脚本；其余默认 CSS。
String inferBackend(String rule) {
  final e = rule.trim();
  final lower = e.toLowerCase();
  if (lower.startsWith('@css:') || e.startsWith('@@')) return 'css';
  if (lower.startsWith('@xpath:')) return 'xpath';
  if (lower.startsWith('@json:')) return 'json';
  if (e.startsWith(r'$.') || e.startsWith(r'$[')) return 'json';
  if (lower.startsWith('@js:') || lower.startsWith('@webjs:')) return 'js';
  if (e.startsWith('/')) return 'xpath';
  return 'css';
}

RuleProgram compileFor(String rule, String backend) {
  final allInOne = rule.trim().startsWith(':');
  return const RuleCompiler().compile(
    rule,
    isJson: backend == 'json',
    isRegex: backend == 'regex',
    allInOne: allInOne,
  );
}

void main(List<String> args) {
  final repoRoot = _repoRoot();
  final sourcesDir = Directory(joinPath(repoRoot, [
    'chloris',
    'assets',
    'sources',
  ]));
  if (!sourcesDir.existsSync()) {
    stderr.writeln('未找到书源目录: ${sourcesDir.path}');
    exit(1);
  }

  final sourceFiles = sourcesDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  stderr.writeln('扫描书源文件: ${sourceFiles.length} 个');

  // 以规则原文去重，保留首次出现的 (来源, 阶段, 字段)。
  final byRule = <String, Map<String, dynamic>>{};
  final sourceCount = <String, int>{};
  var scanned = 0;

  for (final file in sourceFiles) {
    late dynamic raw;
    try {
      raw = jsonDecode(file.readAsStringSync());
    } catch (e) {
      stderr.writeln('跳过无法解析的书源文件 ${file.path}: $e');
      continue;
    }
    final list = raw is List ? raw : [raw];
    for (final item in list) {
      if (item is! Map) continue;
      final sourceUrl = JsonKit.stringOr(item['bookSourceUrl']);
      final sourceName = JsonKit.stringOr(item['bookSourceName']);
      final sourceId =
          sourceUrl.isNotEmpty ? sourceUrl : sourceName.isNotEmpty ? sourceName : '<unknown>';
      if (sourceId == '<unknown>') continue;

      for (final stageEntry in kStageFields.entries) {
        final stage = stageEntry.key;
        for (final objEntry in stageEntry.value.entries) {
          final objKey = objEntry.key;
          final fields = objEntry.value;
          final obj = item[objKey];
          if (obj is! Map) continue;
          for (final field in fields) {
            final value = obj[field];
            if (value is! String) continue;
            final rule = value.trim();
            if (rule.isEmpty) continue;
            // 跳过超长规则（多为整段 JS）以保证语料可读且测试可控。
            if (rule.length > 2000) continue;
            scanned++;
            if (byRule.containsKey(rule)) continue;
            final backend = inferBackend(rule);
            try {
              final program = compileFor(rule, backend);
              byRule[rule] = {
                'rule': rule,
                'source': sourceId,
                'stage': stage,
                'field': '$objKey.$field',
                'backend': backend,
                'allInOne': rule.startsWith(':'),
                'ir': program.toJson(),
              };
              sourceCount[sourceId] = (sourceCount[sourceId] ?? 0) + 1;
            } catch (e) {
              // 个别规则无法编译则跳过，不影响整体。
              stderr.writeln('跳过无法编译的规则 ($sourceId/$stage/$field): $e');
            }
          }
        }
      }
    }
  }

  // 按后端分层抽样：每个后端取代表性规则（短规则优先），保证语料覆盖
  // css/json/xpath/js/regex，既作为回归基线也有基准可用性。
  const perBackendCap = {
    'css': 300,
    'json': 80,
    'xpath': 60,
    'js': 20,
    'regex': 40,
  };
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final e in byRule.values) {
    grouped.putIfAbsent(e['backend'] as String, () => []).add(e);
  }
  final kept = <Map<String, dynamic>>[];
  for (final entry in perBackendCap.entries) {
    final group = grouped[entry.key];
    if (group == null) continue;
    group.sort(
      (a, b) => (a['rule'] as String).length.compareTo(
            (b['rule'] as String).length,
          ),
    );
    kept.addAll(group.take(entry.value));
  }
  // 兜底：若分层后仍不足 200，按长度补满短规则。
  if (kept.length < 200) {
    final seen = <String>{for (final e in kept) e['rule'] as String};
    final rest = byRule.values
        .where((e) => !seen.contains(e['rule']))
        .toList()
      ..sort(
        (a, b) => (a['rule'] as String).length.compareTo(
              (b['rule'] as String).length,
            ),
      );
    kept.addAll(rest.take(200 - kept.length));
  }

  // 统计分布
  final stageDist = <String, int>{};
  final backendDist = <String, int>{};
  for (final e in kept) {
    final stage = e['stage'] as String;
    stageDist[stage] = (stageDist[stage] ?? 0) + 1;
    final b = e['backend'] as String;
    backendDist[b] = (backendDist[b] ?? 0) + 1;
  }

  final out = {
    'baseline': kBaseline,
    'generatedAt': DateTime.now().toIso8601String(),
    'generatedBy': 'tool/gen_corpus.dart',
    'note':
        '本语料为「当前引擎行为快照」(self-baseline)，用于防未来回归，'
        '并非规则与 Legado 的等价性证明。每条 ir 字段是 RuleCompiler 编译出的 '
        'RuleProgram IR，重跑引擎重新编译后须与存储值一致。',
    'sourceFiles': sourceFiles
        .map((f) => f.path.split(Platform.pathSeparator).last)
        .toList(),
    'scannedRules': scanned,
    'uniqueRules': byRule.length,
    'count': kept.length,
    'stageDistribution': stageDist,
    'backendDistribution': backendDist,
    'entries': kept,
  };

  final outPath = args.isNotEmpty
      ? args.first
      : joinPath(repoRoot, [
          'packages',
          'chloris_engine',
          'test',
          'golden',
          'legado_rule_corpus.json',
        ]);
  File(outPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(out),
    );

  stderr.writeln('扫描规则字符串: $scanned 条, 去重后唯一: ${byRule.length} 条');
  stderr.writeln('写入语料: ${kept.length} 条 -> $outPath');
  stderr.writeln('阶段分布: $stageDist');
  stderr.writeln('后端分布: $backendDist');
  stderr.writeln('来源数量: ${sourceCount.length} 个');
}

String _repoRoot() {
  // tool/gen_corpus.dart -> packages/chloris_engine/tool -> repo root = 3 级上。
  final script = File(Platform.script.toFilePath()).parent;
  return script.parent.parent.parent.path;
}
