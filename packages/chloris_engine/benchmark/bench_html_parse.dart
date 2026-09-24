/// 基准：package:html 解析不同大小 HTML 页面的耗时。
///
/// 运行：dart run benchmark/bench_html_parse.dart
library;

import 'package:html/parser.dart' as html_parser;

import 'bench_common.dart';

void main() {
  print('bench_html_parse: 不同大小 HTML 的 package:html 解析吞吐');
  final sizes = <int, String>{
    1024: '1KB',
    10 * 1024: '10KB',
    100 * 1024: '100KB',
    1024 * 1024: '1MB',
  };
  for (final entry in sizes.entries) {
    final html = makeHtmlOfSize(entry.key);
    final bench = Bench('html_${entry.value}');
    bench.start();
    const minSeconds = 1.5;
    while (bench.seconds < minSeconds) {
      final t0 = bench.nowMicros;
      html_parser.parse(html);
      final t1 = bench.nowMicros;
      bench.record((t1 - t0).toDouble());
    }
    bench.stop();
    bench.report();
  }
}
