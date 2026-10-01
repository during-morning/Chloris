import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import '../../core/persist/kv_settings.dart';

import '../local/local_book_provider.dart';
import '../../core/read/book_validation.dart';
import 'online_shelf_provider.dart';

/// 书架 = 本地导入 + 在线加入。
final booksProvider = FutureProvider<List<Book>>((ref) async {
  final local = ref.watch(localShelfProvider).map((b) => b.book);
  final online = ref.watch(onlineShelfProvider).map((e) => e.toShelfBook());
  return [...local, ...online]
      .where(
        (book) => bookIdentityError(name: book.name, url: book.bookUrl) == null,
      )
      .toList();
});

/// 书架查询/分组状态。
final libraryFilterProvider = StateProvider<String>((ref) => 'all');
final librarySortProvider = StateProvider<String>((ref) => 'latest');

final pinnedUrlsProvider = NotifierProvider<PinnedUrlsNotifier, Set<String>>(
  PinnedUrlsNotifier.new,
);

class PinnedUrlsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    Future.microtask(_load);
    return const {};
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    final list = p.getStringList('pinnedBooks');
    if (list != null && list.isNotEmpty) state = list.toSet();
  }

  Future<void> _persist() async {
    final p = await KvSettings.ready();
    await p.setStringList('pinnedBooks', state.toList());
  }

  void pin(String url) {
    state = {url, ...state};
    _persist();
  }

  void unpin(String url) {
    state = {...state}..remove(url);
    _persist();
  }
}

/// 书架分组定义（id + 名称）。
class BookGroupDef {
  const BookGroupDef({required this.id, required this.name});

  final int id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  static BookGroupDef fromJson(Map<String, dynamic> json) => BookGroupDef(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name']?.toString() ?? '',
  );
}

/// 分组定义：`[{id, name}]`，KV 持久化（与置顶同一模式）。
///
/// 成员关系按 bookUrl 记位掩码（对齐 legado `Book.group` 的位或语义；
/// DB `books.group` 列保留，等表结构迁移定稿后合并）。本地书与在线书
/// 统一走这里，因为本地书架重载时会重新解析出新的 Book 对象。
final bookGroupsProvider =
    NotifierProvider<BookGroupsNotifier, List<BookGroupDef>>(
      BookGroupsNotifier.new,
    );

class BookGroupsNotifier extends Notifier<List<BookGroupDef>> {
  static const _defsKey = 'bookGroupDefs';
  static const _mapKey = 'bookGroupMap';

  @override
  List<BookGroupDef> build() {
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    final raw = p.getString(_defsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      state = [
        for (final e in list)
          if (e is Map) BookGroupDef.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {}
  }

  Future<void> _persist() async {
    final p = await KvSettings.ready();
    await p.setString(
      _defsKey,
      jsonEncode([for (final g in state) g.toJson()]),
    );
  }

  int nextId() {
    var max = 0;
    for (final g in state) {
      if (g.id > max) max = g.id;
    }
    return max + 1;
  }

  Future<void> addGroup(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (state.any((g) => g.name == trimmed)) return;
    state = [...state, BookGroupDef(id: nextId(), name: trimmed)];
    await _persist();
  }

  /// 删除分组并从所有成员关系里清掉该位。
  Future<void> removeGroup(int id) async {
    state = state.where((g) => g.id != id).toList();
    await _persist();
    final p = await KvSettings.ready();
    final raw = p.getString(_mapKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final next = <String, int>{};
      map.forEach((url, bits) {
        final v = ((bits as num?)?.toInt() ?? 0) & ~(1 << id);
        if (v != 0) next[url] = v;
      });
      await p.setString(_mapKey, jsonEncode(next));
    } catch (_) {}
  }
}

/// bookUrl → 分组位掩码（对齐 legado `Book.group`：位或多个分组 id）。
final bookGroupMapProvider =
    NotifierProvider<BookGroupMapNotifier, Map<String, int>>(
      BookGroupMapNotifier.new,
    );

class BookGroupMapNotifier extends Notifier<Map<String, int>> {
  static const _key = 'bookGroupMap';

  @override
  Map<String, int> build() {
    Future.microtask(_load);
    return const {};
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      state = map.map(
        (url, bits) => MapEntry(url, (bits as num?)?.toInt() ?? 0),
      );
    } catch (_) {}
  }

  Future<void> _persist() async {
    final p = await KvSettings.ready();
    await p.setString(_key, jsonEncode(state));
  }

  /// 切换一本书对某分组的归属（位或 / 清位）。
  Future<void> toggle(String bookUrl, int groupId) async {
    final cur = state[bookUrl] ?? 0;
    final next = cur ^ (1 << groupId);
    final nextMap = {...state};
    if (next == 0) {
      nextMap.remove(bookUrl);
    } else {
      nextMap[bookUrl] = next;
    }
    state = nextMap;
    await _persist();
  }

  bool memberOf(String bookUrl, int groupId) =>
      ((state[bookUrl] ?? 0) & (1 << groupId)) != 0;
}
