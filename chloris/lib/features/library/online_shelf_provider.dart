import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import '../../core/persist/kv_settings.dart';
import '../../core/persist/persist_queue.dart';
import '../../data/database/shelf_repository.dart';

import '../../services/persist/vault_sync.dart';

class OnlineShelfItem {
  const OnlineShelfItem({required this.source, required this.searchBook});

  final BookSource source;
  final SearchBook searchBook;

  String get bookUrl => searchBook.bookUrl;

  Map<String, dynamic> toJson() => {
        'source': source.toJson(),
        'book': searchBook.toJson(),
      };

  static OnlineShelfItem? fromJson(Map<String, dynamic> json) {
    final s = json['source'];
    final b = json['book'];
    if (s is! Map || b is! Map) return null;
    return OnlineShelfItem(
      source: BookSource.fromJson(Map<String, dynamic>.from(s)),
      searchBook: SearchBook.fromJson(Map<String, dynamic>.from(b)),
    );
  }
}

final onlineShelfProvider =
    NotifierProvider<OnlineShelfNotifier, List<OnlineShelfItem>>(
  OnlineShelfNotifier.new,
);

class OnlineShelfNotifier extends Notifier<List<OnlineShelfItem>> {
  @override
  List<OnlineShelfItem> build() {
    Future.microtask(_load);
    return const [];
  }

  /// Legacy preference that used to be the shelf's only home.
  ///
  /// Still read once so `books` + `searchBooks` can be populated from it, and
  /// kept as the fallback when no database is available (the Web build until
  /// A3 lands). No longer written once the tables own the data.
  static const legacyShelfKey = 'onlineShelf';

  /// Turns an identity row plus its candidates into the view the UI already
  /// consumes, preferring the candidate for the book's chosen source.
  OnlineShelfItem _toItem(ShelfEntry entry) {
    final candidates = entry.candidates;
    final chosen = candidates.where((c) => c.origin == entry.book.origin);
    final c = chosen.isNotEmpty
        ? chosen.first
        : (candidates.isEmpty ? null : candidates.first);
    return OnlineShelfItem(
      source:
          entry.chosenSource ??
          BookSource(
            bookSourceUrl: entry.book.origin ?? entry.bookUrl,
            bookSourceName: entry.book.originName ?? '',
          ),
      searchBook: SearchBook(
        name: c?.name ?? entry.book.name,
        author: c?.author ?? entry.book.author,
        bookUrl: entry.book.bookUrl,
        origin: entry.book.origin ?? '',
        originName: entry.book.originName ?? '',
        kind: c?.kind ?? entry.book.kind,
        intro: c?.intro ?? entry.book.intro,
        coverUrl: c?.coverUrl ?? entry.book.coverUrl,
        latestChapterTitle:
            c?.latestChapterTitle ?? entry.book.latestChapterTitle,
      ),
    );
  }

  Future<void> _load() async {
    final repo = await ref.read(shelfRepositoryProvider.future);
    if (repo != null) {
      try {
        // Idempotent, so it is safe on every start: duplicate entries cannot
        // create duplicate books because the identity key is (name, author).
        final legacy = (await KvSettings.ready()).getString(legacyShelfKey);
        if (legacy != null && legacy.isNotEmpty) {
          await repo.migrateFromKv(legacy);
        }
        final entries = await repo.load();
        if (entries.isNotEmpty) {
          state = [for (final e in entries) _toItem(e)];
          return;
        }
      } catch (_) {
        // Fall through to the blob rather than showing an empty shelf.
      }
    }

    final p = await KvSettings.ready();
    final raw = p.getString(legacyShelfKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final items = <OnlineShelfItem>[];
      for (final e in list) {
        if (e is Map) {
          final item = OnlineShelfItem.fromJson(Map<String, dynamic>.from(e));
          if (item != null) items.add(item);
        }
      }
      if (items.isNotEmpty) state = items;
    } catch (_) {}
  }

  /// Writes the legacy blob.
  ///
  /// Only used while no database is available. Once the tables exist they are
  /// the shelf's home, and writing both would recreate the two-sources-of-truth
  /// problem the alignment removes.
  Future<void> _persistLegacy() async {
    final p = await KvSettings.ready();
    await p.setString(
      legacyShelfKey,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
    await syncVaultFromPrefs();
  }

  void add(BookSource source, SearchBook searchBook) {
    if (state.any((e) => e.bookUrl == searchBook.bookUrl)) return;
    state = [...state, OnlineShelfItem(source: source, searchBook: searchBook)];
    PersistQueue.instance.schedule('shelf.add.${searchBook.bookUrl}', () async {
      final repo = await ref.read(shelfRepositoryProvider.future);
      if (repo == null) {
        await _persistLegacy();
        return;
      }
      await repo.addCandidate(source, searchBook);
    });
  }

  void replaceBook(String oldUrl, BookSource source, SearchBook searchBook) {
    final next = <OnlineShelfItem>[];
    var replaced = false;
    for (final e in state) {
      if (!replaced &&
          (e.bookUrl == oldUrl ||
              (e.searchBook.name == searchBook.name &&
                  e.searchBook.author == searchBook.author))) {
        next.add(OnlineShelfItem(source: source, searchBook: searchBook));
        replaced = true;
      } else {
        next.add(e);
      }
    }
    if (!replaced) {
      next.add(OnlineShelfItem(source: source, searchBook: searchBook));
    }
    state = next;
    PersistQueue.instance.schedule(
      'shelf.replace.${searchBook.bookUrl}',
      () async {
        final repo = await ref.read(shelfRepositoryProvider.future);
        if (repo == null) {
          await _persistLegacy();
          return;
        }
        // Switching source adds the new candidate to the identity; the previous
        // source's candidate stays, which is what makes switching back possible.
        await repo.addCandidate(source, searchBook);
      },
    );
  }

  void remove(String bookUrl) {
    state = state.where((e) => e.bookUrl != bookUrl).toList();
    PersistQueue.instance.schedule('shelf.remove.$bookUrl', () async {
      final repo = await ref.read(shelfRepositoryProvider.future);
      if (repo == null) {
        await _persistLegacy();
        return;
      }
      await repo.remove(bookUrl);
    });
  }

  void top(String bookUrl) {
    final i = state.indexWhere((e) => e.bookUrl == bookUrl);
    if (i <= 0) return;
    final item = state[i];
    state = [item, ...state.where((e) => e.bookUrl != bookUrl)];
    PersistQueue.instance.schedule('shelf.top.$bookUrl', () async {
      final repo = await ref.read(shelfRepositoryProvider.future);
      if (repo == null) {
        await _persistLegacy();
        return;
      }
      await repo.top(bookUrl);
    });
  }
  bool contains(String bookUrl) => state.any((e) => e.bookUrl == bookUrl);
}
