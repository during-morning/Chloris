import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  setUp(RateLimiter.resetShared);
  test('interval spec delays second acquire', () async {
    final a = RateLimiter.shared('t', '50');
    final sw = Stopwatch()..start();
    await a.acquire();
    await a.acquire();
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(40));
  });

  test('empty spec does not serialize', () async {
    final a = RateLimiter.shared('fast', null);
    final sw = Stopwatch()..start();
    await Future.wait(List.generate(20, (_) => a.acquire()));
    expect(sw.elapsedMilliseconds, lessThan(50));
  });
}
