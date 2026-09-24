import 'dart:async';
import 'dart:convert';

/// A deterministic, machine-readable comparison case.
///
/// [run] is intentionally supplied by the caller.  This keeps the audit
/// layer independent from the HTTP port and makes it possible to plug a
/// Legado runner in later without adding a second engine implementation here.
class EquivalenceFixture {
  EquivalenceFixture({
    required this.id,
    required this.stage,
    required this.run,
    this.input = const <String, Object?>{},
    EquivalenceCacheStats? cacheStats,
  }) : cacheStats = cacheStats ?? EquivalenceCacheStats();

  final String id;
  final String stage;
  final Map<String, Object?> input;
  final FutureOr<Map<String, Object?>> Function() run;

  /// Optional counters owned by the caller's runner.  The audit records the
  /// delta around the Chloris invocation and never assumes a particular cache
  /// implementation.
  final EquivalenceCacheStats cacheStats;
}

/// A small explicit cache counter that runners can use to expose cache
/// behaviour without coupling the audit report to engine internals.
class EquivalenceCacheStats {
  int hits = 0;
  int misses = 0;

  int get lookups => hits + misses;

  double get hitRate => lookups == 0 ? 0 : hits / lookups;

  void recordHit([int count = 1]) {
    if (count > 0) hits += count;
  }

  void recordMiss([int count = 1]) {
    if (count > 0) misses += count;
  }

  EquivalenceCacheSnapshot snapshot() =>
      EquivalenceCacheSnapshot(hits: hits, misses: misses);

  Map<String, Object?> toJson() => {
    'hits': hits,
    'misses': misses,
    'lookups': lookups,
    'hitRate': hitRate,
  };
}

class EquivalenceCacheSnapshot {
  const EquivalenceCacheSnapshot({required this.hits, required this.misses});

  final int hits;
  final int misses;

  EquivalenceCacheDelta operator -(EquivalenceCacheSnapshot other) =>
      EquivalenceCacheDelta(
        hits: hits - other.hits,
        misses: misses - other.misses,
      );
}

class EquivalenceCacheDelta {
  const EquivalenceCacheDelta({this.hits = 0, this.misses = 0});

  final int hits;
  final int misses;

  int get lookups => hits + misses;

  double get hitRate => lookups == 0 ? 0 : hits / lookups;

  Map<String, Object?> toJson() => {
    'hits': hits,
    'misses': misses,
    'lookups': lookups,
    'hitRate': hitRate,
  };
}

/// Oracle contract for a reference implementation, normally a Legado bridge.
///
/// The reference may be local, a process bridge, or a remote service.  It
/// receives the same fixture input and returns the same field map as Chloris.
abstract interface class EquivalenceOracle {
  String get name;

  FutureOr<Map<String, Object?>> evaluate(EquivalenceFixture fixture);
}

/// Adapter for a callback-backed oracle.  It is useful in tests and for a
/// future Legado subprocess/HTTP bridge.
class CallbackEquivalenceOracle implements EquivalenceOracle {
  CallbackEquivalenceOracle(this.callback, {this.name = 'legado-oracle'});

  @override
  final String name;
  final FutureOr<Map<String, Object?>> Function(EquivalenceFixture fixture)
  callback;

  @override
  FutureOr<Map<String, Object?>> evaluate(EquivalenceFixture fixture) =>
      callback(fixture);
}

/// Explicit oracle used when no Legado process is available yet.
class SelfBaselineOracle implements EquivalenceOracle {
  const SelfBaselineOracle();

  @override
  String get name => 'chloris-self-baseline';

  @override
  FutureOr<Map<String, Object?>> evaluate(EquivalenceFixture fixture) =>
      fixture.run();
}

class EquivalenceAudit {
  EquivalenceAudit({EquivalenceOracle? oracle})
    : oracle = oracle ?? const SelfBaselineOracle();

  final EquivalenceOracle oracle;

  /// Runs cases serially to preserve fixture order and avoid making the
  /// latency sample depend on scheduler interleaving.
  Future<EquivalenceReport> run(Iterable<EquivalenceFixture> fixtures) async {
    final startedAt = DateTime.now().toUtc();
    final watch = Stopwatch()..start();
    final results = <EquivalenceCaseResult>[];
    for (final fixture in fixtures) {
      results.add(await _runCase(fixture));
    }
    watch.stop();
    final finishedAt = DateTime.now().toUtc();
    return EquivalenceReport(
      startedAt: startedAt,
      finishedAt: finishedAt,
      durationMicros: watch.elapsedMicroseconds,
      oracle: oracle.name,
      selfBaseline: oracle is SelfBaselineOracle,
      cases: results,
    );
  }

