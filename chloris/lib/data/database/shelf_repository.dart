import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart' as db;
import '../../core/persist/app_db.dart';
import '../../core/search/search_match.dart';

/// One shelved book and the per-source candidates that back it.
class ShelfEntry {
  const ShelfEntry({required this.book, required this.candidates});

  /// The identity row from `books` (deduplicated by name + author).
  final db.Book book;

  /// Rows from `searchBooks`. May be empty for a hand-added book.
  final List<db.SearchBook> candidates;

  String get bookUrl => book.bookUrl;

  /// The source this book is currently read from.
  ///
  /// Candidates carry only the source URL and name; the full source lives in
  /// `book_sources` and is resolved by the caller when it needs to scrape.
  BookSource? get chosenSource {
    for (final c in candidates) {
      if (c.origin == book.origin) return _asSource(c);
    }
    return candidates.isEmpty ? null : _asSource(candidates.first);
  }

  static BookSource _asSource(db.SearchBook c) =>
      BookSource(bookSourceUrl: c.origin, bookSourceName: c.originName);
}

/// The shelf, aligned with Legado.
///
/// `books` holds one row per book *identity* (name + author); `searchBooks`
/// holds one row per book URL per source. Keeping them apart is what lets the
/// shelf deduplicate without losing the other sources — the old single-blob
/// shape made that mistake unavoidable.
class ShelfRepository {
  const ShelfRepository(this._db);

  final db.AppDatabase _db;

  /// Identity key used to join a shelf row with its candidates.
  ///
  /// The join is by the normalized (name, author) identity, *not* by bookUrl:
  /// candidates of the same book deliberately carry different URLs — that is
  /// what makes them candidates for different sources. Joining on bookUrl
  /// would report a single candidate and hide the rest.
  static String _identity(String name, String author) =>
      '${normalizeSearchText(name)}\u0000${normalizeSearchText(author)}';

  Future<List<ShelfEntry>> load() async {
    await _backfillIdentityKeys();
    final books =
        await (_db.select(_db.books)..orderBy([
              (t) => OrderingTerm(expression: t.customOrder),
              (t) => OrderingTerm(
                expression: t.lastReadTime,
                mode: OrderingMode.desc,
              ),
            ]))
            .get();
    final identities = books.map((book) => book.identityKey).toSet();
    final candidates = identities.isEmpty
        ? const <db.SearchBook>[]
        : await (_db.select(
            _db.searchBooks,
          )..where((t) => t.identityKey.isIn(identities))).get();
    final byIdentity = <String, List<db.SearchBook>>{};
    for (final c in candidates) {
      byIdentity.putIfAbsent(_identity(c.name, c.author), () => []).add(c);
    }
    return [
      for (final b in books)
        ShelfEntry(
          book: b,
          candidates: byIdentity[_identity(b.name, b.author)] ?? const [],
        ),
    ];
  }

  /// Backfill the v8 normalized identity once. Subsequent shelf reads use the
  /// indexed identity key and only fetch candidates for books on this shelf.
  Future<void> _backfillIdentityKeys() async {
    final books = await (_db.select(
      _db.books,
    )..where((t) => t.identityKey.equals(''))).get();
    final candidates = await (_db.select(
      _db.searchBooks,
    )..where((t) => t.identityKey.equals(''))).get();
    if (books.isEmpty && candidates.isEmpty) return;
    await _db.transaction(() async {
      for (final book in books) {
        await (_db.update(_db.books)..where((t) => t.id.equals(book.id))).write(
          db.BooksCompanion(
            identityKey: Value(_identity(book.name, book.author)),
          ),
        );
      }
      for (final candidate in candidates) {
        await (_db.update(_db.searchBooks)..where(
              (t) =>
                  t.bookUrl.equals(candidate.bookUrl) &
                  t.origin.equals(candidate.origin),
            ))
            .write(
              db.SearchBooksCompanion(
                identityKey: Value(_identity(candidate.name, candidate.author)),
              ),
            );
      }
    });
  }

