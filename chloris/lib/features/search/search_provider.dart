import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';

import '../../app/providers.dart';
import '../../core/persist/kv_settings.dart';
import '../../core/search/source_fanout.dart';
import '../../core/search/search_schedule.dart';
import '../sources/source_library_provider.dart';
import '../../core/search/search_match.dart';
import '../../core/search/search_models.dart';
export '../../core/search/search_models.dart';
export '../../core/search/search_match.dart';

class SearchController extends Notifier<SearchSession> {
  int _token = 0;
  bool _precise = false;
  Set<String> _attemptedSourceUrls = <String>{};

  @override
  SearchSession build() => const SearchSession.empty();

  Future<void> loadMore() async {
    if (!state.finished || state.query.isEmpty) return;
    final resumeCurrentPage = state.remaining > 0;
    final attempted = searchAttemptedSourceUrls(state);
    await run(
      state.query,
      // A cancelled full scan must resume the same page with only sources
      // that have not been attempted. Once the page is complete, the button
      // advances to the next page for every source.
      page: resumeCurrentPage ? state.page : state.page + 1,
      append: true,
      group: state.group,
      excludeSourceUrls: attempted,
      precise: _precise,
    );
  }

  Future<void> run(
    String key, {
    int page = 1,
    bool append = false,
    String group = '',
    Set<String> excludeSourceUrls = const <String>{},
    bool precise = false,
  }) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      state = const SearchSession.empty();
      return;
    }
    _precise = precise;
    final token = ++_token;
    final enabled = await ref.read(enabledSourcesProvider.future);
    if (token != _token) return;
    var enabledList = enabled;
    if (group.isNotEmpty) {
      enabledList = enabled
          .where((s) => (s.bookSourceGroup ?? '未分组') == group)
          .toList();
    }
    if (excludeSourceUrls.isNotEmpty) {
      enabledList = enabledList
          .where((s) => !excludeSourceUrls.contains(s.bookSourceUrl))
          .toList();
    }
    await SourceLatencyStore.ensureLoaded();
    if (token != _token) return;
    SourceLatencyStore.applyTo(enabledList);
    final ordered = orderSearchSources(enabledList);
    final resumeCurrentPage = append && state.remaining > 0;
    final previousDone = state.done;
    final universe = resumeCurrentPage && state.universe > 0
        ? state.universe
        : ordered.length;
    final allCount = resumeCurrentPage ? universe : ordered.length;
    _attemptedSourceUrls = resumeCurrentPage
        ? <String>{...searchAttemptedSourceUrls(state)}
        : <String>{};
    state = SearchSession(
      query: trimmed,
      rows: append ? state.rows : const [],
      done: 0,
      total: allCount,
      finished: ordered.isEmpty,
      page: page,
      group: group,
      remaining: ordered.length,
      universe: universe,
      attemptedSourceUrls: Set.unmodifiable(_attemptedSourceUrls),
    );
    if (ordered.isEmpty) return;

    var completed = resumeCurrentPage ? previousDone : 0;
    final collected = <SourceSearchResult>[if (append) ...state.rows];
    var lastUi = DateTime.fromMillisecondsSinceEpoch(0);
    SearchSession? pendingUi;
    Timer? flushUi;

    void publish(SearchSession session, {bool force = false}) {
      if (token != _token) return;
      final now = DateTime.now();
      if (!force &&
          now.difference(lastUi) < const Duration(milliseconds: 200)) {
        pendingUi = session;
        flushUi ??= Timer(const Duration(milliseconds: 200), () {
          flushUi = null;
          final pending = pendingUi;
          pendingUi = null;
          if (pending != null && token == _token) {
            lastUi = DateTime.now();
            state = pending;
          }
        });
        return;
      }
      lastUi = now;
      pendingUi = null;
      state = session;
    }

    final earlyStopped = await SourceFanout.run(
      sources: ordered,
      query: trimmed,
      page: page,
      search: (s) => ref.read(searchOnlineBooksUseCaseProvider)(
        s,
        trimmed,
        page: page,
        filter: preciseSearchFilter(trimmed, precise: precise),
      ),
      isCancelled: () => token != _token,
      errorOf: friendlySearchError,
      // Only a delivered row is complete. A manually cancelled in-flight
      // request must remain eligible for the next `loadMore()` attempt.
      onRow: (row) {
        if (token != _token) return;
        completed++;
        _attemptedSourceUrls.add(row.source.bookSourceUrl);
        collected.add(row);
        final rows = List<SourceSearchResult>.from(collected);
        publish(
          SearchSession(
            query: trimmed,
            rows: rows,
            done: completed,
            total: allCount,
            finished: completed >= allCount,
            page: page,
            group: group,
            remaining: (universe - completed).clamp(0, universe),
            universe: universe,
            attemptedSourceUrls: Set.unmodifiable(_attemptedSourceUrls),
          ),
          force: completed == 1 || completed >= ordered.length,
        );
      },
    );
    flushUi?.cancel();
    if (token != _token) return;
    if (!state.finished) {
      // Non-early-stop path reaches here only when every source completed, so
      // there is nothing left to continue -> remaining 0. When early-stop fired,
      // `completed < universe`, so we keep the remaining count alive to honor
      // the "continue searching the rest" promise instead of silently dropping
      // the resume entry point (the bug the prior analysis flagged).
      final remaining = earlyStopped
          ? (universe - completed).clamp(0, universe)
          : 0;
      state = SearchSession(
        query: trimmed,
        rows: state.rows,
        done: state.done,
        total: allCount,
        finished: true,
        page: page,
        group: group,
        remaining: remaining,
        universe: universe,
        attemptedSourceUrls: Set.unmodifiable(_attemptedSourceUrls),
      );
    }
  }

  void cancel() {
    _token++;
    ref.read(searchOnlineBooksUseCaseProvider).cancel();
    if (!state.finished) {
      final attempted = Set.unmodifiable(_attemptedSourceUrls);
      final attemptedCount = attempted.length;
      state = SearchSession(
        query: state.query,
        rows: state.rows,
        done: state.done,
        total: state.total,
        finished: true,
        page: state.page,
        group: state.group,
        remaining: (state.universe - attemptedCount).clamp(0, state.universe),
        universe: state.universe,
        attemptedSourceUrls: attempted,
      );
    }
  }
}

