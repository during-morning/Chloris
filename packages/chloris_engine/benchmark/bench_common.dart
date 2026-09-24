/// 基准测试共享工具：用 Stopwatch 统计吞吐 (ops/s) 与延迟 P50/P95。
library;

import 'dart:math';

class Bench {
  Bench(this.name);

  final String name;
  final List<double> _samplesMicros = [];
  int ops = 0;
  final Stopwatch _sw = Stopwatch();

  void start() => _sw.start();
  void stop() => _sw.stop();

  /// 当前已耗微秒（在 start/stop 之间用于单次操作计时）。
  int get nowMicros => _sw.elapsedMicroseconds;

  /// 记录一次操作的耗时（微秒）。
  void record(double micros) {
    _samplesMicros.add(micros);
    ops++;
  }

  double get seconds => _sw.elapsedMicroseconds / 1e6;
  double get opsPerSec => seconds > 0 ? ops / seconds : 0;

  /// 百分位数（p ∈ [0,100]）。基于排序后的样本线性插值。
  double percentile(double p) {
    if (_samplesMicros.isEmpty) return 0;
    final sorted = List<double>.from(_samplesMicros)..sort();
    if (sorted.length == 1) return sorted.first;
    final rank = (p / 100) * (sorted.length - 1);
    final lo = rank.floor();
    final hi = rank.ceil();
    if (lo == hi) return sorted[lo];
    final frac = rank - lo;
    return sorted[lo] * (1 - frac) + sorted[hi] * frac;
  }

  void report({bool latencyInMicros = true}) {
    final scale = latencyInMicros ? 1.0 : 1000.0;
    final unit = latencyInMicros ? 'µs' : 'ms';
    print('  [$name] ops=${ops}  time=${seconds.toStringAsFixed(3)}s'
        '  throughput=${opsPerSec.toStringAsFixed(0)} ops/s'
        '  P50=${_fmt(percentile(50) * scale, unit)}'
        '  P95=${_fmt(percentile(95) * scale, unit)}');
  }
}

String _fmt(double v, String unit) =>
    '${v.toStringAsFixed(v < 10 ? 3 : 2)}$unit';

/// 生成约 [bytes] 大小的 HTML 文档（重复 book 卡片模板）。
String makeHtmlOfSize(int bytes) {
  const card = '''
  <div class="book">
    <a class="cover" href="/book/12345"><img src="https://img.example.com/12345.jpg"/></a>
    <div class="info">
      <h3 class="name">夜的命名术</h3>
      <p class="author">会说话的肘子</p>
      <p class="intro">简介：这是一本关于未来与文明的科幻小说，讲述……</p>
      <span class="kind">科幻</span>
      <span class="lastChapter">最新：第1234章</span>
    </div>
  </div>
''';
  final buffer = StringBuffer();
  buffer.write('<html><head><title>书库</title></head><body><div class="list">');
  while (buffer.length < bytes) {
    buffer.write(card);
  }
  buffer.write('</div></body></html>');
  return buffer.toString();
}

/// 生成约 [n] 本书的搜索结果 JSON。
String makeJsonOfSize(int n) {
  final books = <String>[];
  for (var i = 0; i < n; i++) {
    books.add(
      '{"name":"书名$i","author":"作者$i","bookUrl":"https://example.com/book/$i",'
      '"coverUrl":"https://img.example.com/$i.jpg","kind":"科幻","intro":"简介$i"}',
    );
  }
  return '{"data":{"list":[${books.join(',')}]},"code":0}';
}