  /// Adds a candidate, shelving the book when its identity is new.
  ///
  /// Returns the bookUrl of the identity row: for a book already shelved from
  /// another source this is the *existing* row, which is the whole point of the
  /// alignment.
  Future<String> addCandidate(BookSource source, SearchBook book) async {
    // Source, candidate and identity must be committed together. Otherwise a
    // crash between the candidate insert and identity insert leaves an
    // unreferenced row that cannot be rendered by the shelf.
    return _db.transaction(() async {
      // The candidate has a foreign key into `book_sources`, so the source row
      // has to exist before the candidate can be written.
      await _ensureSource(source);

      await _db
          .into(_db.searchBooks)
          .insertOnConflictUpdate(
            db.SearchBooksCompanion.insert(
              bookUrl: book.bookUrl,
              identityKey: Value(_identity(book.name, book.author)),
              origin: source.bookSourceUrl,
              originName: Value(source.bookSourceName),
              name: Value(book.name),
              author: Value(book.author),
              kind: Value(book.kind),
              coverUrl: Value(book.coverUrl),
              intro: Value(book.intro),
              latestChapterTitle: Value(book.latestChapterTitle),
              tocUrl: Value(book.tocUrl),
              time: Value(DateTime.now().millisecondsSinceEpoch),
              originOrder: Value(book.originOrder),
              respondTime: Value(source.respondTime),
            ),
          );

      var existing = await _findIdentity(book.name, book.author);
      if (existing != null) {
        // Adding a candidate is also the user's source choice. Persist the
        // selected origin on the identity row so a restart does not silently
        // switch back to the source that created the book originally.
        await (_db.update(
          _db.books,
        )..where((t) => t.bookUrl.equals(existing!.bookUrl))).write(
          db.BooksCompanion(
            origin: Value(source.bookSourceUrl),
            originName: Value(source.bookSourceName),
            latestChapterTitle: Value(book.latestChapterTitle),
            lastUpdateTime: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
        return existing.bookUrl;
      }

      // INSERT OR IGNORE makes the identity creation safe if another queued
      // add wins the unique (name, author) race while this transaction is
      // waiting on SQLite's write lock.
      await _db
          .into(_db.books)
          .insert(
            db.BooksCompanion.insert(
              bookUrl: book.bookUrl,
              name: book.name,
              identityKey: Value(_identity(book.name, book.author)),
              author: Value(book.author),
              origin: Value(source.bookSourceUrl),
              originName: Value(source.bookSourceName),
              kind: Value(book.kind),
              coverUrl: Value(book.coverUrl),
              intro: Value(book.intro),
              latestChapterTitle: Value(book.latestChapterTitle),
              lastUpdateTime: Value(DateTime.now().millisecondsSinceEpoch),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      existing = await _findIdentity(book.name, book.author);
      return existing?.bookUrl ?? book.bookUrl;
    });
  }

  Future<db.Book?> _findIdentity(String name, String author) async {
    final exact =
        await (_db.select(_db.books)
              ..where((t) => t.name.equals(name) & t.author.equals(author))
              ..limit(1))
            .getSingleOrNull();
    if (exact != null) return exact;
    return (_db.select(_db.books)
          ..where((t) => t.identityKey.equals(_identity(name, author)))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> _ensureSource(BookSource source) async {
    if (source.bookSourceUrl.isEmpty) return;
    final hit =
        await (_db.select(_db.bookSources)
              ..where((t) => t.bookSourceUrl.equals(source.bookSourceUrl))
              ..limit(1))
            .getSingleOrNull();
    if (hit != null) return;
    await _db
        .into(_db.bookSources)
        .insertOnConflictUpdate(
          db.BookSourcesCompanion.insert(
            bookSourceUrl: source.bookSourceUrl,
            bookSourceName: source.bookSourceName,
          ),
        );
  }

  /// Removes a book and every candidate that belongs to its identity.
  ///
  /// Candidates are keyed by book URL and one identity can have several (that
  /// is the point of the split), so deleting only the shelf row's own URL would
  /// leave the other sources' candidates orphaned.
  Future<void> remove(String bookUrl) async {
    await _backfillIdentityKeys();
    final book = await (_db.select(
      _db.books,
    )..where((t) => t.bookUrl.equals(bookUrl))).getSingleOrNull();
    if (book == null) return;

    await _db.transaction(() async {
      final identity = _identity(book.name, book.author);
      await (_db.delete(
        _db.searchBooks,
      )..where((t) => t.identityKey.equals(identity))).go();
      await (_db.delete(
        _db.books,
      )..where((t) => t.bookUrl.equals(bookUrl))).go();
    });
  }

  /// Moves a book to the front of the manual ordering.
  Future<void> top(String bookUrl) async {
    final query = _db.selectOnly(_db.books)
      ..addColumns([_db.books.customOrder.min()]);
    final row = await query.getSingle();
    final minOrder = row.read(_db.books.customOrder.min()) ?? 0;
    await (_db.update(_db.books)..where((t) => t.bookUrl.equals(bookUrl)))
        .write(db.BooksCompanion(customOrder: Value(minOrder - 1)));
  }

  /// Imports the legacy `onlineShelf` preference.
  ///
  /// Idempotent: every entry goes through [addCandidate], which upserts the
  /// candidate and only creates an identity row when name + author is new, so
  /// running it twice cannot duplicate a book.
  ///
  /// Returns how many preference entries were imported.
  Future<int> migrateFromKv(String? rawJson) async {
    if (rawJson == null || rawJson.isEmpty) return 0;
    List<dynamic> items;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return 0;
      items = decoded;
    } catch (_) {
      // A corrupt preference must not stop the app from opening. The blob is
      // left untouched so it can still be recovered by hand.
      return 0;
    }

    var seen = 0;
    for (final raw in items) {
      if (raw is! Map) continue;
      final source = raw['source'];
      final book = raw['book'];
      if (source is! Map || book is! Map) continue;
      try {
        await addCandidate(
          BookSource.fromJson(Map<String, dynamic>.from(source)),
          SearchBook.fromJson(Map<String, dynamic>.from(book)),
        );
        seen++;
      } catch (_) {
        // One bad entry must not abort the rest of the shelf.
        continue;
      }
    }
    return seen;
  }
}

/// Lazily opens the app database and hands out the shelf repository.
///
/// Features must depend on this provider rather than constructing
/// [ShelfRepository] directly, keeping the data layer behind one port.
final shelfRepositoryProvider = FutureProvider<ShelfRepository?>((ref) async {
  final db = await AppDb.open();
  return db == null ? null : ShelfRepository(db);
});
