import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import '../../core/persist/kv_settings.dart';
import '../../core/persist/persist_queue.dart';
import '../../core/startup_metrics.dart';
import '../../core/search/search_match.dart';
import '../../core/read/book_validation.dart';
import '../../data/database/shelf_repository.dart';

import '../../services/persist/vault_sync.dart';

class OnlineShelfItem {
  const OnlineShelfItem({
    required this.source,
    required this.searchBook,
    this.identityBookUrl,
  });

  final BookSource source;
  final SearchBook searchBook;

  /// URL of the deduplicated identity row in `books`.
  final String? identityBookUrl;

  /// Shelf operations use the identity URL; scraping uses candidateBookUrl.
  String get bookUrl => identityBookUrl == null || identityBookUrl!.isEmpty
      ? searchBook.bookUrl
      : identityBookUrl!;

  String get candidateBookUrl => searchBook.bookUrl;

  /// Book identity used by the library is distinct from the active candidate
  /// URL used for scraping. Keeping the identity here lets delete, pin and
  /// progress actions address the same row that the shelf repository owns.
  Book toShelfBook() {
    final book = searchBook.toBook();
    book.bookUrl = bookUrl;
    return book;
  }

  Map<String, dynamic> toJson() => {
    'source': source.toJson(),
    'book': searchBook.toJson(),
    if (identityBookUrl != null && identityBookUrl!.isNotEmpty)
      'identityBookUrl': identityBookUrl,
  };

  static OnlineShelfItem? fromJson(Map<String, dynamic> json) {
    final s = json['source'];
    final b = json['book'];
    if (s is! Map || b is! Map) return null;
    return OnlineShelfItem(
      source: BookSource.fromJson(Map<String, dynamic>.from(s)),
      searchBook: SearchBook.fromJson(Map<String, dynamic>.from(b)),
      identityBookUrl: json['identityBookUrl']?.toString().trim(),
    );
  }
}

final onlineShelfProvider =
    NotifierProvider<OnlineShelfNotifier, List<OnlineShelfItem>>(
      OnlineShelfNotifier.new,
    );

class OnlineShelfNotifier extends Notifier<List<OnlineShelfItem>> {
  bool _shelfLoaded = false;
  Future<void>? _loadFuture;

