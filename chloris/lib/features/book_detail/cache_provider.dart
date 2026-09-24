import 'dart:async';
import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/download/download_use_cases.dart';
import '../../core/persist/kv_settings.dart';

enum CacheJobEventType {
  restored,
  enqueued,
  resumed,
  started,
  progress,
  failed,
  cancelled,
  completed,
}

/// A durable snapshot of a queue transition. Riverpod state remains the
/// source of truth for widgets; this stream lets background/startup code
/// observe transitions without polling the whole job list.
class CacheJobEvent {
  const CacheJobEvent({
    required this.type,
    required this.jobId,
    required this.done,
    required this.failed,
    required this.pending,
    required this.at,
    this.index,
  });

  final CacheJobEventType type;
  final String jobId;
  final int done;
  final int failed;
  final int pending;
  final int at;
  final int? index;
}

/// Fresh callbacks supplied by the application when a persisted task is
/// resumed. Closures themselves intentionally never enter SharedPreferences.
typedef CacheJobResumeResolver =
    Future<DownloadResumeHandler?> Function(CacheJob job);

class CacheJob {
  CacheJob({
    required this.bookName,
    required this.fromIndex,
    required this.total,
    String? id,
    int? createdAt,
    this.done = 0,
    this.failed = 0,
    this.running = true,
    this.cancelled = false,
    this.paused = false,
    Set<int>? completedIndexes,
    Set<int>? failedIndexes,
    this.metadata,
  }) : id = id ?? _newJobId(bookName, fromIndex, total),
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       completedIndexes = completedIndexes ?? <int>{},
       failedIndexes = failedIndexes ?? <int>{};

  factory CacheJob.fromJson(Map<String, dynamic> json) {
    final completed = _intSet(json['completedIndexes']);
    final failed = _intSet(json['failedIndexes']);
    return CacheJob(
      id: json['id']?.toString(),
      createdAt: (json['createdAt'] as num?)?.toInt(),
      bookName: json['bookName']?.toString() ?? '',
      fromIndex: (json['fromIndex'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      done: (json['done'] as num?)?.toInt() ?? completed.length + failed.length,
      failed: (json['failed'] as num?)?.toInt() ?? failed.length,
      running: json['running'] == true,
      cancelled: json['cancelled'] == true,
      paused: json['paused'] == true,
      completedIndexes: completed,
      failedIndexes: failed,
      metadata: json['metadata'] is Map
          ? BatchDownloadMetadata.fromJson(
              Map<String, dynamic>.from(json['metadata'] as Map),
            )
          : null,
    );
  }

  final String id;
  final int createdAt;

  final String bookName;
  final int fromIndex;
  final int total;
  BatchDownloadMetadata? metadata;
  int done;
  int failed;
  bool running;
  bool cancelled = false;
  bool paused = false;
  final Set<int> completedIndexes;
  final Set<int> failedIndexes;

  int get targetCount => (total - fromIndex).clamp(0, total);

  /// Indexes that still need a successful fetch. Failed indexes remain
  /// retryable so an explicit resume can make forward progress.
  Iterable<int> get pendingIndexes sync* {
    for (var i = fromIndex; i < total; i++) {
      if (!completedIndexes.contains(i)) yield i;
    }
  }

  int get pendingCount => pendingIndexes.length;

  bool get hasPending => pendingCount > 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt,
    'bookName': bookName,
    'fromIndex': fromIndex,
    'total': total,
    'done': done,
    'failed': failed,
    'running': running,
    'cancelled': cancelled,
    'paused': paused,
    'completedIndexes': completedIndexes.toList()..sort(),
    'failedIndexes': failedIndexes.toList()..sort(),
    if (metadata != null) 'metadata': metadata!.toJson(),
  };
}

String _newJobId(String bookName, int fromIndex, int total) =>
    '$bookName|$fromIndex|$total|${DateTime.now().microsecondsSinceEpoch}';

Set<int> _intSet(Object? raw) {
  if (raw is! List) return <int>{};
  return {
    for (final value in raw)
      if (value is num) value.toInt(),
  };
}

final cacheJobsProvider = NotifierProvider<CacheJobsNotifier, List<CacheJob>>(
  CacheJobsNotifier.new,
);

final batchDownloadUseCaseProvider = Provider<BatchDownloadUseCase>((ref) {
  final notifier = ref.read(cacheJobsProvider.notifier);
  return BatchDownloadUseCase(
    _CacheJobsDownloadAdapter(notifier, () => ref.read(cacheJobsProvider)),
  );
});

class _CacheJobsDownloadAdapter implements MetadataBatchDownloadPort {
  _CacheJobsDownloadAdapter(this._notifier, this._jobs);

