import 'dart:async';
import 'dart:collection';

import 'package:chloris_engine/chloris_engine.dart';

import 'search_early_stop.dart';

import 'search_match.dart';
import 'search_models.dart';
import 'search_schedule.dart';

typedef SourceSearchFn = Future<List<SearchBook>> Function(BookSource source);

/// Single fan-out used by search and change-source. Host cap + pool + cache.
class SourceFanout {
  SourceFanout._();

  /// Returns whether the run stopped early once the merged hit threshold was
  /// reached. A `true` result means some sources were *not* launched (their
  /// requests were never issued), but any in-flight request that had already
  /// started still completed and its row was delivered. Callers that surface a
  /// "continue searching the rest" affordance must keep that affordance open
  /// when this returns `true`.
  static Future<bool> run({
    required List<BookSource> sources,
    required String query,
    required int page,
    required SourceSearchFn search,
    required void Function(SourceSearchResult row) onRow,
    required bool Function() isCancelled,
    String Function(Object error)? errorOf,

    /// Start requests before persisted-cache hydration completes.  This is
    /// useful for interactive change-source scans where showing the first
    /// live hit is more important than waiting on a platform preferences
    /// bridge; hydration is still awaited before the run is flushed.
    bool waitForCache = true,

    /// Called exactly once when a source is claimed by the queue, before its
    /// request (or cache lookup) starts.  SearchModel uses this to make
    /// cancellation/resume lossless: an in-flight source must not be retried
    /// merely because its result arrived after the cancellation token.
    void Function(BookSource source)? onStart,

    /// Whether to stop launching new sources once the merged hit count reaches
    /// [EngineLimits.searchEarlyStopHits]. Set to `false` to always scan every
    /// source regardless of hits (used by change-source, which ranks
    /// alternatives by score and benefits from scanning all candidates).
    bool earlyStop = false,
  }) async {
    if (sources.isEmpty) return false;
    final cacheReady = SearchHitCache.ensureLoaded();
    final healthReady = SourceHealthStore.ensureLoaded();
    if (waitForCache) await cacheReady;
    final pending = Queue<int>.from(List<int>.generate(sources.length, (i) => i));
    final sourceHosts = sources.map(searchSourceHost).toList(growable: false);
    final inFlightHost = <String, int>{};
    final hostCap = EngineLimits.searchHostCap;
    final cap = EngineLimits.searchPool;
    final pool = sources.length < cap ? sources.length : cap;
    final earlyStopHits = earlyStop ? EngineLimits.searchEarlyStopHits : 0;
    // Count identities rather than raw rows. A source can return the same
    // book several times; counting row.books.length would stop the fan-out
    // before higher-quality sources have a chance to contribute.
    final mergedIdentityKeys = <String>{};
    // Set once the threshold is reached; workers stop claiming new sources but
    // already-started requests still run to completion.
    var stoppedEarly = false;
    Completer<void>? slotWaiter;

    void notifySlot() {
      final waiter = slotWaiter;
      if (waiter == null || waiter.isCompleted) return;
      slotWaiter = null;
      waiter.complete();
    }

    Future<void> waitForSlot() {
      slotWaiter ??= Completer<void>();
      return slotWaiter!.future;
    }

    Future<void> worker() async {
      while (true) {
        if (isCancelled()) {
          notifySlot();
          return;
        }
        if (stoppedEarly) {
          // Hit threshold reached: don't claim any further sources. In-flight
          // requests from earlier iterations still finish and deliver their
          // rows via onRow below.
          notifySlot();
          return;
        }
        var idx = -1;
        final scanCount = pending.length;
        for (var i = 0; i < scanCount; i++) {
          final candidate = pending.removeFirst();
          final candidateHost = sourceHosts[candidate];
          if (hostCap > 0 &&
              (inFlightHost[candidateHost] ?? 0) >= hostCap) {
            pending.addLast(candidate);
            continue;
          }
          if (hostCap > 0) {
            inFlightHost[candidateHost] =
                (inFlightHost[candidateHost] ?? 0) + 1;
          }
          idx = candidate;
          break;
        }
        if (idx < 0) {
          if (pending.isEmpty) return;
          await waitForSlot();
          continue;
        }
        final source = sources[idx];
        onStart?.call(source);
        // Capture the semantic key once. JS evaluation may mutate runtime
        // variables; writing with a recomputed context would make this hit
        // unavailable to the next invocation.
        final cacheKey = SearchCacheKey.fromSource(
          source: source,
          query: query,
          page: page,
        );
        final host = sourceHosts[idx];
        final sw = Stopwatch()..start();
        var failed = false;
        var fromCache = false;
        SourceSearchResult row;
        try {
          final cached = SearchHitCache.instance.takeKey(cacheKey);
          if (cached != null) {
            fromCache = true;
            row = SourceSearchResult(source: source, books: cached);
          } else {
            final list = await search(source);
            final usable = list
                .where((b) => isUsableSearchBook(b, query: query))
                .toList();
            SearchHitCache.instance.putKey(cacheKey, usable);
            row = SourceSearchResult(source: source, books: usable);
          }
        } catch (e) {
          failed = true;
          row = SourceSearchResult(
            source: source,
            error: errorOf?.call(e) ?? e.toString(),
            errorInfo: DomainError.from(
              e,
              stage: DomainErrorStage.search,
              sourceId: source.bookSourceUrl,
            ),
          );
        } finally {
          if (hostCap > 0) {
            final n = (inFlightHost[host] ?? 1) - 1;
            if (n <= 0) {
              inFlightHost.remove(host);
            } else {
              inFlightHost[host] = n;
            }
          }
          notifySlot();
        }
        if (!fromCache) {
          source.respondTime = blendRespondTime(
            source.respondTime,
            sw.elapsedMilliseconds,
            failed: failed,
          );
          SourceLatencyStore.record(source.bookSourceUrl, source.respondTime);
          SourceHealthStore.record(
            source.bookSourceUrl,
            success: !failed && row.books.isNotEmpty,
          );
        }
        if (isCancelled()) return;
        // Count newly discovered identities and arm early-stop for the next
        // loop iteration. This runs synchronously between awaits, so the set
        // is safe across the worker pool.
        for (final book in row.books) {
          mergedIdentityKeys.add(SearchMerge.identity(book));
        }
        if (earlyStopHits > 0 &&
            !stoppedEarly &&
            searchShouldEarlyStop(
              mergedHits: mergedIdentityKeys.length,
              earlyStopHits: earlyStopHits,
            )) {
          stoppedEarly = true;
        }
        onRow(row);
      }
    }

    await Future.wait(List.generate(pool, (_) => worker()));
    await cacheReady;
    await healthReady;
    SourceLatencyStore.flush();
    SourceHealthStore.flush();
    SearchHitCache.instance.flush();
    return stoppedEarly;
  }
}