  Future<EquivalenceCaseResult> _runCase(EquivalenceFixture fixture) async {
    final before = fixture.cacheStats.snapshot();
    final actualWatch = Stopwatch()..start();
    final actualEvaluation = await _capture(fixture.run);
    actualWatch.stop();
    final after = fixture.cacheStats.snapshot();
    final cache = after - before;

    // A self-baseline is deliberately one invocation.  Calling the same
    // runner twice would make the baseline slower and could double-count
    // cache activity.
    var oracleElapsedMicros = 0;
    late final _Evaluation expectedEvaluation;
    if (oracle is SelfBaselineOracle) {
      expectedEvaluation = actualEvaluation;
    } else {
      final oracleWatch = Stopwatch()..start();
      expectedEvaluation = await _capture(() => oracle.evaluate(fixture));
      oracleWatch.stop();
      oracleElapsedMicros = oracleWatch.elapsedMicroseconds;
    }

    final actual = actualEvaluation.value ?? const <String, Object?>{};
    final expected = expectedEvaluation.value ?? const <String, Object?>{};
    final mismatches = <EquivalenceFieldMismatch>[];
    final actualError = actualEvaluation.error;
    final expectedError = expectedEvaluation.error;
    if (actualError != null || expectedError != null) {
      // Do not report every payload field as missing when one implementation
      // failed.  A state mismatch is one actionable difference; if both
      // failed, compare one normalized error field (without volatile stacks).
      if ((actualError == null) != (expectedError == null)) {
        mismatches.add(
          EquivalenceFieldMismatch(
            caseId: fixture.id,
            stage: fixture.stage,
            field: r'$audit.status',
            kind: EquivalenceMismatchKind.value,
            actual: actualError == null ? 'ok' : 'error',
            expected: expectedError == null ? 'ok' : 'error',
          ),
        );
      } else if (!_deepEquals(
        _errorComparable(actualError!),
        _errorComparable(expectedError!),
      )) {
        mismatches.add(
          EquivalenceFieldMismatch(
            caseId: fixture.id,
            stage: fixture.stage,
            field: r'$audit.error',
            kind: EquivalenceMismatchKind.value,
            actual: _errorComparable(actualError),
            expected: _errorComparable(expectedError),
          ),
        );
      }
    } else {
      final fields = <String>{...actual.keys, ...expected.keys}.toList()
        ..sort();
      for (final field in fields) {
        final hasActual = actual.containsKey(field);
        final hasExpected = expected.containsKey(field);
        final kind = !hasActual
            ? EquivalenceMismatchKind.missingActual
            : !hasExpected
            ? EquivalenceMismatchKind.missingExpected
            : EquivalenceMismatchKind.value;
        if (!hasActual ||
            !hasExpected ||
            !_deepEquals(actual[field], expected[field])) {
          mismatches.add(
            EquivalenceFieldMismatch(
              caseId: fixture.id,
              stage: fixture.stage,
              field: field,
              kind: kind,
              actual: actual[field],
              expected: expected[field],
            ),
          );
        }
      }
    }
    return EquivalenceCaseResult(
      id: fixture.id,
      stage: fixture.stage,
      passed: mismatches.isEmpty,
      elapsedMicros: actualWatch.elapsedMicroseconds,
      oracleElapsedMicros: oracleElapsedMicros,
      input: fixture.input,
      actual: actual,
      expected: expected,
      actualError: actualEvaluation.error,
      expectedError: expectedEvaluation.error,
      cache: cache,
      mismatches: mismatches,
    );
  }

  Future<_Evaluation> _capture(
    FutureOr<Map<String, Object?>> Function() callback,
  ) async {
    try {
      return _Evaluation(value: await callback());
    } catch (error, stackTrace) {
      return _Evaluation(
        error: EquivalenceError(
          type: error.runtimeType.toString(),
          message: error.toString(),
          stack: stackTrace.toString(),
        ),
      );
    }
  }
}

enum EquivalenceMismatchKind { value, missingActual, missingExpected }

class EquivalenceError {
  const EquivalenceError({
    required this.type,
    required this.message,
    required this.stack,
  });

  final String type;
  final String message;
  final String stack;

  Map<String, Object?> toJson() => {
    'type': type,
    'message': message,
    'stack': stack,
  };
}

