import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/persist/kv_settings.dart';
import '../../core/persist/app_db.dart';
import '../../core/persist/persist_queue.dart';
import '../../data/database/app_database.dart' hide BookSource, Book;

import '../../app/providers.dart';
import '../../application/sources/source_unify.dart';

/// url -> enabled override, persisted.
final sourceEnabledOverrideProvider =
    NotifierProvider<SourceEnabledOverrideNotifier, Map<String, bool>>(
      SourceEnabledOverrideNotifier.new,
    );

class SourceEnabledOverrideNotifier extends Notifier<Map<String, bool>> {
  SourceEnabledOverrideNotifier({Map<String, bool>? seed})
    : _seed = seed ?? const {};

  final Map<String, bool> _seed;

  @override
  Map<String, bool> build() {
    Future.microtask(_load);
    return Map<String, bool>.from(_seed);
  }

  Future<void> _load() async {
    final overlay = <String, bool>{};
    final prefs = await KvSettings.ready();
    final raw = prefs.getString('sourceEnabled');
    if (raw != null && raw.isNotEmpty) {
      try {
        overlay.addAll(
          (jsonDecode(raw) as Map).map(
            (k, v) => MapEntry(k.toString(), v == true),
          ),
        );
      } catch (_) {}
    }
    final d = await AppDb.open();
    if (d != null) {
      try {
        final rows = await d.select(d.bookSources).get();
        for (final r in rows) {
          overlay.putIfAbsent(r.bookSourceUrl, () => r.enabled);
        }
      } catch (_) {}
    }
    if (overlay.isNotEmpty) state = overlay;
  }

  void replace(Map<String, bool> map) => state = Map<String, bool>.from(map);

  Future<void> setEnabled(String url, bool enabled) async {
    state = {...state, url: enabled};
    final prefs = await KvSettings.ready();
    await prefs.setString('sourceEnabled', jsonEncode(state));
    PersistQueue.instance.schedule('sourceEnabled.drift', () async {
      final d = await AppDb.open();
      if (d == null) return;
      final snapshot = Map<String, bool>.from(state);
      for (final e in snapshot.entries) {
        final n =
            await (d.update(d.bookSources)
                  ..where((t) => t.bookSourceUrl.equals(e.key)))
                .write(BookSourcesCompanion(enabled: Value(e.value)));
        if (n == 0) {
          await d
              .into(d.bookSources)
              .insert(
                BookSourcesCompanion.insert(
                  bookSourceUrl: e.key,
                  bookSourceName: '',
                  enabled: Value(e.value),
                ),
              );
        }
      }
    });
  }
}

/// 用户导入/启停的书源（可变）。默认源来自打包资产（defaultSourcesProvider）。
final importedSourcesProvider =
    NotifierProvider<ImportedSourcesNotifier, List<BookSource>>(
      ImportedSourcesNotifier.new,
    );

class ImportedSourcesNotifier extends Notifier<List<BookSource>> {
  @override
  List<BookSource> build() {
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final prefs = await KvSettings.ready();
    final raw = prefs.getString('importedSources');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = BookSource.listFromJson(jsonDecode(raw));
        if (list.isNotEmpty) {
          state = list;
          return;
        }
      } catch (_) {}
    }
    final d = await AppDb.open();
    if (d == null) return;
    try {
      final rows = await d.select(d.bookSources).get();
      final items = <BookSource>[];
      for (final r in rows) {
        final blob = r.raw;
        if (blob == null || blob.isEmpty) continue;
        try {
          final decoded = jsonDecode(blob);
          if (decoded is Map) {
            items.add(BookSource.fromJson(Map<String, dynamic>.from(decoded)));
          }
        } catch (_) {
          items.add(
            BookSource(
              bookSourceUrl: r.bookSourceUrl,
              bookSourceName: r.bookSourceName,
              bookSourceGroup: r.bookSourceGroup,
              bookSourceType: r.bookSourceType,
              enabled: r.enabled,
              enabledExplore: r.enabledExplore,
            ),
          );
        }
      }
      if (items.isNotEmpty) state = items;
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await KvSettings.ready();
    await prefs.setString(
      'importedSources',
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
    PersistQueue.instance.schedule('importedSources.drift', _persistDrift);
  }

  Future<void> _persistDrift() async {
    final d = await AppDb.open();
    if (d == null) return;
    try {
      for (final s in state) {
        final n =
            await (d.update(
              d.bookSources,
            )..where((t) => t.bookSourceUrl.equals(s.bookSourceUrl))).write(
              BookSourcesCompanion(
                bookSourceName: Value(s.bookSourceName),
                bookSourceGroup: Value(s.bookSourceGroup),
                bookSourceType: Value(s.bookSourceType),
                enabled: Value(s.enabled),
                enabledExplore: Value(s.enabledExplore),
                lastUpdateTime: Value(s.lastUpdateTime),
                respondTime: Value(s.respondTime),
                weight: Value(s.weight),
                raw: Value(jsonEncode(s.toJson())),
              ),
            );
        if (n == 0) {
          await d
              .into(d.bookSources)
              .insert(
                BookSourcesCompanion.insert(
                  bookSourceUrl: s.bookSourceUrl,
                  bookSourceName: s.bookSourceName,
                  bookSourceGroup: Value(s.bookSourceGroup),
                  bookSourceType: Value(s.bookSourceType),
                  enabled: Value(s.enabled),
                  enabledExplore: Value(s.enabledExplore),
                  lastUpdateTime: Value(s.lastUpdateTime),
                  respondTime: Value(s.respondTime),
                  weight: Value(s.weight),
                  raw: Value(jsonEncode(s.toJson())),
                ),
              );
        }
      }
    } catch (_) {}
  }

  void addAll(Iterable<BookSource> sources) {
    final map = <String, BookSource>{for (final s in state) s.bookSourceUrl: s};
    for (final s in sources) {
      if (isAdultSourceLabel('${s.bookSourceGroup ?? ''}${s.bookSourceName}') ||
          isDictionarySourceLabel(
            '${s.bookSourceGroup ?? ''}${s.bookSourceName}',
          )) {
        continue;
      }
      s.enabled = true;
      final key = canonicalizeSourceUrl(s.bookSourceUrl);
      if (key.isNotEmpty) s.bookSourceUrl = key;
      s.bookSourceGroup = unifySourceGroup(s);
      map[s.bookSourceUrl] = s;
    }
    state = map.values.toList();
    // Persistence is best-effort in headless/widget-test environments.
    _persist().catchError((_) {});
  }

  void remove(String url) {
    state = state.where((s) => s.bookSourceUrl != url).toList();
    _persist().catchError((_) {});
  }

  void upsert(BookSource source) {
    addAll([source]);
  }
}