/// Returns the source URLs already attempted in a cancelled full scan.
/// Keeping this policy outside the notifier makes the resume contract
/// testable and prevents a "continue" action from silently restarting every
/// source on the next page.
Set<String> searchAttemptedSourceUrls(SearchSession session) {
  if (session.remaining <= 0) return const <String>{};
  if (session.attemptedSourceUrls.isNotEmpty) {
    return session.attemptedSourceUrls;
  }
  return session.rows.map((row) => row.source.bookSourceUrl).toSet();
}

final searchControllerProvider =
    NotifierProvider<SearchController, SearchSession>(SearchController.new);

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<String>>(
      SearchHistoryNotifier.new,
    );

Future<List<SearchBook>> searchBooksOf(
  WidgetRef ref,
  BookSource source,
  String query, {
  int page = 1,
}) {
  return ref.read(searchOnlineBooksUseCaseProvider)(source, query, page: page);
}

class SearchHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    state = p.getStringList('searchHistory') ?? const [];
  }

  Future<void> add(String q) async {
    state = [q, ...state.where((e) => e != q).take(19)];
    final p = await KvSettings.ready();
    await p.setStringList('searchHistory', state);
  }

  Future<void> clear() async {
    state = const [];
    final p = await KvSettings.ready();
    await p.remove('searchHistory');
  }

  Future<void> remove(String q) async {
    state = state.where((e) => e != q).toList();
    final p = await KvSettings.ready();
    await p.setStringList('searchHistory', state);
  }
}