class EquivalenceFieldMismatch {
  const EquivalenceFieldMismatch({
    required this.caseId,
    required this.stage,
    required this.field,
    required this.kind,
    this.actual,
    this.expected,
  });

  final String caseId;
  final String stage;
  final String field;
  final EquivalenceMismatchKind kind;
  final Object? actual;
  final Object? expected;

  Map<String, Object?> toJson() => {
    'caseId': caseId,
    'stage': stage,
    'field': field,
    'kind': kind.name,
    'actual': _jsonSafe(actual),
    'expected': _jsonSafe(expected),
  };
}

class EquivalenceCaseResult {
  const EquivalenceCaseResult({
    required this.id,
    required this.stage,
    required this.passed,
    required this.elapsedMicros,
    this.oracleElapsedMicros = 0,
    required this.input,
    required this.actual,
    required this.expected,
    required this.actualError,
    required this.expectedError,
    required this.cache,
    required this.mismatches,
  });

  final String id;
  final String stage;
  final bool passed;
  final int elapsedMicros;
  final int oracleElapsedMicros;
  final Map<String, Object?> input;
  final Map<String, Object?> actual;
  final Map<String, Object?> expected;
  final EquivalenceError? actualError;
  final EquivalenceError? expectedError;
  final EquivalenceCacheDelta cache;
  final List<EquivalenceFieldMismatch> mismatches;

  Map<String, Object?> toJson() => {
    'id': id,
    'stage': stage,
    'passed': passed,
    'elapsedMicros': elapsedMicros,
    'oracleElapsedMicros': oracleElapsedMicros,
    'input': _jsonSafe(input),
    'actual': _jsonSafe(actual),
    'expected': _jsonSafe(expected),
    if (actualError != null) 'actualError': actualError!.toJson(),
    if (expectedError != null) 'expectedError': expectedError!.toJson(),
    'cache': cache.toJson(),
    'mismatches': [for (final mismatch in mismatches) mismatch.toJson()],
  };
}

class EquivalenceStageMetrics {
  EquivalenceStageMetrics({
    required this.stage,
    required List<EquivalenceCaseResult> cases,
  }) : _cases = List.unmodifiable(cases);

  final String stage;
  final List<EquivalenceCaseResult> _cases;

  int get totalCases => _cases.length;
  int get passedCases => _cases.where((result) => result.passed).length;
  int get failedCases => totalCases - passedCases;
  int get fieldsCompared =>
      _cases.fold(0, (sum, result) => sum + _fieldCount(result));
  int get mismatchCount =>
      _cases.fold(0, (sum, result) => sum + result.mismatches.length);
  int get cacheHits => _cases.fold(0, (sum, result) => sum + result.cache.hits);
  int get cacheMisses =>
      _cases.fold(0, (sum, result) => sum + result.cache.misses);
  double get passRate => totalCases == 0 ? 1 : passedCases / totalCases;
  double get cacheHitRate {
    final total = cacheHits + cacheMisses;
    return total == 0 ? 0 : cacheHits / total;
  }

  int get p50Micros =>
      _percentile([for (final result in _cases) result.elapsedMicros], 0.50);
  int get p95Micros =>
      _percentile([for (final result in _cases) result.elapsedMicros], 0.95);

  Map<String, Object?> toJson() => {
    'stage': stage,
    'totalCases': totalCases,
    'passedCases': passedCases,
    'failedCases': failedCases,
    'passRate': passRate,
    'fieldsCompared': fieldsCompared,
    'mismatchCount': mismatchCount,
    'p50Micros': p50Micros,
    'p95Micros': p95Micros,
    'cacheHits': cacheHits,
    'cacheMisses': cacheMisses,
    'cacheHitRate': cacheHitRate,
  };
}

class EquivalenceMetrics {
  EquivalenceMetrics(List<EquivalenceCaseResult> cases)
    : _cases = List.unmodifiable(cases),
      stages = _groupStages(cases);

  final List<EquivalenceCaseResult> _cases;
  final Map<String, EquivalenceStageMetrics> stages;