/// 全部书源 = 默认源 + 导入源 + 启停覆盖。
final allSourcesProvider = FutureProvider<List<BookSource>>((ref) async {
  final defaults = await ref.watch(defaultSourcesProvider.future);
  final imported = ref.watch(importedSourcesProvider);
  final overlay = ref.watch(sourceEnabledOverrideProvider);
  final map = <String, BookSource>{
    for (final s in defaults) s.bookSourceUrl: s,
  };
  for (final s in imported) {
    map[s.bookSourceUrl] = s;
  }
  for (final s in map.values) {
    final v = overlay[s.bookSourceUrl];
    if (v != null) s.enabled = v;
  }
  return map.values.toList();
});

/// 启用且有搜索规则的书源（供搜索使用）。
final sourceNameQueryProvider = StateProvider<String>((ref) => '');

class _PersistedStringN extends Notifier<String?> {
  _PersistedStringN(this.key);
  final String key;
  @override
  String? build() {
    Future.microtask(_load);
    return null;
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    state = p.getString(key);
  }

  Future<void> setValue(String? v) async {
    state = v;
    final p = await KvSettings.ready();
    if (v == null || v.isEmpty) {
      await p.remove(key);
    } else {
      await p.setString(key, v);
    }
  }
}

class _PersistedBoolN extends Notifier<bool> {
  _PersistedBoolN(this.key, {this.fallback = false});
  final String key;
  final bool fallback;
  @override
  bool build() {
    Future.microtask(_load);
    return fallback;
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    state = p.getBool(key) ?? fallback;
  }

  Future<void> setValue(bool v) async {
    state = v;
    final p = await KvSettings.ready();
    await p.setBool(key, v);
  }
}

final sourceGroupFilterProvider = NotifierProvider<_PersistedStringN, String?>(
  () => _PersistedStringN('sourceGroupFilter'),
);
final sourceOnlyEnabledProvider = NotifierProvider<_PersistedBoolN, bool>(
  () => _PersistedBoolN('sourceOnlyEnabled'),
);
final sourceTypeFilterProvider = NotifierProvider<_PersistedStringN, String?>(
  () => _PersistedStringN('sourceTypeFilter'),
);

final enabledSourcesProvider = FutureProvider<List<BookSource>>((ref) async {
  final all = await ref.watch(allSourcesProvider.future);
  return all.where((s) => s.enabled && s.hasSearch).toList();
});

final enabledExploreSourcesProvider = FutureProvider<List<BookSource>>((
  ref,
) async {
  final all = await ref.watch(allSourcesProvider.future);
  return all
      .where((s) => s.enabled && s.enabledExplore && s.hasExploreUrl)
      .toList();
});

final filteredSourcesProvider = Provider<AsyncValue<List<BookSource>>>((ref) {
  final sources = ref.watch(allSourcesProvider);
  final filter = ref.watch(sourceGroupFilterProvider);
  final q = ref.watch(sourceNameQueryProvider).toLowerCase();
  final onlyEnabled = ref.watch(sourceOnlyEnabledProvider);
  final typeF = ref.watch(sourceTypeFilterProvider);
  return sources.whenData((list) {
    var shown = filter == null
        ? list
        : list.where((s) => displaySourceGroup(s) == filter).toList();
    if (q.isNotEmpty) {
      shown = shown
          .where(
            (s) =>
                s.bookSourceName.toLowerCase().contains(q) ||
                s.bookSourceUrl.toLowerCase().contains(q),
          )
          .toList();
    }
    if (onlyEnabled) {
      shown = shown.where((s) => s.enabled).toList();
    }
    if (typeF != null && typeF.isNotEmpty) {
      final t = int.tryParse(typeF);
      if (t != null) {
        shown = shown.where((s) => s.bookSourceType == t).toList();
      }
    }
    return shown;
  });
});
