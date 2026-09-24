/// 基准：规则解析吞吐。对语料库中的真实规则反复做 编译(parse) + 执行(eval)。
///
/// 运行：dart run benchmark/bench_rule_parse.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import 'bench_common.dart';

void main() {
  final corpusPath = p.join(
    File(Platform.script.toFilePath()).parent.parent.path,
    'test',
    'golden',
    'legado_rule_corpus.json',
  );
  final doc = jsonDecode(File(corpusPath).readAsStringSync())
      as Map<String, dynamic>;
  final entries = (doc['entries'] as List).cast<Map<String, dynamic>>();

  // 共享夹具：一个真实结构的 HTML 列表页 + 一份搜索结果 JSON。
  final html = html_parser.parse('''
    <html><body><div class="list">
      <div class="book"><a class="cover" href="/book/1"><h3 class="name">书名一</h3>
        <p class="author">作者甲</p><p class="intro">简介内容</p><span class="kind">玄幻</span></div>
      <div class="book"><a class="cover" href="/book/2"><h3 class="name">书名二</h3>
        <p class="author">作者乙</p><p class="intro">简介内容二</p><span class="kind">科幻</span></div>
    </div></body></html>''');
  final jsonRoot = jsonDecode(
    '{"data":{"list":[{"name":"A","author":"x","bookUrl":"/b/1"},'
    '{"name":"B","author":"y","bookUrl":"/b/2"}]}}',
  );

  final compiler = const RuleCompiler();
  final css = AnalyzeByCss(html);
  final xpath = AnalyzeByXPath(html);
  final jsonp = AnalyzeByJsonPath(jsonRoot);

  // 预构建每个条目的执行闭包（按后端选择夹具，js 仅编译不执行）。
  final jobs = <(String rule, String backend, bool allInOne, void Function() eval)>[];
  for (final e in entries) {
    final rule = e['rule'] as String;
    final backend = e['backend'] as String;
    final allInOne = e['allInOne'] as bool? ?? false;
    void Function()? eval;
    switch (backend) {
      case 'css':
        eval = () => css.getString(rule);
      case 'xpath':
        eval = () => xpath.getString(rule);
      case 'json':
        eval = () => jsonp.getString(rule);
      default:
        eval = () {}; // js / regex：不执行
    }
    jobs.add((rule, backend, allInOne, eval));
  }

  print('bench_rule_parse: ${jobs.length} 条真实规则, 反复 compile+eval');
  final bench = Bench('rule_parse');
  bench.start();
  const minSeconds = 3;
  while (bench.seconds < minSeconds) {
    for (final (rule, backend, allInOne, eval) in jobs) {
      final t0 = bench.nowMicros;
      compiler.compile(
        rule,
        isJson: backend == 'json',
        isRegex: backend == 'regex',
        allInOne: allInOne,
      );
      try {
        eval();
      } catch (_) {
        // 个别规则在通用夹具上无匹配/抛错属正常，不计入失败。
      }
      final t1 = bench.nowMicros;
      bench.record((t1 - t0).toDouble());
    }
  }
  bench.stop();
  bench.report();
}
