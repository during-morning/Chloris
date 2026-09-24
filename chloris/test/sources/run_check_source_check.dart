// 纯 Dart 实跑：验证 BulkSourceValidator 的两级（HEAD 探活 + 关键词搜索）校验分级。
// 运行：cd chloris && dart run test/sources/run_check_source_check.dart
//
// 不依赖 flutter test（本沙箱跑不了），仅注入假 HttpPort / 假 searchProbe 验证分级逻辑。
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';

import '../../lib/features/sources/check_source.dart';
import '../../lib/features/sources/source_validator.dart';

/// 假 HttpPort：除 down.example 外都返回 200（HEAD 探活通过）；down.example 返回 503（不可达）。
class _FakeHttpPort implements HttpPort {
  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final down = spec.url.contains('down.example');
    return StrResponse(url: spec.url, body: '', code: down ? 503 : 200);
  }

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) =>
      Future.value(Uint8List(0));

  @override
  void cancelInFlight() {}
}

/// 假 searchProbe：
///  - empty.example → 返回空列表（搜索规则失效/空结果）；
///  - err.example   → 抛异常（搜索规则异常）；
///  - 其余可达且有 searchUrl 的源 → 返回 2 条结果。
Future<List<SearchBook>> _fakeProbe(BookSource source, String keyword) async {
  await Future<void>.delayed(const Duration(milliseconds: 5));
  if (source.bookSourceUrl.contains('empty.example')) return const [];
  if (source.bookSourceUrl.contains('err.example')) {
    throw StateError('搜索规则失效：$keyword');
  }
  return [
    SearchBook(bookUrl: '${source.bookSourceUrl}#1', name: '书一'),
    SearchBook(bookUrl: '${source.bookSourceUrl}#2', name: '书二'),
  ];
}

BookSource _src({
  required String url,
  required String name,
  String? searchUrl,
  String? checkKeyWord,
}) =>
    BookSource(
      bookSourceUrl: url,
      bookSourceName: name,
      searchUrl: searchUrl,
      ruleSearch: SearchRule(
        bookList: 'class.item',
        name: 'text',
        bookUrl: 'href',
        checkKeyWord: checkKeyWord,
      ),
      ruleToc: TocRule(chapterList: 'class.list'),
      ruleContent: ContentRule(content: 'id.content'),
    );

Future<void> main() async {
  final sources = <BookSource>[
    _src(
      url: 'https://ok.example/search',
      name: 'A-有结果',
      searchUrl: 'https://ok.example/search?q={{key}}',
    ),
    _src(
      url: 'https://empty.example/search',
      name: 'B-搜索空',
      searchUrl: 'https://empty.example/search?q={{key}}',
    ),
    _src(
      url: 'https://err.example/search',
      name: 'C-搜索异常',
      searchUrl: 'https://err.example/search?q={{key}}',
    ),
    _src(
      url: 'https://norule.example/nosearch',
      name: 'D-无搜索规则',
      // 不设 searchUrl
    ),
    _src(
      url: 'https://down.example/search',
      name: 'E-域名不可达',
      searchUrl: 'https://down.example/search?q={{key}}',
    ),
    _src(
      url: 'https://custom.example/search',
      name: 'F-自定义词',
      searchUrl: 'https://custom.example/search?q={{key}}',
      checkKeyWord: '我的探针',
    ),
  ];

  final report = await BulkSourceValidator(
    http: _FakeHttpPort(),
    searchProbe: _fakeProbe,
  ).validate(sources, concurrency: 3);

  // 期望分级：名称 -> (status, 是否应有结果, 期望关键词)
  final expectations = <String, (SourceValidationStatus, bool, String?)>{
    'A-有结果': (SourceValidationStatus.healthy, true, '我的'),
    'B-搜索空': (SourceValidationStatus.degraded, false, '我的'),
    'C-搜索异常': (SourceValidationStatus.degraded, false, '我的'),
    'D-无搜索规则': (SourceValidationStatus.degraded, false, '我的'),
    'E-域名不可达': (SourceValidationStatus.failed, false, '我的'),
    'F-自定义词': (SourceValidationStatus.healthy, true, '我的探针'),
  };

  print('=== 两级校验结果 ===');
  print('源'.padRight(14) +
      '状态'.padRight(10) +
      '结果数'.padRight(8) +
      '搜索耗时(ms)'.padRight(14) +
      '校验词');
  var pass = 0;
  var fail = 0;
  for (final r in report.results) {
    final exp = expectations[r.source.bookSourceName]!;
    final okStatus = r.status == exp.$1;
    final okCount = exp.$2 ? r.resultCount > 0 : r.resultCount == 0;
    final okKw = r.checkedKeyword == exp.$3;
    final ok = okStatus && okCount && okKw;
    ok ? pass++ : fail++;
    print(
      r.source.bookSourceName.padRight(14) +
          r.status.name.padRight(10) +
          r.resultCount.toString().padRight(8) +
          r.searchElapsed.inMilliseconds.toString().padRight(14) +
          (r.checkedKeyword ?? '-') +
          (ok ? '   ✓' : '   ✗ 期望=${exp.$1.name}/count=${exp.$2}/kw=${exp.$3}'),
    );
  }

  // 附加：纯探活路径（不注入 searchProbe）应退化为 HEAD-only healthy。
  final legacy = await BulkSourceValidator(http: _FakeHttpPort())
      .validate([sources.first], concurrency: 1);
  final legacyOk = legacy.results.first.status == SourceValidationStatus.healthy &&
      legacy.results.first.resultCount == 0 &&
      legacy.results.first.checkedKeyword == null;
  legacyOk ? pass++ : fail++;
  print('');
  print('纯探活退化路径(无 searchProbe): ${legacyOk ? '✓' : '✗'} '
      '(status=${legacy.results.first.status.name}, count=${legacy.results.first.resultCount}, kw=${legacy.results.first.checkedKeyword})');

  print('');
  print('分级统计：healthy=${report.healthyCount}, '
      '平均质量分=${report.averageQuality.toStringAsFixed(1)}');
  print('断言：通过 $pass / 失败 $fail');
  if (fail > 0) {
    print('RESULT: FAIL');
    exitCode = 1;
  } else {
    print('RESULT: PASS');
  }
}