  final CacheJobsNotifier _notifier;
  final List<CacheJob> Function() _jobs;

  @override
  Future<void> enqueueOrResume({
    required String bookName,
    required int fromIndex,
    required int total,
    required Future<void> Function(int index) fetchChapter,
    String Function(int index)? hostOf,
  }) => _enqueueOrResume(
    bookName: bookName,
    fromIndex: fromIndex,
    total: total,
    fetchChapter: fetchChapter,
    hostOf: hostOf,
  );

  @override
  Future<void> enqueueOrResumeWithMetadata({
    required String bookName,
    required int fromIndex,
    required int total,
    required Future<void> Function(int index) fetchChapter,
    String Function(int index)? hostOf,
    BatchDownloadMetadata? metadata,
  }) => _enqueueOrResume(
    bookName: bookName,
    fromIndex: fromIndex,
    total: total,
    fetchChapter: fetchChapter,
    hostOf: hostOf,
    metadata: metadata,
  );

  Future<void> _enqueueOrResume({
    required String bookName,
    required int fromIndex,
    required int total,
    required Future<void> Function(int index) fetchChapter,
    String Function(int index)? hostOf,
    BatchDownloadMetadata? metadata,
  }) async {
    CacheJob? existing;
    for (final job in _jobs().reversed) {
      final persisted = job.metadata;
      final sameBook =
          persisted?.bookUrl.trim().isNotEmpty == true &&
              metadata?.bookUrl.trim().isNotEmpty == true
          ? persisted!.bookUrl == metadata!.bookUrl &&
                (persisted.sourceId.trim().isEmpty ||
                    metadata.sourceId.trim().isEmpty ||
                    persisted.sourceId == metadata.sourceId)
          : job.bookName == bookName;
      if (sameBook &&
          job.total == total &&
          job.fromIndex == fromIndex &&
          (job.paused || job.cancelled || job.failedIndexes.isNotEmpty)) {
        if (metadata != null) job.metadata = metadata;
        existing = job;
        break;
      }
    }
    if (existing != null) {
      await _notifier.resume(
        existing,
        fetchChapter: fetchChapter,
        hostOf: hostOf,
      );
      return;
    }
    await _notifier.enqueue(
      bookName: bookName,
      fromIndex: fromIndex,
      total: total,
      metadata: metadata,
      hostOf: hostOf,
      fetchChapter: fetchChapter,
    );
  }
}

class CacheJobsNotifier extends Notifier<List<CacheJob>> {
  static const _key = 'cacheJobsV1';
  Future<void> _persistTail = Future<void>.value();
  final StreamController<CacheJobEvent> _events =
      StreamController<CacheJobEvent>.broadcast();
  Completer<void> _restoreDone = Completer<void>();

  Stream<CacheJobEvent> get events => _events.stream;

  /// Completes after the first SharedPreferences snapshot has been applied.
  Future<void> get restored => _restoreDone.future;

  List<CacheJob> get pendingJobs =>
      List.unmodifiable(state.where((job) => job.hasPending));

