/// 基准：真实规则在真实结构 HTML/JSON 上的整链 eval。
/// 既用语料库里的真实规则，也用一组能命中夹具的精选规则，体现真实抽取链路。
///
/// 运行：dart run benchmark/bench_rule_eval.dart
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

  // 真实结构的 HTML 书列表页（含多本书卡片）。
  final html = html_parser.parse('''
    <html><body><div class="bookList">
      <li class="book"><a class="cover" href="/book/101"><img src="c1.jpg"/></a>
        <div class="info"><h3 class="bookname">夜的命名术</h3>
        <p class="author">会说话的肘子</p><p class="intro">未来科幻小说</p>
        <span class="kind">科幻</span><span class="last">第1234章</span></div></li>
      <li class="book"><a class="cover" href="/book/102"><img src="c2.jpg"/></a>
        <div class="info"><h3 class="bookname">诡秘之主</h3>
        <p class="author">爱潜水的乌贼</p><p class="intro">克苏鲁风</p>
        <span class="kind">奇幻</span><span class="last">第999章</span></div></li>
      <li class="book"><a class="cover" href="/book/103"><img src="c3.jpg"/></a>
        <div class="info"><h3 class="bookname">凡人修仙传</h3>
        <p class="author">忘语</p><p class="intro">修仙长篇</p>
        <span class="kind">仙侠</span><span class="last">第3000章</span></div></li>
    </div></body></html>''');

  final jsonRoot = jsonDecode(
    '{"data":{"list":['
    '{"name":"夜的命名术","author":"会说话的肘子","bookUrl":"/b/101","kind":"科幻"},'
    '{"name":"诡秘之主","author":"爱潜水的乌贼","bookUrl":"/b/102","kind":"奇幻"},'
    '{"name":"凡人修仙传","author":"忘语","bookUrl":"/b/103","kind":"仙侠"}]}}',
  );

  final css = AnalyzeByCss(html);
  final xpath = AnalyzeByXPath(html);
  final jsonp = AnalyzeByJsonPath(jsonRoot);

  // 从语料中采样真实规则（排除内嵌 JS，避免触发 JS 运行时）。
  final sampled = <(String rule, String backend)>[];
  final want = {'css': 12, 'xpath': 8, 'json': 8};
  final counters = <String, int>{};
  for (final e in entries) {
    final backend = e['backend'] as String;
    if (!want.containsKey(backend)) continue;
    final rule = e['rule'] as String;
    if (rule.contains('<js>') || rule.contains('@webjs:')) continue;
    if ((counters[backend] ?? 0) >= want[backend]!) continue;
    counters[backend] = (counters[backend] ?? 0) + 1;
    sampled.add((rule, backend));
  }

  // 精选的、能命中夹具的真实风格规则，保证体现真实抽取链路。
  const curated = <(String, String)>[
    ('.book', 'css'),
    ('.bookname', 'css'),
    ('.author', 'css'),
    ('.cover@href', 'css'),
    ('class.book&&class.bookname', 'css'),
    ('//li[@class="book"]/div/h3', 'xpath'),
    ('//h3[@class="bookname"]/text()', 'xpath'),
    ('//div[@class="info"]/p[@class="author"]', 'xpath'),
    (r'$.data.list[*].name', 'json'),
    (r'$.data.list[0].author', 'json'),
  ];

  final jobs = <(String rule, void Function() eval)>[];
  void add(String rule, String backend) {
    switch (backend) {
      case 'css':
        jobs.add((rule, () => css.getStringList(rule)));
      case 'xpath':
        jobs.add((rule, () => xpath.getStringList(rule)));
      case 'json':
        jobs.add((rule, () => jsonp.getStringList(rule)));
    }
  }

  for (final (rule, backend) in sampled) add(rule, backend);
  for (final (rule, backend) in curated) add(rule, backend);

  print('bench_rule_eval: ${jobs.length} 条真实/精选规则在真实结构上的整链 eval');
  final bench = Bench('rule_eval');
  bench.start();
  const minSeconds = 3;
  while (bench.seconds < minSeconds) {
    for (final (rule, eval) in jobs) {
      final t0 = bench.nowMicros;
      try {
        eval();
      } catch (_) {
        // 抽取失败不计入错误，仅衡量吞吐。
      }
      final t1 = bench.nowMicros;
      bench.record((t1 - t0).toDouble());
    }
  }
  bench.stop();
  bench.report();
}
