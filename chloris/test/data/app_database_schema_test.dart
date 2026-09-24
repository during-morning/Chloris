import 'package:chloris/data/database/app_database.dart'
    hide Bookmark, Cookie, ReadRecord, ReplaceRule, RssArticle, RssSource;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // An in-memory database exercises the real schema and the `beforeOpen`
    // pragma without needing path_provider.
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  /// The shelf is unique by (name, author), so the default name is derived from
  /// the url rather than being a constant that collides across inserts.
  Future<int> insertBook(String url, {String? name}) =>
      db.into(db.books).insert(
            BooksCompanion.insert(bookUrl: url, name: name ?? 'book-$url'),
          );

  Future<void> insertChapter(String bookUrl, String url, int index) =>
      db.into(db.bookChapters).insert(
        BookChaptersCompanion.insert(
          url: url,
          bookUrl: bookUrl,
          index: index,
        ),
      );

  group('schema', () {
    test('every table added in v4 exists', () async {
      // Touching each table proves it was created, not just declared.
      expect(await db.select(db.books).get(), isEmpty);
      expect(await db.select(db.bookChapters).get(), isEmpty);
      expect(await db.select(db.bookmarks).get(), isEmpty);
      expect(await db.select(db.readRecords).get(), isEmpty);
      expect(await db.select(db.bookGroups).get(), isEmpty);
      expect(await db.select(db.cookies).get(), isEmpty);
      expect(await db.select(db.cacheEntries).get(), isEmpty);
      expect(await db.select(db.rssSources).get(), isEmpty);
      expect(await db.select(db.rssArticles).get(), isEmpty);
      expect(await db.select(db.rssStars).get(), isEmpty);
      expect(await db.select(db.rssReadRecords).get(), isEmpty);
    });
  });

  group('chapters', () {
    test('deleting a book removes its chapters', () async {
      await insertBook('https://b.test/1');
      await insertChapter('https://b.test/1', 'https://b.test/1/c1', 0);
      await insertChapter('https://b.test/1', 'https://b.test/1/c2', 1);
      expect(await db.select(db.bookChapters).get(), hasLength(2));

      await (db.delete(db.books)
            ..where((t) => t.bookUrl.equals('https://b.test/1')))
          .go();

      // The cascade is only real because beforeOpen enables foreign keys.
      expect(await db.select(db.bookChapters).get(), isEmpty);
    });

    test('a chapter index is unique per book', () async {
      await insertBook('https://b.test/1');
      await insertChapter('https://b.test/1', 'https://b.test/1/c1', 0);

      await expectLater(
        insertChapter('https://b.test/1', 'https://b.test/1/other', 0),
        throwsA(isA<Exception>()),
      );
    });

    test('the same index is fine for a different book', () async {
      await insertBook('https://b.test/1');
      await insertBook('https://b.test/2');
      await insertChapter('https://b.test/1', 'https://b.test/1/c1', 0);
      await insertChapter('https://b.test/2', 'https://b.test/2/c1', 0);
      expect(await db.select(db.bookChapters).get(), hasLength(2));
    });

    test('chapters can be read back in order', () async {
      await insertBook('https://b.test/1');
      await insertChapter('https://b.test/1', 'u3', 2);
      await insertChapter('https://b.test/1', 'u1', 0);
      await insertChapter('https://b.test/1', 'u2', 1);

      final rows = await (db.select(db.bookChapters)
            ..where((t) => t.bookUrl.equals('https://b.test/1'))
            ..orderBy([(t) => OrderingTerm(expression: t.index)]))
          .get();
      expect(rows.map((r) => r.index).toList(), [0, 1, 2]);
    });
  });

  group('bookmarks', () {
    test('a bookmark round-trips and is keyed by time', () async {
      await db.into(db.bookmarks).insert(
            BookmarksCompanion.insert(
              time: const Value(1000),
              bookName: 'n',
              bookAuthor: 'a',
              chapterIndex: 3,
              chapterPos: 42,
              chapterName: 'c',
              bookText: '',
              content: 'text',
            ),
          );
      final rows = await db.select(db.bookmarks).get();
      expect(rows.single.time, 1000);
      expect(rows.single.chapterPos, 42);
    });
  });

  group('read records', () {
    test('the key is device plus book name', () async {
      await db.into(db.readRecords).insert(
            ReadRecordsCompanion.insert(
              deviceId: 'dev1',
              bookName: 'book',
              readTime: const Value(60),
            ),
          );
      // Same book on another device is a separate row, like Legado.
      await db.into(db.readRecords).insert(
            ReadRecordsCompanion.insert(deviceId: 'dev2', bookName: 'book'),
          );
      expect(await db.select(db.readRecords).get(), hasLength(2));

      await expectLater(
        db.into(db.readRecords).insert(
              ReadRecordsCompanion.insert(deviceId: 'dev1', bookName: 'book'),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('groups', () {
    test('built-in groups are addressable by their negative ids', () async {
      for (final (id, name) in const [
        (-1, '全部'),
        (-2, '本地'),
        (-3, '音频'),
        (-11, '更新失败'),
      ]) {
        await db.into(db.bookGroups).insert(
              BookGroupsCompanion.insert(groupId: Value(id), groupName: name),
            );
      }
      final rows = await db.select(db.bookGroups).get();
      expect(rows, hasLength(4));
      expect(rows.map((r) => r.groupId).toSet(), {-1, -2, -3, -11});
    });
  });

  group('cache', () {
    test('deadline 0 means never expires, matching Legado', () async {
      await db.into(db.cacheEntries).insert(
            CacheEntriesCompanion.insert(key: 'forever', value: const Value('v')),
          );
      await db.into(db.cacheEntries).insert(
            CacheEntriesCompanion.insert(
              key: 'soon',
              value: const Value('v'),
              deadline: const Value(1234),
            ),
          );
      final rows = await db.select(db.cacheEntries).get();
      expect(rows.firstWhere((r) => r.key == 'forever').deadline, 0);
      expect(rows.firstWhere((r) => r.key == 'soon').deadline, 1234);
    });
  });

  group('rss', () {
    test('an article key is origin + link + sort', () async {
      await db.into(db.rssArticles).insert(
            RssArticlesCompanion.insert(
              origin: 'https://feed.test',
              link: 'https://feed.test/1',
              sort: '科技',
              title: const Value('标题'),
            ),
          );
      // Same link under a different sort is a separate row.
      await db.into(db.rssArticles).insert(
            RssArticlesCompanion.insert(
              origin: 'https://feed.test',
              link: 'https://feed.test/1',
              sort: '资讯',
            ),
          );
      expect(await db.select(db.rssArticles).get(), hasLength(2));

      await expectLater(
        db.into(db.rssArticles).insert(
              RssArticlesCompanion.insert(
                origin: 'https://feed.test',
                link: 'https://feed.test/1',
                sort: '科技',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('read state and progress have a home now', () async {
      await db.into(db.rssArticles).insert(
            RssArticlesCompanion.insert(
              origin: 'o',
              link: 'l',
              sort: 's',
              read: const Value(true),
              durPos: const Value(99),
              group: const Value('分组B'),
            ),
          );
      final row = (await db.select(db.rssArticles).get()).single;
      expect(row.read, isTrue);
      expect(row.durPos, 99);
      expect(row.group, '分组B');
    });

    test('an rss source keeps the fields import used to drop', () async {
      await db.into(db.rssSources).insert(
            RssSourcesCompanion.insert(
              sourceUrl: 'https://feed.test/rss',
              sourceName: const Value('测试订阅'),
              header: const Value('{"User-Agent":"UA"}'),
              loginUi: const Value('[]'),
              jsLib: const Value('function x(){}'),
              contentWhitelist: const Value('p,img'),
              contentBlacklist: const Value('script'),
              cacheFirst: const Value(1),
              searchUrl: const Value('https://feed.test/search'),
            ),
          );
      final row = (await db.select(db.rssSources).get()).single;
      expect(row.header, contains('User-Agent'));
      expect(row.contentWhitelist, 'p,img');
      expect(row.cacheFirst, 1);
    });

    test('stars are keyed by origin and link', () async {
      await db.into(db.rssStars).insert(
            RssStarsCompanion.insert(origin: 'o', link: 'l'),
          );
      expect(await db.select(db.rssStars).get(), hasLength(1));
      await expectLater(
        db
            .into(db.rssStars)
            .insert(RssStarsCompanion.insert(origin: 'o', link: 'l')),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('cookies', () {
    test('url is the key, so one cookie per url', () async {
      await db.into(db.cookies).insert(
            CookiesCompanion.insert(url: 'a.test', cookie: 'k=v'),
          );
      await db.into(db.cookies).insert(
            CookiesCompanion.insert(url: 'b.test', cookie: 'k=v'),
          );
      expect(await db.select(db.cookies).get(), hasLength(2));
      await expectLater(
        db.into(db.cookies).insert(
              CookiesCompanion.insert(url: 'a.test', cookie: 'other'),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
