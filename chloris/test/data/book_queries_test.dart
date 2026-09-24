import 'package:chloris/data/database/app_database.dart'
    hide Book, BookSource, Cookie, ReadRecord, ReplaceRule, RssSource;
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

  /// The shelf is unique by (name, author), so the default name is derived from
  /// the url rather than being a constant that collides across inserts.
  Future<void> addBook(String url, int type, {String? name}) =>
      db.into(db.books).insert(
            BooksCompanion.insert(
              bookUrl: url,
              name: name ?? 'book-$url',
              type: Value(type),
            ),
          );

  group('type bit-mask queries', () {
    setUp(() async {
      await addBook('local', BookType.local | BookType.text, name: '本地');
      await addBook('online', BookType.text, name: '在线');
      await addBook('audio', BookType.audio, name: '听书');
      await addBook('video', BookType.video, name: '视频');
      await addBook('image', BookType.image, name: '漫画');
      await addBook(
        'failed',
        BookType.text | BookType.updateError,
        name: '更新失败',
      );
      await addBook('hidden', BookType.text | BookType.notShelf, name: '不在架');
    });

    test('flowLocal selects only the local flag', () async {
      final rows = await q.flowLocal().get();
      expect(rows.map((r) => r.bookUrl), ['local']);
    });

    test('flowOnline is the complement of the local flag', () async {
      final rows = await q.flowOnline().get();
      expect(rows.map((r) => r.bookUrl).toSet(), {
        'online',
        'audio',
        'video',
        'image',
        'failed',
        'hidden',
      });
    });

    test('media flags are independent of each other', () async {
      expect((await q.flowAudio().get()).map((r) => r.bookUrl), ['audio']);
      expect((await q.flowVideo().get()).map((r) => r.bookUrl), ['video']);
      expect((await q.flowImage().get()).map((r) => r.bookUrl), ['image']);
    });

    test('flowUpdateError finds refresh failures', () async {
      final rows = await q.flowUpdateError().get();
      expect(rows.map((r) => r.bookUrl), ['failed']);
    });

    test('flowRoot is scraped text books that are on the shelf', () async {
      final rows = await q.flowRoot().get();
      // 'local' is excluded by the local flag, 'audio'/'video'/'image' by the
      // text flag, 'hidden' by notShelf. 'failed' is still a shelf book.
      expect(rows.map((r) => r.bookUrl).toSet(), {'online', 'failed'});
    });

    test('flowShelf excludes not-on-shelf books only', () async {
      final rows = await q.flowShelf().get();
      expect(rows.map((r) => r.bookUrl), isNot(contains('hidden')));
      expect(rows, hasLength(6));
    });

    test('a book with several flags answers every matching query', () async {
      await addBook(
        'multi',
        BookType.local | BookType.text | BookType.updateError,
      );
      expect(
        (await q.flowLocal().get()).map((r) => r.bookUrl),
        contains('multi'),
      );
      expect(
        (await q.flowUpdateError().get()).map((r) => r.bookUrl),
        contains('multi'),
      );
      // Still excluded from flowRoot because of the local flag.
      expect(
        (await q.flowRoot().get()).map((r) => r.bookUrl),
        isNot(contains('multi')),
      );
    });
  });

  group('the predicate stays in SQL', () {
    test('limit applies after the bit-mask filter, not before', () async {
      for (var i = 0; i < 10; i++) {
        await addBook('l$i', BookType.local | BookType.text);
      }
      for (var i = 0; i < 40; i++) {
        await addBook('o$i', BookType.text);
      }

      // If the filter ran in Dart after a `limit(3)` fetch it would return
      // online books too. SQL-side filtering must yield three local books.
      final rows = await (q.flowLocal()..limit(3)).get();
      expect(rows, hasLength(3));
      expect(rows.every((r) => BookType.has(r.type, BookType.local)), isTrue);
    });

    test('the row count reflects the filter', () async {
      await addBook('a', BookType.local | BookType.text);
      await addBook('b', BookType.text);
      expect(await q.flowLocal().get(), hasLength(1));
    });
  });
}
