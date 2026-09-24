import 'package:flutter_test/flutter_test.dart';

import 'package:chloris/core/search/search_early_stop.dart';

void main() {
  group('searchShouldEarlyStop', () {
    test('命中数未达阈值不早停', () {
      expect(
        searchShouldEarlyStop(mergedHits: 0, earlyStopHits: 8),
        isFalse,
      );
      expect(
        searchShouldEarlyStop(mergedHits: 7, earlyStopHits: 8),
        isFalse,
      );
    });

    test('命中数达到阈值即早停', () {
      expect(
        searchShouldEarlyStop(mergedHits: 8, earlyStopHits: 8),
        isTrue,
      );
      expect(
        searchShouldEarlyStop(mergedHits: 9, earlyStopHits: 8),
        isTrue,
      );
    });

    test('阈值 <= 0 关闭早停（兼容关掉该设置的场景）', () {
      expect(
        searchShouldEarlyStop(mergedHits: 100, earlyStopHits: 0),
        isFalse,
      );
      expect(
        searchShouldEarlyStop(mergedHits: 100, earlyStopHits: -1),
        isFalse,
      );
    });
  });
}
