import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('EngineLimits.apply clamps and sets UA', () {
    final oldHttp = EngineLimits.httpTimeout;
    final oldPool = EngineLimits.searchPool;
    final oldUa = EngineLimits.userAgent;
    EngineLimits.apply(httpTimeoutSec: 3, searchPool: 1, userAgent: '  FooBar/1.0  ');
    expect(EngineLimits.httpTimeout.inSeconds, 6);
    expect(EngineLimits.searchPool, 4);
    expect(EngineLimits.userAgent, 'FooBar/1.0');
    EngineLimits.apply(userAgent: '');
    expect(EngineLimits.userAgent, isNull);
    EngineLimits.apply(
      httpTimeoutSec: oldHttp.inSeconds,
      searchPool: oldPool,
      userAgent: oldUa ?? '',
    );
  });

  test('search dispatch clamps allow unlimited hosts and no early stop', () {
    final oldPool = EngineLimits.searchPool;
    final oldHost = EngineLimits.searchHostCap;
    final oldHits = EngineLimits.searchEarlyStopHits;
    EngineLimits.apply(searchPool: 99, searchHostCap: -1, searchEarlyStopHits: -3);
    expect(EngineLimits.searchPool, 64);
    expect(EngineLimits.searchHostCap, 0);
    expect(EngineLimits.searchEarlyStopHits, 0);
    EngineLimits.apply(
      searchPool: oldPool,
      searchHostCap: oldHost,
      searchEarlyStopHits: oldHits,
    );
  });

  test('content and toc timeouts stay independent of HTTP timeout', () {
    final oldHttp = EngineLimits.httpTimeout;
    final oldToc = EngineLimits.tocTimeout;
    final oldContent = EngineLimits.contentTimeout;
    EngineLimits.apply(httpTimeoutSec: 8, tocTimeoutSec: 20, contentTimeoutSec: 30);
    expect(EngineLimits.httpTimeout.inSeconds, 8);
    expect(EngineLimits.tocTimeout.inSeconds, 20);
    expect(EngineLimits.contentTimeout.inSeconds, 30);
    EngineLimits.apply(
      httpTimeoutSec: oldHttp.inSeconds,
      tocTimeoutSec: oldToc.inSeconds,
      contentTimeoutSec: oldContent.inSeconds,
    );
  });

  test('search timeout is independent of HTTP timeout', () {
    final oldHttp = EngineLimits.httpTimeout;
    final oldSearch = EngineLimits.searchTimeout;
    EngineLimits.apply(httpTimeoutSec: 8, searchTimeoutSec: 30);
    expect(EngineLimits.httpTimeout.inSeconds, 8);
    expect(EngineLimits.searchTimeout.inSeconds, 30);
    EngineLimits.apply(
      httpTimeoutSec: oldHttp.inSeconds,
      searchTimeoutSec: oldSearch.inSeconds,
    );
  });
}
