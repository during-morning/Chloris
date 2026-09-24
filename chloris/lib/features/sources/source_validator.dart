import 'dart:async';

import 'package:chloris_engine/chloris_engine.dart';

import 'check_source.dart';

class SourceValidationStatus {
  const SourceValidationStatus._(this.name);
  final String name;

  static const healthy = SourceValidationStatus._('healthy');
  static const degraded = SourceValidationStatus._('degraded');
  static const failed = SourceValidationStatus._('failed');
  static const cancelled = SourceValidationStatus._('cancelled');
}

class SourceValidationResult {
  const SourceValidationResult({
    required this.source,
    required this.status,
    required this.code,
    required this.elapsed,
    required this.qualityScore,
    this.error,
    this.resultCount = 0,
    this.searchElapsed = Duration.zero,
    this.checkedKeyword,
  });

  final BookSource source;
  final SourceValidationStatus status;
  final int code;
  final Duration elapsed;
  final int qualityScore;
  final Object? error;

  /// 搜索式校验返回的有效结果数（两级校验新增；纯探活路径下为 0）。
  final int resultCount;

  /// 搜索阶段耗时（两级校验新增；纯探活路径下为 [Duration.zero]）。
  final Duration searchElapsed;

  /// 实际使用的校验关键词（[BookSource.getCheckKeyword] 的落定值；未搜索为 null）。
  final String? checkedKeyword;
}

class SourceValidationReport {
  const SourceValidationReport(this.results);
  final List<SourceValidationResult> results;

  int get healthyCount => results.where((r) => r.status == SourceValidationStatus.healthy).length;
  double get averageQuality => results.isEmpty
      ? 0
      : results.map((r) => r.qualityScore).reduce((a, b) => a + b) / results.length;
}

class BulkSourceValidator {
  BulkSourceValidator({required this.http, this.searchProbe});

  final HttpPort http;

  /// 搜索式校验探针（对齐 legado `getCheckKeyword` + `searchBookAwait`）。
  /// 为 null 时退化为纯 HEAD 探活，保持既有行为；非空时每个源在 HEAD 探活通过后
  /// 用 [kDefaultCheckKeyword] 兜底的真实关键词搜索一次，按结果数分级。
  final SearchProbe? searchProbe;

  Future<SourceValidationReport> validate(
    Iterable<BookSource> sources, {
    int concurrency = 4,
    Duration? timeout,
    int retry = 1,
    void Function(SourceValidationResult result)? onResult,
  }) async {
    final list = sources.toList(growable: false);
    if (list.isEmpty) return const SourceValidationReport([]);
    final limit = concurrency < 1 ? 1 : concurrency;
    final results = <SourceValidationResult>[];
    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        final index = cursor++;
        if (index >= list.length) return;
        final result = await _validateOne(list[index], timeout: timeout, retry: retry);
        results.add(result);
        onResult?.call(result);
      }
    }
    await Future.wait(List.generate(limit, (_) => worker()));
    return SourceValidationReport(List.unmodifiable(results));
  }

  void cancel() => http.cancelInFlight();

  Future<SourceValidationResult> _validateOne(
    BookSource source, {
    Duration? timeout,
    required int retry,
  }) async {
    final started = DateTime.now();

    // —— 第一级：HEAD 快探（沿用既有逻辑，仅判定域名/接口是否可达）——
    late final int headCode;
    late final Duration headElapsed;
    late final Object? headError;
    late final SourceValidationStatus headStatus;
    try {
      final response = await http.send(HttpRequestSpec(
        url: source.bookSourceUrl,
        method: 'HEAD',
        timeout: timeout,
        retry: retry,
      ));
      headElapsed = DateTime.now().difference(started);
      headCode = response.code;
      headError = response.error;
      headStatus = response.isSuccessful
          ? (response.code < 300
              ? SourceValidationStatus.healthy
              : SourceValidationStatus.degraded)
          : SourceValidationStatus.failed;
    } on HttpCancelledException catch (e) {
      return SourceValidationResult(
        source: source,
        status: SourceValidationStatus.cancelled,
        code: 0,
        elapsed: DateTime.now().difference(started),
        qualityScore: 0,
        error: e,
      );
    } catch (e) {
      return SourceValidationResult(
        source: source,
        status: SourceValidationStatus.failed,
        code: 0,
        elapsed: DateTime.now().difference(started),
        qualityScore: 0,
        error: e,
      );
    }

    // 未注入搜索探针：保持纯探活语义，不引入搜索结果字段。
    if (searchProbe == null) {
      return SourceValidationResult(
        source: source,
        status: headStatus,
        code: headCode,
        elapsed: headElapsed,
        qualityScore: _score(source, headCode, headElapsed),
        error: headError,
      );
    }

    // 探活失败：域名/接口不可达，不再搜索（对齐 legado 「网站失效」）。
    if (headStatus == SourceValidationStatus.failed) {
      return SourceValidationResult(
        source: source,
        status: SourceValidationStatus.failed,
        code: headCode,
        elapsed: headElapsed,
        qualityScore: 0,
        error: headError,
        checkedKeyword: source.getCheckKeyword(kDefaultCheckKeyword),
      );
    }

    // —— 第二级：用真实关键词搜索一次（对齐 legado `searchBookAwait`）——
    final keyword = source.getCheckKeyword(kDefaultCheckKeyword);
    final searched = (source.searchUrl ?? '').trim().isNotEmpty;
    var resultCount = 0;
    var searchError = headError;
    var searchElapsed = Duration.zero;
    if (searched) {
      final s = DateTime.now();
      try {
        final books = timeout == null
            ? await searchProbe!(source, keyword)
            : await searchProbe!(source, keyword).timeout(timeout);
        resultCount = books.length;
        searchError = null;
      } on HttpCancelledException catch (e) {
        return SourceValidationResult(
          source: source,
          status: SourceValidationStatus.cancelled,
          code: headCode,
          elapsed: DateTime.now().difference(started),
          qualityScore: 0,
          error: e,
          checkedKeyword: keyword,
        );
      } catch (e) {
        // 搜索异常：域名可达但搜索规则失效，对齐 legado 「搜索失效」→ degraded。
        searchError = e;
      }
      searchElapsed = DateTime.now().difference(s);
    }

    final level = classifySearchResult(
      reachable: headStatus != SourceValidationStatus.failed,
      searched: searched,
      resultCount: resultCount,
    );
    final status = switch (level) {
      SearchCheckLevel.healthy => SourceValidationStatus.healthy,
      SearchCheckLevel.degraded => SourceValidationStatus.degraded,
      SearchCheckLevel.failed => SourceValidationStatus.failed,
    };
    return SourceValidationResult(
      source: source,
      status: status,
      code: headCode,
      elapsed: DateTime.now().difference(started),
      qualityScore: _score(
        source,
        headCode,
        headElapsed,
        searched: searched,
        resultCount: resultCount,
      ),
      error: searchError,
      resultCount: resultCount,
      searchElapsed: searchElapsed,
      checkedKeyword: keyword,
    );
  }

  int _score(
    BookSource source,
    int code,
    Duration elapsed, {
    bool searched = false,
    int resultCount = 0,
  }) {
    if (code < 200 || code >= 400) return 0;
    var score = 60;
    if (source.hasCompleteRules) score += 25;
    if (source.enabled) score += 5;
    if (elapsed <= const Duration(seconds: 1)) score += 10;
    // 搜索式校验通过（真实返回书籍）额外加分，反映规则确实有效。
    if (searched && resultCount > 0) score += 5;
    return score.clamp(0, 100);
  }
}
