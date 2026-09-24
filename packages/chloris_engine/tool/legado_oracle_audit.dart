import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';

/// Bilateral parity runner.
///
/// Builds fixtures that exercise the real Chloris backends on the `run()` side
/// and the real Legado-E backends (via [LegadoProcessOracle]) on the oracle
/// side, then lets [EquivalenceAudit] diff them field-by-field. When the judge
/// process is unavailable it falls back to [SelfBaselineOracle] and prints a
/// clear "not bilateral" banner so CI never silently trusts a self-comparison.
void main(List<String> args) async {
  final outPath =
      _option(args, '--out') ??
      'artifacts/verification/20260912-rule-engine-parity/equivalence-bilateral.json';

  final fixtures = _buildFixtures();

  final oracle = await LegadoProcessOracle.tryCreate();
  final bilateral = oracle != null;
  final EquivalenceOracle usedOracle =
      (oracle as EquivalenceOracle?) ?? const SelfBaselineOracle();

  if (!bilateral) {
    stderr.writeln(
      '[legado-oracle] judge unavailable (no JDK / launcher not built / '
      'LEGADO_ORACLE_SKIP=1). Falling back to SelfBaselineOracle — '
      'this run is NOT a bilateral differential.',
    );
  }

  final report = await EquivalenceAudit(oracle: usedOracle).run(fixtures);

  final outFile = File(outPath);
  await outFile.parent.create(recursive: true);
  await outFile.writeAsString(report.toJsonString(pretty: true));

  _printSummary(report, bilateral, outFile.path);
}

List<EquivalenceFixture> _buildFixtures() {
  // Fixtures live in tool/legado_oracle/fixtures/*.json as JSON arrays of
  // {id, kind, rule, content, expect, src}. They are sampled from real book
  // sources (chloris/assets/sources/*.json) and exercise the same four backends
  // the oracle bridges. Only backend-pure rule fragments are kept so the partial
  // Legado oracle and Chloris exercise identical semantics; divergences below
  // therefore reflect real engine differences.
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final fixtureDir = '${scriptDir.path}/legado_oracle/fixtures';
  final names = [
    'css.json',
    'json.json',
    'stage1-regex.json',
    'regex-multiline.json',
  ];
  final out = <EquivalenceFixture>[];
  for (final name in names) {
    final file = File('$fixtureDir/$name');
    if (!file.existsSync()) {
      stderr.writeln('[legado-oracle] fixture missing: $name');
      continue;
    }
    final List<dynamic> arr = jsonDecode(file.readAsStringSync());
    for (final raw in arr) {
      final m = raw as Map<String, dynamic>;
      final kind = m['kind'] as String;
      final rule = m['rule'] as String;
      final content = m['content'] as String;
      out.add(
        EquivalenceFixture(
          id: 'legado/${m['id']}',
          stage: 'rule',
          input: <String, Object?>{
            'name': m['id'],
            'kind': kind,
            'fallback': kind,
            'rule': rule,
            'input': content,
            'expect': m['expect'],
            'src': m['src'],
          },
          run: () => _run(kind, rule, content),
        ),
      );
    }
  }
  return out;
}

Map<String, Object?> _run(String kind, String rule, String content) {
  switch (kind) {
    case 'regex':
      // Split on `%%` so Chloris chains stages the same way the oracle does
      // (Main.kt: rule.split("%%")). A bare pattern stays a single-element list.
      return {
        'mode': 'regex',
        'expression': rule,
        'value': AnalyzeByRegex.getElement(content, rule.split('%%')),
      };
    case 'css':
      return {
        'mode': 'css',
        'expression': rule,
        'value': AnalyzeByCss(content).getString(rule),
      };
    case 'xpath':
      return {
        'mode': 'xpath',
        'expression': rule,
        'value': AnalyzeByXPath(content).getString(rule),
      };
    case 'json':
      return {
        'mode': 'json',
        'expression': rule,
        'value': AnalyzeByJsonPath(content).getString(rule),
      };
    default:
      return {'mode': kind, 'expression': rule, 'value': null};
  }
}

void _printSummary(EquivalenceReport report, bool bilateral, String path) {
  final m = report.metrics;
  stdout.writeln(
    jsonEncode({
      'oracle': report.oracle,
      'bilateral': bilateral,
      'selfBaseline': report.selfBaseline,
      'totalCases': m.totalCases,
      'passedCases': m.passedCases,
      'failedCases': m.failedCases,
      'passRate': m.passRate,
      'artifact': path,
    }),
  );
  for (final c in report.cases) {
    final status = c.passed ? 'PASS' : 'FAIL';
    stdout.writeln('  [$status] ${c.id}');
    for (final mm in c.mismatches) {
      stdout.writeln(
        '        ${mm.field}: chloris=${mm.actual} | legado=${mm.expected}',
      );
    }
  }
}

String? _option(List<String> args, String name) {
  final prefix = '$name=';
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
    if (arg == name && i + 1 < args.length) return args[i + 1];
  }
  return null;
}
