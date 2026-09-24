import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';

/// Run a fast, deterministic self-baseline over the checked-in rule corpus.
///
/// The library API accepts a [CallbackEquivalenceOracle] for a Legado bridge;
/// this command deliberately stays offline so CI does not depend on network
/// state.  Use `--out PATH` to choose the JSON artifact location.
Future<void> main(List<String> args) async {
  final corpusPath =
      _option(args, '--corpus') ?? 'test/golden/legado_rule_corpus.json';
  final outputPath =
      _option(args, '--out') ??
      'artifacts/verification/equivalence-audit/equivalence.json';
  final corpusFile = File(corpusPath);
  if (!corpusFile.existsSync()) {
    stderr.writeln('equivalence audit corpus not found: $corpusPath');
    exitCode = 2;
    return;
  }

  final raw = jsonDecode(await corpusFile.readAsString());
  if (raw is! List) {
    stderr.writeln('equivalence audit corpus must be a JSON array');
    exitCode = 2;
    return;
  }
  final fixtures = [
    for (final item in raw)
      if (item is Map<String, dynamic>) _fixture(item),
  ];
  final report = await EquivalenceAudit().run(fixtures);
  final output = File(outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsString(report.toJsonString(pretty: true));
  stdout.writeln(
    jsonEncode({
      'artifact': output.path,
      'oracle': report.oracle,
      'totalCases': report.metrics.totalCases,
      'passedCases': report.metrics.passedCases,
      'failedCases': report.metrics.failedCases,
      'p50Micros': report.metrics.p50Micros,
      'p95Micros': report.metrics.p95Micros,
      'cacheHitRate': report.metrics.cacheHitRate,
    }),
  );
}

EquivalenceFixture _fixture(Map<String, dynamic> item) {
  final name = item['name']?.toString() ?? 'unnamed';
  final rule = item['rule']?.toString() ?? '';
  final input = item['input'];
  final fallback = item['fallback']?.toString() ?? 'css';
  return EquivalenceFixture(
    id: 'golden/$name',
    stage: 'rule',
    input: {'name': name, 'rule': rule, 'fallback': fallback, 'input': input},
    run: () => _evaluate(rule, fallback, input),
  );
}

Map<String, Object?> _evaluate(
  String rule,
  String fallbackName,
  Object? input,
) {
  final fallback = RuleMode.values.firstWhere(
    (mode) => mode.name == fallbackName,
    orElse: () => RuleMode.css,
  );
  final compiler = const RuleCompiler();
  final program = compiler.compile(rule);
  final step = compiler.compileStep(rule, fallback: fallback);
  if (fallback == RuleMode.css) {
    return {
      'mode': step.mode.name,
      'expression': step.expression,
      'value': AnalyzeByCss(input?.toString() ?? '').getString(rule),
      'steps': program.steps.length,
    };
  }
  if (fallback == RuleMode.xpath) {
    return {
      'mode': step.mode.name,
      'expression': step.expression,
      'value': AnalyzeByXPath(
        input?.toString() ?? '',
      ).getString(step.expression),
      'steps': program.steps.length,
    };
  }
  if (fallback == RuleMode.json) {
    return {
      'mode': step.mode.name,
      'expression': step.expression,
      'value': AnalyzeByJsonPath(input ?? '').getString(step.expression),
      'steps': program.steps.length,
    };
  }
  return {
    'mode': step.mode.name,
    'expression': step.expression,
    'value': AnalyzeByRegex.getElement(input?.toString() ?? '', [
      step.expression,
    ]),
    'steps': program.steps.length,
  };
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
