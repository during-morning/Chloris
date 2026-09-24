import 'package:chloris/data/database/app_database.dart'
    hide
        Book,
        BookSource,
        Cookie,
        ReadRecord,
        ReplaceRule,
        RssSource,
        SearchBook;
import 'package:chloris/data/database/book_queries.dart';
import 'package:chloris_engine/chloris_engine.dart' show BookType;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late BookQueries q;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    q = BookQueries(db);
  });

  tearDown(() async => db.close());

  /// The default name is derived from the url: the shelf is unique by
  /// (name, author) now, so two helpers calls must not collide by accident.
  Future<void> addBook(
    String url, {
    String? name,
    String author = '作者',
    int type = BookType.text,
    int group = 0,
  }) => db.into(db.books).insert(
        BooksCompanion.insert(
          bookUrl: url,
          name: name ?? '书-$url',
          author: Value(author),
          type: Value(type),
          group: Value(group),
        ),
      );

  Future<void> addSource(String url) => db.into(db.bookSources).insert(
        BookSourcesCompanion.insert(
          bookSourceUrl: url,
          bookSourceName: '源',
        ),
      );

  group('shelf identity, aligned with Legado', () {
    test('the same name and author cannot be shelved twice', () async {
      await addBook('u1', name: '三体', author: '刘慈欣');
      await expectLater(
        addBook('u2', name: '三体', author: '刘慈欣'),
        throwsA(isA<Exception>()),
      );
    });

    test('the same title by a different author is a different book', () async {
      await addBook('u1', name: '同名', author: '甲');
      await addBook('u2', name: '同名', author: '乙');
      expect(await db.select(db.books).get(), hasLength(2));
    });

    test('an authorless book still deduplicates', () async {
      // The column is NOT NULL '' precisely so this works: SQLite treats NULLs
      // as distinct, which would let the same book in twice.
      await addBook('u1', name: '无名', author: '');
      await expectLater(
        addBook('u2', name: '无名', author: ''),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('per-source candidates', () {
    test('one book can have several candidates', () async {
      await addSource('s1');
      await addSource('s2');
      await db.into(db.searchBooks).insert(
            SearchBooksCompanion.insert(
              bookUrl: 'c1',
              origin: 's1',
              name: const Value('三体'),
            ),
          );
      await db.into(db.searchBooks).insert(
            SearchBooksCompanion.insert(
              bookUrl: 'c2',
              origin: 's2',
              name: const Value('三体'),
            ),
          );
      expect(await db.select(db.searchBooks).get(), hasLength(2));
    });

    test('deleting a book source removes its candidates', () async {
      await addSource('s1');
      await db.into(db.searchBooks).insert(
            SearchBooksCompanion.insert(bookUrl: 'c1', origin: 's1'),
          );
      await (db.delete(db.bookSources)
            ..where((t) => t.bookSourceUrl.equals('s1')))
          .go();
      // Only real because beforeOpen enables foreign keys.
      expect(await db.select(db.searchBooks).get(), isEmpty);
    });

    test('a candidate cannot point at a missing source', () async {
      await expectLater(
        db.into(db.searchBooks).insert(
              SearchBooksCompanion.insert(bookUrl: 'c1', origin: 'nope'),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('group bit mask', () {
    test('a book can belong to several groups at once', () async {
      await addBook('u1', group: 1 | 4);
      await addBook('u2', group: 4);

      expect((await q.flowByUserGroup(1).get()).map((r) => r.bookUrl), ['u1']);
      expect(
        (await q.flowByUserGroup(4).get()).map((r) => r.bookUrl).toSet(),
        {'u1', 'u2'},
      );
      expect(await q.flowByUserGroup(2).get(), isEmpty);
    });

    test('a non-bit-mask group id is rejected rather than silently matching',
        () {
      // 3 is not a single bit, so it is not a Legado group id.
      expect(() => BookQueries.inGroup(3), throwsArgumentError);
      expect(() => BookQueries.inGroup(0), throwsArgumentError);
      expect(() => BookQueries.inGroup(-1), throwsArgumentError);
      expect(() => BookQueries.inGroup(4), returnsNormally);
    });
  });

  group('flowRoot now carries the group clause', () {
    test('books in a user group are excluded', () async {
      await addBook('ungrouped');
      await addBook('grouped', group: 2);
      // A user group (positive id) exists.
      await db.into(db.bookGroups).insert(
            BookGroupsCompanion.insert(
              groupId: const Value(2),
              groupName: '我的分组',
            ),
          );

      final rows = await q.flowRoot().get();
      expect(rows.map((r) => r.bookUrl), ['ungrouped']);
    });

    test('built-in negative groups do not exclude anything', () async {
      await addBook('u1');
      // Ids < 0 are virtual (all / local / audio / …), so the subquery that
      // sums positive ids must ignore them.
      for (final id in const [-1, -2, -3]) {
        await db.into(db.bookGroups).insert(
              BookGroupsCompanion.insert(
                groupId: Value(id),
                groupName: 'builtin$id',
              ),
            );
      }
      expect((await q.flowRoot().get()).map((r) => r.bookUrl), ['u1']);
    });

    test('the ungrouped variant ignores group membership', () async {
      await addBook('grouped', group: 2);
      await db.into(db.bookGroups).insert(
            BookGroupsCompanion.insert(
              groupId: const Value(2),
              groupName: 'g',
            ),
          );
      expect(await q.flowRoot().get(), isEmpty);
      expect(await q.flowRootUngrouped().get(), hasLength(1));
    });
  });
}
