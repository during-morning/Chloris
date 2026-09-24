import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/persist/kv_settings.dart';

import '../../app/rss_providers.dart';
import '../../application/rss/rss_models.dart';

/// 默认订阅源（打包资产）。
final defaultRssSourcesProvider = FutureProvider<List<RssSource>>((ref) async {
  final raw = await rootBundle.loadString(
    'assets/sources/default_rss_sources.json',
  );
  return RssSource.listFromJson(jsonDecode(raw));
});

/// 拉取并解析某订阅源的文章。
final rssArticlesProvider = FutureProvider.autoDispose
    .family<List<RssArticle>, RssSource>((ref, source) async {
      final useCase = ref.watch(loadRssArticlesUseCaseProvider);
      ref.onDispose(useCase.cancel);
      return useCase(source);
    });

/// 订阅源发现分类的键：同一源 + 某个分类 url 对应一次加载。
class RssCategoryKey {
  const RssCategoryKey(this.source, this.url);

  final RssSource source;
  final String url;

  @override
  bool operator ==(Object other) =>
      other is RssCategoryKey &&
      other.source.sourceUrl == source.sourceUrl &&
      other.url == url;

  @override
  int get hashCode => Object.hash(source.sourceUrl, url);
}

/// 拉取并解析某个发现分类（sortUrl 中的一条）下的文章。
final rssCategoryArticlesProvider = FutureProvider.autoDispose
    .family<List<RssArticle>, RssCategoryKey>((ref, key) async {
      final useCase = ref.watch(loadRssArticlesUseCaseProvider);
      ref.onDispose(useCase.cancel);
      return useCase(key.source, startUrl: key.url);
    });

final rssNameQueryProvider = StateProvider<String>((ref) => '');

final importedRssSourcesProvider =
    NotifierProvider<ImportedRssNotifier, List<RssSource>>(
      ImportedRssNotifier.new,
    );

class ImportedRssNotifier extends Notifier<List<RssSource>> {
  static const _key = 'importedRssSources';

  @override
  List<RssSource> build() {
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      state = RssSource.listFromJson(jsonDecode(raw));
    } catch (_) {}
  }

  Future<void> _persist() async {
    final p = await KvSettings.ready();
    await p.setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  void addAll(Iterable<RssSource> list) {
    final seen = {for (final s in state) s.sourceUrl};
    final extra = list.where((s) => seen.add(s.sourceUrl)).toList();
    if (extra.isEmpty) return;
    state = [...state, ...extra];
    _persist();
  }

  void remove(String url) {
    state = state.where((s) => s.sourceUrl != url).toList();
    _persist();
  }
}

final allRssSourcesProvider = Provider<AsyncValue<List<RssSource>>>((ref) {
  final base = ref.watch(defaultRssSourcesProvider);
  final extra = ref.watch(importedRssSourcesProvider);
  return base.when(
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
    data: (list) {
      final seen = {for (final s in extra) s.sourceUrl};
      final merged = [
        ...extra,
        ...list.where((s) => !seen.contains(s.sourceUrl)),
      ];
      return AsyncData(merged);
    },
  );
});

/// RSS 文章收藏。
final starredRssProvider = NotifierProvider<StarredRssNotifier, Set<String>>(
  StarredRssNotifier.new,
);

final rssArticleSnapshotsProvider =
    NotifierProvider<RssArticleSnapshotsNotifier, Map<String, RssArticle>>(
      RssArticleSnapshotsNotifier.new,
    );

class RssArticleSnapshotsNotifier extends Notifier<Map<String, RssArticle>> {
  @override
  Map<String, RssArticle> build() {
    Future.microtask(_load);
    return const {};
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    final raw = p.getString('rssArticleSnapshots');
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map;
      state = {
        for (final e in map.entries)
          e.key.toString(): RssArticle.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          ),
      };
    } catch (_) {}
  }

  Future<void> save(RssArticle article) async {
    final key = article.link.isNotEmpty ? article.link : article.title;
    if (key.isEmpty || article.title.trim().isEmpty) return;
    state = {...state, key: article};
    final p = await KvSettings.ready();
    await p.setString(
      'rssArticleSnapshots',
      jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}),
    );
  }

  Future<void> remove(String key) async {
    state = {...state}..remove(key);
    await _persist();
  }

  Future<void> removeMany(Iterable<String> keys) async {
    final next = {...state};
    for (final key in keys) next.remove(key);
    state = next;
    await _persist();
  }

  Future<void> clearOrphans(Set<String> starredLinks) async {
    final orphans = state.keys
        .where((key) => !starredLinks.contains(key))
        .toList();
    if (orphans.isNotEmpty) await removeMany(orphans);
  }

  Future<void> _persist() async {
    final p = await KvSettings.ready();
    await p.setString(
      'rssArticleSnapshots',
      jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}),
    );
  }
}

class StarredRssNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    Future.microtask(_load);
    return const {};
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    final list = p.getStringList('rssStars');
    if (list != null && list.isNotEmpty) state = list.toSet();
  }

  Future<void> _persist() async {
    final p = await KvSettings.ready();
    await p.setStringList('rssStars', state.toList());
  }

  void clear() {
    state = const {};
    _persist();
  }

  void toggle(String link) {
    final next = {...state};
    if (next.contains(link)) {
      next.remove(link);
    } else {
      next.add(link);
    }
    state = next;
    _persist();
  }
}

Future<int> importRssSourcesFromUrl(WidgetRef ref, String url) async {
  final list = await ref.read(importRssSourcesUseCaseProvider)(url);
  ref.read(importedRssSourcesProvider.notifier).addAll(list);
  return list.length;
}
