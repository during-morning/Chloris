import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';

import '../../app/providers.dart';
import '../../core/persist/kv_settings.dart';
import '../../core/search/source_fanout.dart';
import '../../core/http/http_session.dart';
import '../../core/search/search_schedule.dart';
import '../sources/source_library_provider.dart';
import '../../core/search/search_match.dart';
import '../../core/search/search_models.dart';
export '../../core/search/search_models.dart';
export '../../core/search/search_match.dart';

class SearchController extends Notifier<SearchSession> {
  int _token = 0;
  bool _precise = false;

  @override
  SearchSession build() => const SearchSession.empty();

  Future<void> loadMore() async {
    if (!state.finished || state.query.isEmpty) return;
    await run(
      state.query,
      page: state.page + 1,
      append: true,
      group: state.group,
      precise: _precise,
    );
  }

  Future<void> run(
    String key, {
    int page = 1,
    bool append = false,
    String group = '',
    bool precise = false,
  }) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      _token++;
      if (!state.finished) {
        ref.read(searchOnlineBooksUseCaseProvider).cancel();
      }
      state = const SearchSession.empty();
      return;
    }
    _precise = precise;
    final token = ++_token;
    // Submitting a new query while a scan is running is a restart: cancel its
    // in-flight HTTP session before scheduling the new query from page one.
    if (!state.finished) {
      ref.read(searchOnlineBooksUseCaseProvider).cancel();
    }
    state = SearchSession(
      query: trimmed,
      rows: append ? state.rows : const [],
      done: 0,
      total: 0,
      finished: false,
      page: page,
      group: group,
    );
    final enabled = await ref.read(enabledSourcesProvider.future);
    if (token != _token) return;
    var enabledList = enabled;
    if (group.isNotEmpty) {
      enabledList = enabled
          .where((s) => (s.bookSourceGroup ?? '未分组') == group)
          .toList();
    }
    await SourceLatencyStore.ensureLoaded().timeout(
      const Duration(milliseconds: 100),
      onTimeout: () {},
    );
    if (token != _token) return;
    SourceLatencyStore.applyTo(enabledList);
    final ordered = orderSearchSources(enabledList);
    final universe = ordered.length;
    final allCount = ordered.length;
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
    );
    if (ordered.isEmpty) return;

    var completed = 0;
    final collected = <SourceSearchResult>[if (append) ...state.rows];
    var lastUi = DateTime.fromMillisecondsSinceEpoch(0);
    Timer? flushUi;

    SearchSession snapshot() => SearchSession(
      query: trimmed,
      rows: List<SourceSearchResult>.unmodifiable(collected),
      done: completed,
      total: allCount,
      finished: completed >= allCount,
      page: page,
      group: group,
      remaining: (universe - completed).clamp(0, universe),
      universe: universe,
    );

    void publish({bool force = false}) {
      if (token != _token) return;
      final now = DateTime.now();
      if (!force &&
          now.difference(lastUi) < const Duration(milliseconds: 200)) {
        flushUi ??= Timer(const Duration(milliseconds: 200), () {
          flushUi = null;
          publish(force: true);
        });
        return;
      }
      lastUi = now;
      state = snapshot();
    }

    await SourceFanout.run(
      sources: ordered,
      query: trimmed,
      page: page,
      search: (s) => HttpSession.bind(
        'search.$token',
        () => ref.read(searchOnlineBooksUseCaseProvider)(
          s,
          trimmed,
          page: page,
          filter: preciseSearchFilter(trimmed, precise: precise),
        ),
      ),
      isCancelled: () => token != _token,
      errorOf: friendlySearchError,
      // Cache hydration is an optimization; it must not delay the first live
      // source requests on a cold launch.
      waitForCache: false,
      // A search must not silently pause after reaching a hit threshold. Let
      // every eligible source finish; the next explicit request starts fresh.
      earlyStop: false,
      onRow: (row) {
        if (token != _token) return;
        completed++;
        collected.add(row);
        publish(force: completed == 1 || completed >= ordered.length);
      },
    );
    flushUi?.cancel();
    if (token != _token) return;
    if (!state.finished) {
      state = SearchSession(
        query: trimmed,
        rows: List<SourceSearchResult>.unmodifiable(collected),
        done: completed,
        total: allCount,
        finished: true,
        page: page,
        group: group,
        remaining: 0,
        universe: universe,
      );
    } else if (state.rows.length != collected.length) {
      state = snapshot();
    }
  }

  void cancel() {
    _token++;
    ref.read(searchOnlineBooksUseCaseProvider).cancel();
    if (!state.finished) {
      state = SearchSession(
        query: state.query,
        rows: state.rows,
        done: state.done,
        total: state.total,
        finished: true,
        page: state.page,
        group: state.group,
        remaining: 0,
        universe: state.universe,
      );
    }
  }
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
