import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris/features/sources/source_validator.dart';

class FakeHttp implements HttpPort {
  FakeHttp(this.responses);
  final Map<String, StrResponse> responses;
  final calls = <String>[];
  bool cancelled = false;

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    calls.add(spec.url);
    if (cancelled) throw const HttpCancelledException();
    final response = responses[spec.url];
    if (response == null) throw StateError('missing response');
    return response;
  }

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async => Uint8List(0);

  @override
  void cancelInFlight() { cancelled = true; }
}

void main() {
  test('批量校验分级、重试参数和质量评分', () async {
    final http = FakeHttp({
      'https://ok.test': const StrResponse(url: 'https://ok.test', body: '', code: 200),
      'https://redirect.test': const StrResponse(url: 'https://redirect.test', body: '', code: 302),
      'https://bad.test': const StrResponse(url: 'https://bad.test', body: '', code: 503),
    });
    final report = await BulkSourceValidator(http: http).validate([
      BookSource(bookSourceUrl: 'https://ok.test', bookSourceName: 'ok'),
      BookSource(bookSourceUrl: 'https://redirect.test', bookSourceName: 'redirect'),
      BookSource(bookSourceUrl: 'https://bad.test', bookSourceName: 'bad'),
    ], concurrency: 2, retry: 2);
    expect(report.results, hasLength(3));
    expect(report.healthyCount, 1);
    expect(report.results.firstWhere((r) => r.code == 200).qualityScore, 75);
    expect(report.results.firstWhere((r) => r.code == 302).status, SourceValidationStatus.degraded);
    expect(report.results.firstWhere((r) => r.code == 503).qualityScore, 0);
  });

  test('取消会产生可识别的取消结果', () async {
    final http = FakeHttp({
      'https://cancel.test': const StrResponse(url: 'https://cancel.test', body: '', code: 200),
    })..cancelled = true;
    final report = await BulkSourceValidator(http: http).validate([
      BookSource(bookSourceUrl: 'https://cancel.test'),
    ]);
    expect(report.results.single.status, SourceValidationStatus.cancelled);
  });
}