  @override
  List<CacheJob> build() {
    _restoreDone = Completer<void>();
    ref.onDispose(() {
      _events.close();
      if (!_restoreDone.isCompleted) _restoreDone.complete();
    });
    Future<void>.microtask(() async {
      try {
        await _restore();
      } finally {
        if (!_restoreDone.isCompleted) _restoreDone.complete();
      }
    });
    return const [];
  }

  void _emit(CacheJob job, CacheJobEventType type, {int? index}) {
    if (_events.isClosed) return;
    _events.add(
      CacheJobEvent(
        type: type,
        jobId: job.id,
        done: job.done,
        failed: job.failed,
        pending: job.pendingCount,
        at: DateTime.now().millisecondsSinceEpoch,
        index: index,
      ),
    );
  }

  Future<void> _restore() async {
    final p = await KvSettings.ready();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final restored = <CacheJob>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final job = CacheJob.fromJson(Map<String, dynamic>.from(item));
        if (job.bookName.trim().isEmpty || job.total <= 0) continue;
        // Closures cannot survive a process restart. Preserve progress and
        // expose a paused task rather than claiming that it resumed itself.
        if (job.running) {
          job.running = false;
          job.paused = true;
          job.cancelled = false;
        }
        restored.add(job);
      }
      if (restored.isNotEmpty) {
        state = restored;
        for (final job in restored) {
          _emit(job, CacheJobEventType.restored);
        }
        await _persist();
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    final snapshot = jsonEncode(state.map((j) => j.toJson()).toList());
    _persistTail = _persistTail.catchError((_) {}).then((_) async {
      final p = await KvSettings.ready();
      await p.setString(_key, snapshot);
    });
    await _persistTail;
  }

  Future<void> enqueue({
    required String bookName,
    required int fromIndex,
    required int total,
    required Future<void> Function(int i) fetchChapter,
    String Function(int i)? hostOf,
    BatchDownloadMetadata? metadata,
  }) async {
    final job = CacheJob(
      bookName: bookName,
      fromIndex: fromIndex,
      total: total,
      metadata: metadata,
    );
    state = [...state, job];
    await _persist();
    _emit(job, CacheJobEventType.enqueued);
    await _runJob(job, fetchChapter: fetchChapter, hostOf: hostOf);
  }

  /// Resume a paused/cancelled task while the caller can still provide the
  /// original chapter fetch closure.
  Future<void> resume(
    CacheJob job, {
    required Future<void> Function(int i) fetchChapter,
    String Function(int i)? hostOf,
  }) async {
    if (job.running) return;
    // A failed attempt is retryable on an explicit resume. Completed indexes
    // remain durable and are never fetched twice.
    job.failedIndexes.clear();
    job.failed = 0;
    job.done = job.completedIndexes.length;
    job.cancelled = false;
    job.paused = false;
    state = [...state];
    await _persist();
    _emit(job, CacheJobEventType.resumed);
    await _runJob(job, fetchChapter: fetchChapter, hostOf: hostOf);
  }

  /// Resolve every persisted paused/cancelled task with fresh runtime
  /// callbacks. Returns the number of tasks for which a resolver was found.
  /// This is explicit by design: no callback or network client is fabricated
  /// after a process restart.
  Future<int> resumePending({
    required CacheJobResumeResolver resolve,
    bool includeCancelled = true,
  }) async {
    final candidates = List<CacheJob>.from(
      pendingJobs.where(
        (job) =>
            !job.running &&
            (job.paused ||
                (includeCancelled && job.cancelled) ||
                job.failedIndexes.isNotEmpty),
      ),
    );
    var resumed = 0;
    for (final job in candidates) {
      final handler = await resolve(job);
      if (handler == null) continue;
      await resume(
        job,
        fetchChapter: handler.fetchChapter,
        hostOf: handler.hostOf,
      );
      resumed++;
    }
    return resumed;
  }

