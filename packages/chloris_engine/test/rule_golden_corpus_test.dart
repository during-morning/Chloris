import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

const String kExpectedBaseline = 'self-2026-09-12';

void main() {
  final path = 'test/golden/legado_rule_corpus.json';
  final raw = File(path).readAsStringSync();
  final doc = jsonDecode(raw) as Map<String, dynamic>;
  final entries = (doc['entries'] as List).cast<Map<String, dynamic>>();

  test('corpus 元信息：基线标记与规模', () {
    expect(doc['baseline'], kExpectedBaseline,
        reason: '必须为当前引擎行为快照基线');
    expect(entries.length, greaterThanOrEqualTo(200),
        reason: '语料规模需 ≥ 200 条');
    // 阶段与后端覆盖检查
    final stages = entries.map((e) => e['stage'] as String).toSet();
    expect(stages, containsAll(<String>['search', 'detail', 'toc', 'content']));
    final backends = entries.map((e) => e['backend'] as String).toSet();
    expect(backends, containsAll(<String>['css', 'json', 'xpath']));
  });

  test('corpus 每条规则的引擎编译产物与快照一致（防回归）', () {
    final compiler = const RuleCompiler();
    for (final e in entries) {
      final rule = e['rule'] as String;
      final backend = e['backend'] as String;
      final allInOne = e['allInOne'] as bool? ?? false;
      final program = compiler.compile(
        rule,
        isJson: backend == 'json',
        isRegex: backend == 'regex',
        allInOne: allInOne,
      );
      final actual = program.toJson();
      final expected = e['ir'] as Map<String, dynamic>;
      expect(jsonEncode(actual), jsonEncode(expected),
          reason: '${e['source']} / ${e['stage']} / ${e['field']} :: $rule');
    }
  });
}
