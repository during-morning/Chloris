import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test(
    'self baseline emits machine-readable metrics and cache deltas',
    () async {
      final cache = EquivalenceCacheStats();
      final report = await EquivalenceAudit().run([
        EquivalenceFixture(
          id: 'rule/css',
          stage: 'rule',
          input: {'rule': 'div@text'},
          cacheStats: cache,
          run: () {
            cache.recordMiss();
            return {
              'value': '目标',
              'fields': ['name', 'author'],
            };
          },
        ),
        EquivalenceFixture(
          id: 'search/empty',
          stage: 'search',
          cacheStats: cache,
          run: () {
            cache.recordHit();
            return {'items': <Object?>[]};
          },
        ),
      ]);

      expect(report.selfBaseline, isTrue);
      expect(report.oracle, 'chloris-self-baseline');
      expect(report.metrics.totalCases, 2);
      expect(report.metrics.passedCases, 2);
      expect(report.metrics.passRate, 1);
      expect(report.metrics.cacheHits, 1);
      expect(report.metrics.cacheMisses, 1);
      expect(report.metrics.cacheHitRate, 0.5);
      expect(
        report.metrics.stages.keys,
        containsAll(<String>['rule', 'search']),
      );
      expect(report.metrics.p50Micros, greaterThanOrEqualTo(0));
      expect(report.metrics.p95Micros, greaterThanOrEqualTo(0));

      final decoded = jsonDecode(report.toJsonString()) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], 1);
      expect(decoded['metrics']['mismatchesByStage'], isEmpty);
      expect(decoded['cases'], hasLength(2));
    },
  );

  test('oracle comparison reports stage and field mismatches', () async {
    final report =
        await EquivalenceAudit(
          oracle: CallbackEquivalenceOracle((fixture) async {
            expect(fixture.input['query'], '规则');
            return {'name': '参考名', 'author': '作者'};
          }),
        ).run([
          EquivalenceFixture(
            id: 'search/one',
            stage: 'search',
            input: {'query': '规则'},
            run: () async => {'name': 'Chloris名', 'extra': true},
          ),
        ]);

    expect(report.selfBaseline, isFalse);
    expect(report.metrics.passedCases, 0);
    expect(report.metrics.failedCases, 1);
    expect(report.metrics.mismatchCount, 3);
    expect(report.metrics.mismatchesByStage, {'search': 3});
    expect(report.metrics.mismatchesByField, {
      'author': 1,
      'extra': 1,
      'name': 1,
    });
    expect(report.cases.single.mismatches, hasLength(3));
    expect(report.cases.single.mismatches.first.caseId, 'search/one');
    expect(report.cases.single.mismatches.first.stage, 'search');
  });

  test('runner errors are comparable and continue the audit', () async {
    final report =
        await EquivalenceAudit(
          oracle: CallbackEquivalenceOracle(
            (_) => throw StateError('legado fail'),
          ),
        ).run([
          EquivalenceFixture(
            id: 'content/error',
            stage: 'content',
            run: () => throw StateError('chloris fail'),
          ),
          EquivalenceFixture(
            id: 'content/ok',
            stage: 'content',
            run: () => {'text': 'ok'},
          ),
        ]);

    expect(report.metrics.totalCases, 2);
    expect(report.metrics.failedCases, 2);
    expect(report.cases.first.mismatches, hasLength(1));
    expect(report.cases.first.mismatches.single.field, r'$audit.error');
    expect(report.cases.last.mismatches, hasLength(1));
    expect(report.cases.last.mismatches.single.field, r'$audit.status');
  });
}