  Future<void> _runJob(
    CacheJob job, {
    required Future<void> Function(int i) fetchChapter,
    String Function(int i)? hostOf,
  }) async {
    job.running = true;
    job.paused = false;
    job.done = job.completedIndexes.length + job.failedIndexes.length;
    job.failed = job.failedIndexes.length;
    state = [...state];
    await _persist();
    _emit(job, CacheJobEventType.started);
    // ParallelChapterFetch has no per-host cap; keep local workers.
    final conc = EngineLimits.downloadPool;
    final hostCap = EngineLimits.downloadHostCap;
    final total = job.total;
    final fromIndex = job.fromIndex;
    final claimed = List<bool>.filled(total, false);
    for (var i = 0; i < fromIndex && i < total; i++) {
      claimed[i] = true;
    }
    // Failed indexes are intentionally left claimable. They are retried by an
    // explicit resume, while successful indexes remain exactly-once.
    for (final i in job.completedIndexes) {
      if (i >= 0 && i < total) claimed[i] = true;
    }
    final inFlightHost = <String, int>{};

    bool allClaimed() {
      for (var i = fromIndex; i < total; i++) {
        if (!claimed[i]) return false;
      }
      return true;
    }

    Future<void> worker() async {
      while (true) {
        if (job.cancelled) return;
        var i = -1;
        for (var c = fromIndex; c < total; c++) {
          if (claimed[c]) continue;
          final host = hostOf?.call(c) ?? '';
          if (host.isNotEmpty && (inFlightHost[host] ?? 0) >= hostCap) {
            continue;
          }
          claimed[c] = true;
          if (host.isNotEmpty) {
            inFlightHost[host] = (inFlightHost[host] ?? 0) + 1;
          }
          i = c;
          break;
        }
        if (i < 0) {
          if (allClaimed()) return;
          await Future<void>.delayed(const Duration(milliseconds: 40));
          continue;
        }
        var ok = false;
        for (var attempt = 0; attempt < 2 && !ok; attempt++) {
          if (job.cancelled) break;
          try {
            await fetchChapter(i);
            ok = true;
          } catch (_) {
            if (attempt == 0) {
              await Future<void>.delayed(const Duration(milliseconds: 280));
            }
          }
        }
        final host = hostOf?.call(i) ?? '';
        if (host.isNotEmpty) {
          final n = (inFlightHost[host] ?? 1) - 1;
          if (n <= 0) {
            inFlightHost.remove(host);
          } else {
            inFlightHost[host] = n;
          }
        }
        if (ok) {
          job.failedIndexes.remove(i);
          job.completedIndexes.add(i);
        } else {
          job.failedIndexes.add(i);
          _emit(job, CacheJobEventType.failed, index: i);
        }
        job.failed = job.failedIndexes.length;
        job.done = job.completedIndexes.length + job.failedIndexes.length;
        state = [...state];
        _emit(job, CacheJobEventType.progress, index: i);
        unawaited(_persist());
      }
    }

    final pending = claimed.where((value) => !value).length;
    if (pending == 0) {
      job.running = false;
      job.paused = false;
      job.cancelled = false;
      state = [...state];
      await _persist();
      _emit(job, CacheJobEventType.completed);
      return;
    }
    final n = pending < conc ? pending.clamp(1, conc) : conc;
    await Future.wait(List.generate(n, (_) => worker()));
    job.running = false;
    job.paused = false;
    state = [...state];
    await _persist();
    if (job.cancelled) {
      _emit(job, CacheJobEventType.cancelled);
    } else {
      _emit(job, CacheJobEventType.completed);
    }
  }

  void cancel(CacheJob job) {
    job.cancelled = true;
    job.running = false;
    job.paused = false;
    state = [...state];
    _persist();
    _emit(job, CacheJobEventType.cancelled);
  }

  void clearFinished() {
    state = state.where((j) => j.running).toList();
    _persist();
  }
}
