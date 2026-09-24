import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/persist/kv_settings.dart';

final bookmarkListProvider =
    NotifierProvider<BookmarkListNotifier, List<Bookmark>>(
  BookmarkListNotifier.new,
);

class BookmarkListNotifier extends Notifier<List<Bookmark>> {
  @override
  List<Bookmark> build() {
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final p = await KvSettings.ready();
    final raw = p.getString('bookmarks');
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      state = list
          .whereType<Map>()
          .map((e) => Bookmark.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final p = await KvSettings.ready();
    await p.setString(
      'bookmarks',
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  void add(Bookmark b) {
    state = [...state, b];
    _persist();
  }

  void addAll(Iterable<Bookmark> list) {
    state = [...state, ...list];
    _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }

  void removeAt(int time) {
    state = state.where((e) => e.time != time).toList();
    _persist();
  }

  List<Bookmark> forBook(String name, String author) => state
      .where((e) => e.bookName == name && e.bookAuthor == author)
      .toList();

  /// Removes every bookmark that belongs to one book.
  ///
  /// Deleting a book previously left its bookmarks behind, because the only
  /// removal paths were by timestamp and "clear everything".
  void removeByBook(String name, String author) {
    final next = state
        .where((e) => !(e.bookName == name && e.bookAuthor == author))
        .toList();
    if (next.length == state.length) return;
    state = next;
    _persist();
  }
}
