import 'dart:convert';

import 'package:chloris/data/database/app_database.dart' as db;
import 'package:chloris/data/database/shelf_repository.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds one `onlineShelf` preference entry, the shape the blob used.
Map<String, dynamic> shelfEntry({
  required String sourceUrl,
  required String sourceName,
  required String bookUrl,
  required String name,
  String author = '作者',
}) => {
  'source': BookSource(
    bookSourceUrl: sourceUrl,
    bookSourceName: sourceName,
  ).toJson(),
  'book': SearchBook(
    name: name,
    author: author,
    bookUrl: bookUrl,
    origin: sourceUrl,
    originName: sourceName,
  ).toJson(),
};

void main() {
  late db.AppDatabase database;
  late ShelfRepository repo;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    repo = ShelfRepository(database);
  });

  tearDown(() async => database.close());

  Future<List<db.Book>> books() => database.select(database.books).get();
  Future<List<db.SearchBook>> candidates() =>
      database.select(database.searchBooks).get();

  group('migration keeps every source', () {
    test('three sources of one book become one shelf row and three candidates',
        () async {
      // This is the whole point of the alignment: before it, the shelf could
      // only be "one row per source", so deduplicating would have meant losing
      // the other sources.
      final legacy = jsonEncode([
        shelfEntry(
          sourceUrl: 's1',
          sourceName: '源一',
          bookUrl: 'u1',
          name: '三体',
        ),
        shelfEntry(
          sourceUrl: 's2',
          sourceName: '源二',
          bookUrl: 'u2',
          name: '三体',
        ),
        shelfEntry(
          sourceUrl: 's3',
          sourceName: '源三',
          bookUrl: 'u3',
          name: '三体',
        ),
      ]);

      final seen = await repo.migrateFromKv(legacy);

      expect(seen, 3);
      expect(await books(), hasLength(1), reason: 'one identity row');
      expect(await candidates(), hasLength(3), reason: 'no source dropped');

      final entry = (await repo.load()).single;
      expect(entry.book.name, '三体');
      expect(entry.candidates.map((c) => c.origin).toSet(), {
        's1',
        's2',
        's3',
      });
    });

    test('different books stay separate', () async {
      final legacy = jsonEncode([
        shelfEntry(sourceUrl: 's1', sourceName: 'a', bookUrl: 'u1', name: 'A'),
        shelfEntry(sourceUrl: 's1', sourceName: 'a', bookUrl: 'u2', name: 'B'),
      ]);
      await repo.migrateFromKv(legacy);
      expect(await books(), hasLength(2));
      expect(await candidates(), hasLength(2));
    });

    test('the same title by a different author is two books', () async {
      final legacy = jsonEncode([
        shelfEntry(
          sourceUrl: 's1',
          sourceName: 'a',
          bookUrl: 'u1',
          name: '同名',
          author: '甲',
        ),
        shelfEntry(
          sourceUrl: 's1',
          sourceName: 'a',
          bookUrl: 'u2',
          name: '同名',
          author: '乙',
        ),
      ]);
      await repo.migrateFromKv(legacy);
      expect(await books(), hasLength(2));
    });
  });

  group('migration is idempotent and safe', () {
    test('running it three times changes nothing', () async {
      final legacy = jsonEncode([
        shelfEntry(sourceUrl: 's1', sourceName: 'a', bookUrl: 'u1', name: 'A'),
        shelfEntry(sourceUrl: 's2', sourceName: 'b', bookUrl: 'u2', name: 'A'),
      ]);
      await repo.migrateFromKv(legacy);
      await repo.migrateFromKv(legacy);
      await repo.migrateFromKv(legacy);

      expect(await books(), hasLength(1));
      expect(await candidates(), hasLength(2));
    });

    test('an empty or absent blob is a no-op', () async {
      expect(await repo.migrateFromKv(null), 0);
      expect(await repo.migrateFromKv(''), 0);
      expect(await books(), isEmpty);
    });

    test('a corrupt blob is reported as zero, not a crash', () async {
      // A damaged preference must not stop the app from opening, and the blob
      // is left untouched so it can still be recovered by hand.
      expect(await repo.migrateFromKv('{not json'), 0);
      expect(await repo.migrateFromKv('"a string"'), 0);
      expect(await repo.migrateFromKv('[1, 2, 3]'), 0);
      expect(await books(), isEmpty);
    });

    test('one bad entry does not abort the rest', () async {
      final legacy = jsonEncode([
        {'source': 'not a map', 'book': {}},
        shelfEntry(sourceUrl: 's1', sourceName: 'a', bookUrl: 'u1', name: 'A'),
        {'nonsense': true},
      ]);
      final seen = await repo.migrateFromKv(legacy);
      expect(seen, 1);
      expect(await books(), hasLength(1));
    });
  });

  group('repository operations', () {
    test('adding a second source keeps the first candidate', () async {
      await repo.addCandidate(
        BookSource(bookSourceUrl: 's1', bookSourceName: '一'),
        SearchBook(name: 'A', author: 'a', bookUrl: 'u1', origin: 's1'),
      );
      await repo.addCandidate(
        BookSource(bookSourceUrl: 's2', bookSourceName: '二'),
        SearchBook(name: 'A', author: 'a', bookUrl: 'u2', origin: 's2'),
      );

      expect(await books(), hasLength(1));
      expect((await candidates()).map((c) => c.origin).toSet(), {'s1', 's2'});
    });

    test('adding an existing book returns the original shelf row', () async {
      final first = await repo.addCandidate(
        BookSource(bookSourceUrl: 's1', bookSourceName: '一'),
        SearchBook(name: 'A', author: 'a', bookUrl: 'u1', origin: 's1'),
      );
      final second = await repo.addCandidate(
        BookSource(bookSourceUrl: 's2', bookSourceName: '二'),
        SearchBook(name: 'A', author: 'a', bookUrl: 'u2', origin: 's2'),
      );
      expect(second, first, reason: 'same identity resolves to the same row');
    });

    test('removing a book removes every candidate of its identity', () async {
      await repo.addCandidate(
        BookSource(bookSourceUrl: 's1', bookSourceName: '一'),
        SearchBook(name: 'A', author: 'a', bookUrl: 'u1', origin: 's1'),
      );
      await repo.addCandidate(
        BookSource(bookSourceUrl: 's2', bookSourceName: '二'),
        SearchBook(name: 'A', author: 'a', bookUrl: 'u2', origin: 's2'),
      );

      await repo.remove('u1');

      expect(await books(), isEmpty);
      // Deleting only u1's own candidate would have orphaned u2 here.
      expect(await candidates(), isEmpty);
    });

    test('removing an unknown book is a no-op', () async {
      await repo.remove('nope');
      expect(await books(), isEmpty);
    });

    test('top assigns a decreasing order', () async {
      await repo.addCandidate(
        BookSource(bookSourceUrl: 's1', bookSourceName: '一'),
        SearchBook(name: 'A', author: 'a', bookUrl: 'u1', origin: 's1'),
      );
      await repo.addCandidate(
        BookSource(bookSourceUrl: 's1', bookSourceName: '一'),
        SearchBook(name: 'B', author: 'b', bookUrl: 'u2', origin: 's1'),
      );

      await repo.top('u2');
      final loaded = await repo.load();
      expect(loaded.first.bookUrl, 'u2');
    });

    test('candidates need their source row to exist first', () async {
      await repo.addCandidate(
        BookSource(bookSourceUrl: 's1', bookSourceName: '一'),
        SearchBook(name: 'A', author: 'a', bookUrl: 'u1', origin: 's1'),
      );
      // The repository creates the source so the foreign key can be satisfied:
      // the legacy blob carried sources that were never imported separately.
      final sources = await database.select(database.bookSources).get();
      expect(sources.map((s) => s.bookSourceUrl), contains('s1'));
    });
  });

  group('round trip', () {
    test('blob -> tables -> load preserves identity and all candidates',
        () async {
      final legacy = jsonEncode([
        shelfEntry(sourceUrl: 's1', sourceName: '一', bookUrl: 'u1', name: '书'),
        shelfEntry(sourceUrl: 's2', sourceName: '二', bookUrl: 'u2', name: '书'),
      ]);

      await repo.migrateFromKv(legacy);
      final first = await repo.load();

      // Re-running the migration must be indistinguishable from the first run.
      await repo.migrateFromKv(legacy);
      final second = await repo.load();

      expect(second.length, first.length);
      expect(second.first.bookUrl, first.first.bookUrl);
      expect(
        second.first.candidates.map((c) => c.origin).toSet(),
        first.first.candidates.map((c) => c.origin).toSet(),
      );
    });
  });
}