  int get totalCases => _cases.length;
  int get passedCases => _cases.where((result) => result.passed).length;
  int get failedCases => totalCases - passedCases;
  int get fieldsCompared =>
      _cases.fold(0, (sum, result) => sum + _fieldCount(result));
  int get mismatchCount =>
      _cases.fold(0, (sum, result) => sum + result.mismatches.length);
  double get passRate => totalCases == 0 ? 1 : passedCases / totalCases;
  double get mismatchRate =>
      fieldsCompared == 0 ? 0 : mismatchCount / fieldsCompared;
  int get cacheHits => _cases.fold(0, (sum, result) => sum + result.cache.hits);
  int get cacheMisses =>
      _cases.fold(0, (sum, result) => sum + result.cache.misses);
  double get cacheHitRate {
    final total = cacheHits + cacheMisses;
    return total == 0 ? 0 : cacheHits / total;
  }

  int get p50Micros =>
      _percentile([for (final result in _cases) result.elapsedMicros], 0.50);
  int get p95Micros =>
      _percentile([for (final result in _cases) result.elapsedMicros], 0.95);

  Map<String, int> get mismatchesByStage {
    final out = <String, int>{};
    for (final result in _cases) {
      if (result.mismatches.isNotEmpty) {
        out[result.stage] = (out[result.stage] ?? 0) + result.mismatches.length;
      }
    }
    return out;
  }

  Map<String, int> get mismatchesByField {
    final out = <String, int>{};
    for (final result in _cases) {
      for (final mismatch in result.mismatches) {
        out[mismatch.field] = (out[mismatch.field] ?? 0) + 1;
      }
    }
    return out;
  }

  Map<String, Object?> toJson() => {
    'totalCases': totalCases,
    'passedCases': passedCases,
    'failedCases': failedCases,
    'passRate': passRate,
    'fieldsCompared': fieldsCompared,
    'mismatchCount': mismatchCount,
    'mismatchRate': mismatchRate,
    'p50Micros': p50Micros,
    'p95Micros': p95Micros,
    'cacheHits': cacheHits,
    'cacheMisses': cacheMisses,
    'cacheHitRate': cacheHitRate,
    'mismatchesByStage': mismatchesByStage,
    'mismatchesByField': mismatchesByField,
    'stages': {
      for (final entry in stages.entries) entry.key: entry.value.toJson(),
    },
  };

  static Map<String, EquivalenceStageMetrics> _groupStages(
    List<EquivalenceCaseResult> cases,
  ) {
    final grouped = <String, List<EquivalenceCaseResult>>{};
    for (final result in cases) {
      grouped.putIfAbsent(result.stage, () => []).add(result);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: EquivalenceStageMetrics(
          stage: entry.key,
          cases: entry.value,
        ),
    };
  }
}

class EquivalenceReport {
  EquivalenceReport({
    required this.startedAt,
    required this.finishedAt,
    required this.durationMicros,
    required this.oracle,
    required this.selfBaseline,
    required this.cases,
  }) : metrics = EquivalenceMetrics(cases);

  static const int schemaVersion = 1;

  final DateTime startedAt;
  final DateTime finishedAt;
  final int durationMicros;
  final String oracle;
  final bool selfBaseline;
  final List<EquivalenceCaseResult> cases;
  final EquivalenceMetrics metrics;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt.toIso8601String(),
    'durationMicros': durationMicros,
    'oracle': oracle,
    'selfBaseline': selfBaseline,
    'metrics': metrics.toJson(),
    'cases': [for (final result in cases) result.toJson()],
  };

  String toJsonString({bool pretty = false}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(toJson())
      : jsonEncode(toJson());
}

class _Evaluation {
  const _Evaluation({this.value, this.error});

  final Map<String, Object?>? value;
  final EquivalenceError? error;
}

int _fieldCount(EquivalenceCaseResult result) {
  if (result.actualError != null || result.expectedError != null) return 1;
  final keys = <String>{...result.actual.keys, ...result.expected.keys};
  return keys.length;
}

Map<String, String> _errorComparable(EquivalenceError error) => {
  'type': error.type,
  'message': error.message,
};

int _percentile(List<int> values, double fraction) {
  if (values.isEmpty) return 0;
  values.sort();
  final rank = (values.length * fraction).ceil() - 1;
  return values[rank.clamp(0, values.length - 1)];
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is num && b is num) return a == b;
  // Scalars (String/bool) must compare by value. The original implementation
  // fell through to `false` here, which made every bilateral oracle report a
  // mismatch on scalar fields (self-baseline only passed via `identical`).
  if (a is String && b is String) return a == b;
  if (a is bool && b is bool) return a == b;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }
  return false;
}

Object? _jsonSafe(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) return [for (final item in value) _jsonSafe(item)];
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _jsonSafe(entry.value),
    };
  }
  return value.toString();
}
