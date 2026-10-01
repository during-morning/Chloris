import '../../features/media/music_schema.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// 书籍（对应 legado `Book`）——**书架**，按身份去重。
///
/// 与 Legado 对齐后的语义：
/// - `UNIQUE(name, author)`：同一本书在书架上只有一行，`origin` 指向选定源；
///   各源候选放在 [SearchBooks]，所以去重不会丢候选。
/// - `group` 是**位掩码**（Legado 的 `Long`），不是单个分组 id。
@TableIndex(name: 'books_last_read', columns: {#lastReadTime})
@TableIndex(name: 'books_group', columns: {#group})
@TableIndex(name: 'books_identity_key', columns: {#identityKey})
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookUrl => text().unique()();
  TextColumn get name => text()();
  TextColumn get identityKey => text().withDefault(const Constant(''))();
  // NOT NULL 才能参与去重：SQLite 把 NULL 视为互不相等，可空的 author 会让
  // 同一本书进来两次。
  TextColumn get author => text().withDefault(const Constant(''))();
  TextColumn get intro => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get origin => text().nullable()();
  TextColumn get originName => text().nullable()();
  TextColumn get kind => text().nullable()();
  IntColumn get durChapterIndex => integer().withDefault(const Constant(0))();
  TextColumn get durChapterTitle => text().nullable()();
  IntColumn get durChapterPos => integer().withDefault(const Constant(0))();
  IntColumn get durChapterPosEnd => integer().withDefault(const Constant(0))();
  TextColumn get latestChapterTitle => text().nullable()();
  IntColumn get totalChapterNum => integer().withDefault(const Constant(0))();
  IntColumn get type => integer().withDefault(const Constant(0))();

  /// Legado `Book.group`：用户分组 id 的位或，0 表示未分组。
  IntColumn get group => integer().withDefault(const Constant(0))();
  IntColumn get customOrder => integer().withDefault(const Constant(0))();
  IntColumn get lastReadTime => integer().withDefault(const Constant(0))();
  IntColumn get lastUpdateTime => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {name, author},
  ];
}

/// 各书源搜到的候选（对应 legado `searchBooks`）。
///
/// Legado 的书架（`books`）按身份去重，一本书在每个来源下的候选存这里，换源
/// 时从这里挑。Chloris 之前把两者混在 KV 的 `onlineShelf` 里，语义上更接近本表
/// 而不是 `books`。
@TableIndex(name: 'search_books_origin', columns: {#origin})
@TableIndex(name: 'search_books_book_url', columns: {#bookUrl})
@TableIndex(name: 'search_books_identity_key', columns: {#identityKey})
class SearchBooks extends Table {
  TextColumn get bookUrl => text()();
  TextColumn get identityKey => text().withDefault(const Constant(''))();
  TextColumn get origin => text().customConstraint(
    'NOT NULL REFERENCES book_sources (book_source_url) ON DELETE CASCADE',
  )();
  TextColumn get originName => text().withDefault(const Constant(''))();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get author => text().withDefault(const Constant(''))();
  IntColumn get type => integer().withDefault(const Constant(0))();
  TextColumn get kind => text().nullable()();
  TextColumn get coverUrl => text().nullable()();
  TextColumn get intro => text().nullable()();
  TextColumn get wordCount => text().nullable()();
  TextColumn get latestChapterTitle => text().nullable()();
  TextColumn get tocUrl => text().withDefault(const Constant(''))();
  IntColumn get time => integer().withDefault(const Constant(0))();
  TextColumn get variable => text().nullable()();
  IntColumn get originOrder => integer().withDefault(const Constant(0))();
  TextColumn get chapterWordCountText => text().nullable()();
  IntColumn get chapterWordCount => integer().withDefault(const Constant(-1))();
  IntColumn get respondTime => integer().withDefault(const Constant(-1))();

  @override
  /// A URL is only unique within one source. Different sources commonly use
  /// different URLs for the same title, and the same source can legitimately
  /// expose aliases. Keeping `origin` in the key prevents one candidate from
  /// overwriting another during an upsert.
  Set<Column> get primaryKey => {bookUrl, origin};
}

/// 书源（对应 legado `BookSource`，规则以大 JSON 文本存储，由引擎解析）。
class BookSources extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookSourceUrl => text().unique()();
  TextColumn get bookSourceName => text()();
  TextColumn get bookSourceGroup => text().nullable()();
  IntColumn get bookSourceType => integer().withDefault(const Constant(0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get enabledExplore =>
      boolean().withDefault(const Constant(true))();
  IntColumn get customOrder => integer().withDefault(const Constant(0))();
  IntColumn get lastUpdateTime => integer().withDefault(const Constant(0))();
  IntColumn get respondTime => integer().withDefault(const Constant(180000))();
  IntColumn get weight => integer().withDefault(const Constant(0))();
  TextColumn get raw => text().nullable()();
}

/// 净化替换规则（对应 legado `ReplaceRule`，13 列）。
///
/// 这张表此前**从未被写入**：净化规则只活在 KV 的 `replaceRules` JSON 里，
/// 表是空的。现在写入路径双写，表才名副其实，也才可能做作用域查询。
class ReplaceRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get groupName => text().nullable()();
  TextColumn get pattern => text()();
  TextColumn get replacement => text()();
  TextColumn get scope => text().nullable()();
  BoolColumn get scopeTitle => boolean().withDefault(const Constant(false))();
  BoolColumn get scopeContent => boolean().withDefault(const Constant(true))();
  TextColumn get excludeScope => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get isRegex => boolean().withDefault(const Constant(true))();
  IntColumn get timeoutMillisecond =>
      integer().withDefault(const Constant(3000))();
  IntColumn get orderValue => integer().withDefault(const Constant(0))();
}

/// 章节（对应 legado `chapters`）。
///
/// `UNIQUE(bookUrl, index)` 与 `FK → Books ON DELETE CASCADE` 都按 Legado 声明。
/// 此前章节只活在 blob 缓存里，没有约束也没有级联，删书后必然留下孤儿。
@TableIndex(
  name: 'book_chapters_book_index',
  columns: {#bookUrl, #index},
  unique: true,
)
class BookChapters extends Table {
  TextColumn get url => text()();
  // Declared via an explicit constraint rather than `references()`: the
  // generator warns "should be a simple class name" for the latter and emits no
  // foreign key at all, which silently produced a table with no cascade.
  TextColumn get bookUrl => text().customConstraint(
    'NOT NULL REFERENCES books (book_url) ON DELETE CASCADE',
  )();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get index => integer()();
  TextColumn get baseUrl => text().withDefault(const Constant(''))();
  BoolColumn get isVolume => boolean().withDefault(const Constant(false))();
  BoolColumn get isVip => boolean().withDefault(const Constant(false))();
  BoolColumn get isPay => boolean().withDefault(const Constant(false))();
  TextColumn get tag => text().nullable()();
  TextColumn get wordCount => text().nullable()();
  IntColumn get start => integer().nullable()();
  IntColumn get end => integer().nullable()();
  TextColumn get startFragmentId => text().nullable()();
  TextColumn get endFragmentId => text().nullable()();
  TextColumn get variable => text().nullable()();
  TextColumn get imgUrl => text().nullable()();
  TextColumn get resourceUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {url, bookUrl};
}

/// 书签（对应 legado `bookmarks`，主键是时间戳）。
class Bookmarks extends Table {
  IntColumn get time => integer()();
  TextColumn get bookName => text()();
  TextColumn get bookAuthor => text()();
  IntColumn get chapterIndex => integer()();
  IntColumn get chapterPos => integer()();
  TextColumn get chapterName => text()();
  TextColumn get bookText => text()();
  TextColumn get content => text()();

  @override
  Set<Column> get primaryKey => {time};
}

/// 阅读记录（对应 legado `readRecord`，主键 `(deviceId, bookName)`）。
class ReadRecords extends Table {
  TextColumn get deviceId => text()();
  TextColumn get bookName => text()();
  IntColumn get readTime => integer().withDefault(const Constant(0))();
  IntColumn get lastRead => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {deviceId, bookName};
}

/// 书籍分组（对应 legado `bookGroups`）。负 id 是内置虚拟分组
/// （-1 全部 / -2 本地 / -3 音频 / -4 网络未分组 / -5 本地未分组 / -6 视频 /
/// -11 更新失败），与 `Books.group` 的位掩码配合使用。
class BookGroups extends Table {
  IntColumn get groupId => integer()();
  TextColumn get groupName => text()();
  TextColumn get cover => text().nullable()();
  IntColumn get order => integer().withDefault(const Constant(0))();
  BoolColumn get enableRefresh => boolean().withDefault(const Constant(true))();
  BoolColumn get show => boolean().withDefault(const Constant(true))();
  IntColumn get bookSort => integer().withDefault(const Constant(-1))();
  BoolColumn get onlyUpdateRead =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {groupId};
}

/// Cookie（对应 legado `cookies`，按 url 唯一）。
class Cookies extends Table {
  TextColumn get url => text()();
  TextColumn get cookie => text()();

  @override
  Set<Column> get primaryKey => {url};
}

/// 键值缓存（对应 legado `caches`）。`deadline == 0` 表示永不过期。
class CacheEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  IntColumn get deadline => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {key};
}

/// 订阅源（对应 legado `rssSources`，字段与 `RssSource` 模型一一对应）。
class RssSources extends Table {
  TextColumn get sourceUrl => text()();
  TextColumn get sourceName => text().withDefault(const Constant(''))();
  TextColumn get sourceIcon => text().withDefault(const Constant(''))();
  TextColumn get sourceGroup => text().nullable()();
  TextColumn get sourceComment => text().nullable()();
  TextColumn get variableComment => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get enabledCookieJar =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get enableJs => boolean().withDefault(const Constant(false))();
  BoolColumn get singleUrl => boolean().withDefault(const Constant(true))();
  BoolColumn get loadWithBaseUrl =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get shouldOverrideUrlLoading => boolean().nullable()();
  IntColumn get articleStyle => integer().withDefault(const Constant(0))();
  IntColumn get customOrder => integer().withDefault(const Constant(0))();
  IntColumn get lastUpdateTime => integer().withDefault(const Constant(0))();
  IntColumn get type => integer().withDefault(const Constant(0))();
  IntColumn get showWebLog => integer().withDefault(const Constant(0))();
  IntColumn get preload => integer().withDefault(const Constant(0))();
  IntColumn get cacheFirst => integer().withDefault(const Constant(0))();
  TextColumn get jsLib => text().nullable()();
  TextColumn get concurrentRate => text().nullable()();
  TextColumn get header => text().nullable()();
  TextColumn get loginUrl => text().nullable()();
  TextColumn get loginUi => text().nullable()();
  TextColumn get loginCheckJs => text().nullable()();
  TextColumn get coverDecodeJs => text().nullable()();
  TextColumn get sortUrl => text().nullable()();
  TextColumn get ruleArticles => text().nullable()();
  TextColumn get ruleNextPage => text().nullable()();
  TextColumn get ruleTitle => text().nullable()();
  TextColumn get rulePubDate => text().nullable()();
  TextColumn get ruleDescription => text().nullable()();
  TextColumn get ruleImage => text().nullable()();
  TextColumn get ruleLink => text().nullable()();
  TextColumn get ruleContent => text().nullable()();
  TextColumn get contentWhitelist => text().nullable()();
  TextColumn get contentBlacklist => text().nullable()();
  TextColumn get style => text().nullable()();
  TextColumn get injectJs => text().nullable()();
  TextColumn get preloadJs => text().nullable()();
  TextColumn get startHtml => text().nullable()();
  TextColumn get startStyle => text().nullable()();
  TextColumn get startJs => text().nullable()();
  TextColumn get searchUrl => text().nullable()();

  @override
  Set<Column> get primaryKey => {sourceUrl};
}

/// 订阅文章（对应 legado `rssArticles`，主键 `(origin, link, sort)`）。
class RssArticles extends Table {
  TextColumn get origin => text()();
  TextColumn get link => text()();
  TextColumn get sort => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get order => integer().withDefault(const Constant(0))();
  TextColumn get pubDate => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get content => text().nullable()();
  TextColumn get image => text().nullable()();
  TextColumn get group => text().withDefault(const Constant('默认分组'))();
  BoolColumn get read => boolean().withDefault(const Constant(false))();
  TextColumn get variable => text().nullable()();
  IntColumn get type => integer().withDefault(const Constant(0))();
  IntColumn get durPos => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {origin, link, sort};
}

/// 订阅收藏（对应 legado `rssStars`，主键 `(origin, link)`）。
class RssStars extends Table {
  TextColumn get origin => text()();
  TextColumn get link => text()();
  TextColumn get sort => text().withDefault(const Constant(''))();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get starTime => integer().withDefault(const Constant(0))();
  TextColumn get pubDate => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get content => text().nullable()();
  TextColumn get image => text().nullable()();
  TextColumn get group => text().withDefault(const Constant('默认分组'))();
  TextColumn get variable => text().nullable()();
  IntColumn get type => integer().withDefault(const Constant(0))();
  IntColumn get durPos => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {origin, link};
}

/// 订阅已读记录（对应 legado `rssReadRecords`）。
class RssReadRecords extends Table {
  TextColumn get record => text()();
  TextColumn get origin => text().withDefault(const Constant(''))();
  TextColumn get sort => text().withDefault(const Constant(''))();
  TextColumn get title => text().nullable()();
  IntColumn get readTime => integer().nullable()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();
  TextColumn get image => text().nullable()();
  IntColumn get type => integer().withDefault(const Constant(0))();
  IntColumn get durPos => integer().withDefault(const Constant(0))();
  TextColumn get pubDate => text().nullable()();

  @override
  Set<Column> get primaryKey => {record};
}

/// Local shelf descriptors are indexed metadata only. Original documents and
/// chapter bodies live in the durable document store, outside Blob eviction.
@TableIndex(name: 'local_book_order', columns: {#customOrder})
class LocalBookDescriptors extends Table {
  TextColumn get bookUrl => text()();
  TextColumn get metadata => text()();
  IntColumn get customOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {bookUrl};
}

/// Persistent size/access index for expendable binary cache entries.
@TableIndex(name: 'blob_entries_access', columns: {#lastAccess})
class BlobEntries extends Table {
  TextColumn get key => text()();
  IntColumn get size => integer().withDefault(const Constant(0))();
  IntColumn get lastAccess => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Books,
    SearchBooks,
    BookSources,
    ReplaceRules,
    BookChapters,
    Bookmarks,
    ReadRecords,
    BookGroups,
    Cookies,
    CacheEntries,
    RssSources,
    RssArticles,
    RssStars,
    RssReadRecords,
    LocalBookDescriptors,
    BlobEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.connect()
    : super(
        driftDatabase(
          name: 'chloris',
          // On the web, drift needs the sqlite3 wasm module and the drift
          // worker to open the database. Both assets are served from `web/`.
          // This parameter is ignored on native platforms (mobile/desktop).
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await createMusicSchema(this);
    },
    // SQLite ignores foreign keys unless they are switched on per connection,
    // so the chapter cascade would be decorative without this.
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      // Add idempotent music indexes to databases already on version 9.
      await createMusicSchema(this);
    },
    onUpgrade: (m, from, to) async {
      await createMusicSchema(this);
      // Version 2 only recorded the boundary. Version 3 adds the four
      // ReplaceRule columns the engine model always had but the table never
      // stored. Version 4 adds the tables that previously had no home: chapters,
      // bookmarks, read records, groups, cookies, the key/value cache and the
      // RSS set.
      //
      // Only additions happen here. `Books` deliberately keeps its current
      // shape: giving it Legado's UNIQUE(name, author) first requires deciding
      // whether the shelf is deduplicated by identity or keeps one entry per
      // source, and that decision changes data rather than structure.
      if (from < 3) {
        await m.addColumn(replaceRules, replaceRules.scope);
        await m.addColumn(replaceRules, replaceRules.excludeScope);
        await m.addColumn(replaceRules, replaceRules.isRegex);
        await m.addColumn(replaceRules, replaceRules.timeoutMillisecond);
      }
      if (from < 4) {
        await m.createTable(bookChapters);
        await m.createTable(bookmarks);
        await m.createTable(readRecords);
        await m.createTable(bookGroups);
        await m.createTable(cookies);
        await m.createTable(cacheEntries);
        await m.createTable(rssSources);
        await m.createTable(rssArticles);
        await m.createTable(rssStars);
        await m.createTable(rssReadRecords);
      }
      if (from < 5) {
        // Align the shelf with Legado: one row per book identity, candidates in
        // a separate table, and `group` becomes a bit mask.
        if (from >= 4) {
          await m.renameColumn(books, 'group_id', books.group);
        }
        // The unique key has to exist before the rebuild so the new table is
        // created with it. Clear duplicates first, otherwise the rebuild fails
        // and the database cannot be opened at all.
        //
        // Dropping duplicate mirror rows is safe at this point: the real shelf
        // lives in the `onlineShelf` preference, and this table only ever held
        // a progress mirror. Nothing a user can see is lost.
        await customStatement('''
          DELETE FROM books WHERE id NOT IN (
            SELECT MIN(id) FROM books GROUP BY name, COALESCE(author, '')
          )
        ''');
        await m.alterTable(
          TableMigration(
            books,
            columnTransformer: {
              // A nullable author cannot participate in a unique key, because
              // SQLite treats NULLs as distinct.
              books.author: const CustomExpression<String>(
                "COALESCE(author, '')",
              ),
              books.group: const CustomExpression<int>('0'),
            },
            newColumns: [books.group],
          ),
        );
        await m.createTable(searchBooks);
      }
      if (from < 6) {
        // 纯增量：只为已存在的 `books` 表补两个查询索引，不改动表结构，也不
        // 动列。幂等由 `from < 6` 守卫保证——每段升级只跑一次，不会重复建索引。
        await m.createIndex(booksLastRead);
        await m.createIndex(booksGroup);
      }
      if (from < 7) {
        // SearchBooks used to be keyed only by book_url. Rebuild it with the
        // source URL in the key so candidates from different sources can
        // coexist. Existing rows have unique book_url values under the old
        // schema, therefore the copy is lossless; the new secondary index
        // keeps direct URL lookups efficient for legacy call sites.
        await m.alterTable(TableMigration(searchBooks));
      }
      if (from < 8) {
        await m.addColumn(books, books.identityKey);
        await m.addColumn(searchBooks, searchBooks.identityKey);
        await m.createIndex(booksIdentityKey);
        await m.createIndex(searchBooksIdentityKey);
        await m.createTable(localBookDescriptors);
        await m.createTable(blobEntries);
        await m.createIndex(localBookOrder);
        await m.createIndex(blobEntriesAccess);
      }
    },
  );
}