  @override
  List<OnlineShelfItem> build() {
    _loadFuture = Future<void>.microtask(_load);
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
        // Candidate URL identifies the source record. It must not be replaced
        // with the identity URL used by the shelf row.
        bookUrl: c?.bookUrl ?? entry.book.bookUrl,
        origin: c?.origin ?? entry.book.origin ?? '',
        originName: c?.originName ?? entry.book.originName ?? '',
        kind: c?.kind ?? entry.book.kind,
        intro: c?.intro ?? entry.book.intro,
        coverUrl: c?.coverUrl ?? entry.book.coverUrl,
        latestChapterTitle:
            c?.latestChapterTitle ?? entry.book.latestChapterTitle,
      ),
      identityBookUrl: entry.book.bookUrl,
    );
  }

  Future<void> _load() async {
    try {
      await _loadContents();
    } finally {
      _shelfLoaded = true;
    }
  }

  Future<void> _loadContents() async {
    final repo = await ref.read(shelfRepositoryProvider.future);
    if (repo != null) {
      try {
        // Idempotent, so it is safe on every start: duplicate entries cannot
        // create duplicate books because the identity key is (name, author).
        final legacy = (await KvSettings.ready()).getString(legacyShelfKey);
        if (legacy != null && legacy.isNotEmpty) {
          await repo.migrateFromKv(legacy);
        }
        final entries = <ShelfEntry>[];
        for (final entry in await repo.load()) {
          if (bookIdentityError(
                name: entry.book.name,
                url: entry.book.bookUrl,
              ) ==
              null) {
            entries.add(entry);
          } else {
            await repo.remove(entry.book.bookUrl);
          }
        }
        if (entries.isNotEmpty) {
          state = [for (final e in entries) _toItem(e)];
          StartupMetrics.mark('shelf_available');
          return;
        }
      } catch (_) {
        // Fall through to the blob rather than showing an empty shelf.
      }
    }

    final p = await KvSettings.ready();
    final raw = p.getString(legacyShelfKey);
    if (raw == null || raw.isEmpty) {
      StartupMetrics.mark('shelf_available');
      return;
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final items = <OnlineShelfItem>[];
      for (final e in list) {
        if (e is Map) {
          final item = OnlineShelfItem.fromJson(Map<String, dynamic>.from(e));
          if (item != null &&
              bookIdentityError(
                    name: item.searchBook.name,
                    url: item.candidateBookUrl,
                  ) ==
                  null) {
            items.add(item);
          }
        }
      }
      if (items.isNotEmpty) state = items;
    } catch (_) {}
    StartupMetrics.mark('shelf_available');
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
    if (!_shelfLoaded) {
      final loading = _loadFuture;
      if (loading != null) {
        unawaited(loading.then((_) => add(source, searchBook)));
      }
      return;
    }
    if (!isUsableSearchBook(searchBook) ||
        bookIdentityError(name: searchBook.name, url: searchBook.bookUrl) !=
            null) {
      return;
    }
    final identity = _identityKey(searchBook.name, searchBook.author);
    final existingIndex = state.indexWhere(
      (e) => _identityKey(e.searchBook.name, e.searchBook.author) == identity,
    );
    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      // A different source URL is a valid candidate. Only suppress an exact
      // source candidate duplicate.
      if (existing.searchBook.bookUrl == searchBook.bookUrl &&
          existing.searchBook.origin == source.bookSourceUrl) {
        return;
      }
      final next = [...state];
      next[existingIndex] = OnlineShelfItem(
        source: source,
        searchBook: searchBook,
        identityBookUrl: existing.identityBookUrl ?? existing.bookUrl,
      );
      state = next;
    } else {
      state = [
        ...state,
        OnlineShelfItem(
          source: source,
          searchBook: searchBook,
          identityBookUrl: searchBook.bookUrl,
        ),
      ];
    }
    final queueKey = 'shelf.add.${source.bookSourceUrl}|${searchBook.bookUrl}';
    PersistQueue.instance.schedule(queueKey, () async {
      final repo = await ref.read(shelfRepositoryProvider.future);
      if (repo == null) {
        await _persistLegacy();
        return;
      }
      final identityUrl = await repo.addCandidate(source, searchBook);
      state = state.map((e) {
        if (e.searchBook.bookUrl == searchBook.bookUrl &&
            e.searchBook.origin == source.bookSourceUrl) {
          return OnlineShelfItem(
            source: e.source,
            searchBook: e.searchBook,
            identityBookUrl: identityUrl,
          );
        }
        return e;
      }).toList();
    });
  }

  /// Removes a shelf entry only when the exact source candidate has been
  /// confirmed unusable (for example, a successfully fetched empty catalog).
  void removeCandidate(String sourceUrl, String candidateBookUrl) {
    if (!_shelfLoaded) {
      final loading = _loadFuture;
      if (loading != null) {
        unawaited(
          loading.then(
            (_) => removeCandidate(sourceUrl, candidateBookUrl),
          ),
        );
      }
      return;
    }
    final matches = state
        .where(
          (item) =>
              item.source.bookSourceUrl == sourceUrl &&
              item.candidateBookUrl == candidateBookUrl,
        )
        .map((item) => item.bookUrl)
        .toSet();
    for (final bookUrl in matches) {
      remove(bookUrl);
    }
  }

  void replaceBook(String oldUrl, BookSource source, SearchBook searchBook) {
    final next = <OnlineShelfItem>[];
    var replaced = false;
    for (final e in state) {
      if (!replaced &&
          (e.bookUrl == oldUrl ||
              (_identityKey(e.searchBook.name, e.searchBook.author) ==
                  _identityKey(searchBook.name, searchBook.author)))) {
        next.add(
          OnlineShelfItem(
            source: source,
            searchBook: searchBook,
            identityBookUrl: e.identityBookUrl ?? e.bookUrl,
          ),
        );
        replaced = true;
      } else {
        next.add(e);
      }
    }
    if (!replaced) {
      next.add(
        OnlineShelfItem(
          source: source,
          searchBook: searchBook,
          identityBookUrl: oldUrl.isEmpty ? searchBook.bookUrl : oldUrl,
        ),
      );
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

  static String _identityKey(String name, String author) =>
      '${normalizeSearchText(name)}\u0000${normalizeSearchText(author)}';
}
