import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chloris/application/online/online_book_port.dart';
import 'package:chloris/application/online/online_reading_use_cases.dart';

void main() {
  test('音频章节再次打开从缓存恢复歌词与资源地址', () async {
    final port = _FakeOnlineBookPort()..content = 'https://cdn.example/a.mp3';
    final store = _FakeContentStore();
    final loader = LoadOnlineChapterContentUseCase(port, store);
    final source = BookSource(bookSourceUrl: 'https://source.example');
    final book = Book(
      bookUrl: 'https://source.example/book',
      type: BookType.audio,
    );
    final chapter = BookChapter(
      url: 'https://source.example/chapter',
      variable: '{"lyric":"[00:01]歌词","token":"x"}',
      resourceUrl: 'https://cdn.example/a.mp3',
    );
    await loader(source: source, book: book, chapter: chapter);
    final reopened = BookChapter(url: chapter.url);
    expect(
      await loader(source: source, book: book, chapter: reopened),
      port.content,
    );
    expect(reopened.getVariable('lyric'), '[00:01]歌词');
    expect(reopened.getVariable('token'), 'x');
    expect(reopened.resourceUrl, chapter.resourceUrl);
    expect(port.contentCalls, 1);
  });
  test(
    'search use case classifies transport failures at the search stage',
    () async {
      final port = _FakeOnlineBookPort()
        ..searchError = StateError('socket closed');
      final useCase = SearchOnlineBooksUseCase(port);
      final source = BookSource(bookSourceUrl: 'https://source.example');

      await expectLater(
        useCase(source, '测试'),
        throwsA(
          isA<DomainError>()
              .having((e) => e.stage, 'stage', DomainErrorStage.search)
              .having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
    },
  );

  test(
    'catalog use case filters empty and duplicate chapter identities',
    () async {
      final port = _FakeOnlineBookPort()
        ..chapters = [
          BookChapter(url: 'a', title: '第一章'),
          BookChapter(url: 'a', title: '重复'),
          BookChapter(url: '', title: '无链接'),
          BookChapter(url: 'b', title: ''),
          BookChapter(url: 'b', title: '第二章'),
        ];
      final store = _FakeCatalogStore();
      final useCase = LoadOnlineCatalogUseCase(port, store);
      final source = BookSource(bookSourceUrl: 'https://source.example');
      final book = Book(
        bookUrl: 'https://source.example/book',
        origin: source.bookSourceUrl,
      );

      final chapters = await useCase(source: source, seed: book, maxPages: 1);

      expect(chapters.map((e) => e.url), ['a', 'b']);
      expect(store.values, isEmpty, reason: 'short catalogs are not persisted');
    },
  );

  test('catalog use case drops short-list chrome before cache', () async {
    final port = _FakeOnlineBookPort()
      ..chapters = [
        BookChapter(url: 'https://ex.com/', title: '首页'),
        BookChapter(url: 'https://ex.com/toc', title: '目录'),
        BookChapter(url: 'https://ex.com/c/1', title: '第一章'),
        BookChapter(url: 'https://ex.com/c/2', title: '第二章'),
      ];
    final store = _FakeCatalogStore();
    final useCase = LoadOnlineCatalogUseCase(port, store);
    final source = BookSource(bookSourceUrl: 'https://source.example');
    final book = Book(
      bookUrl: 'https://source.example/book',
      origin: source.bookSourceUrl,
    );

    final chapters = await useCase(source: source, seed: book, maxPages: 1);
    expect(chapters.map((e) => e.title), ['第一章', '第二章']);
  });

  test(
    'background TOC expand skips sources without a next-page rule',
    () async {
      final port = _FakeOnlineBookPort()
        ..chapters = [
          BookChapter(url: 'a', title: '第一章'),
          BookChapter(url: 'b', title: '第二章'),
        ];
      final useCase = LoadOnlineCatalogUseCase(port, _FakeCatalogStore());
      final source = BookSource(bookSourceUrl: 'https://source.example');
      final book = Book(
        bookUrl: 'https://source.example/book',
        origin: source.bookSourceUrl,
      );

      await useCase.expandInBackground(
        source: source,
        seed: book,
        currentLength: 2,
      );
      expect(port.catalogCalls, 0);

      source.ruleToc = TocRule(nextTocUrl: 'class.next@href');
      await useCase.expandInBackground(
        source: source,
        seed: book,
        currentLength: 2,
      );
      expect(port.catalogCalls, 1);
    },
  );

  test(
    'chapter content use case reads cache and rejects empty content',
    () async {
      final port = _FakeOnlineBookPort()..content = '正文';
      final store = _FakeContentStore();
      final useCase = LoadOnlineChapterContentUseCase(port, store);
      final source = BookSource(bookSourceUrl: 'https://source.example');
      final book = Book(
        bookUrl: 'https://source.example/book',
        origin: source.bookSourceUrl,
      );
      final chapter = BookChapter(
        url: 'https://source.example/chapter',
        title: '第一章',
      );

      expect(await useCase(source: source, book: book, chapter: chapter), '正文');
      expect(port.contentCalls, 1);
      expect(await useCase(source: source, book: book, chapter: chapter), '正文');
      expect(port.contentCalls, 1);

      store.values.clear();
      port.content = '   ';
      await expectLater(
        useCase(source: source, book: book, chapter: chapter, useCache: false),
        throwsA(
          isA<DomainError>().having(
            (e) => e.stage,
            'stage',
            DomainErrorStage.content,
          ),
        ),
      );
    },
  );
}

class _FakeOnlineBookPort implements OnlineBookPort {
  Object? searchError;
  List<BookChapter> chapters = const [];
  String content = '';
  var contentCalls = 0;
  var catalogCalls = 0;

  @override
  Future<List<SearchBook>> search(
    BookSource source,
    String query, {
    int page = 1,
    bool Function(String name, String author, String? kind)? filter,
  }) async {
    if (searchError != null) throw searchError!;
    return const [];
  }

  @override
  Future<List<SearchBook>> explore(
    BookSource source,
    String url, {
    int page = 1,
  }) async => const [];

  @override
  Future<Book> loadBookInfo(BookSource source, Book book) async => book;

  @override
  Future<List<BookChapter>> loadChapterList(
    BookSource source,
    Book book, {
    int maxPages = 40,
    void Function(List<BookChapter> chapters)? onPartial,
  }) async {
    catalogCalls++;
    onPartial?.call(chapters);
    return chapters;
  }

  @override
  Future<String> loadChapterContent(
    BookSource source,
    Book book,
    BookChapter chapter, {
    String? nextChapterUrl,
    int maxHops = 32,
  }) async {
    contentCalls++;
    return content;
  }

  @override
  void cancelSession(String sessionId) {}
}

class _FakeCatalogStore implements ChapterCatalogStore {
  final Map<String, List<BookChapter>> values = {};

  @override
  Future<void> ensureLoaded() async {}

  @override
  Future<void> hydrate(String bookUrl) async {}

  @override
  List<BookChapter>? take(String bookUrl) => values[bookUrl];

  @override
  List<BookChapter>? peek(String bookUrl) => values[bookUrl];

  @override
  Future<void> put(String bookUrl, List<BookChapter> chapters) async {
    values[bookUrl] = chapters;
  }

  @override
  Future<void> remove(String bookUrl) async => values.remove(bookUrl);

  @override
  void skipNext(String bookUrl) {}
}

class _FakeContentStore implements ChapterContentStore {
  final Map<String, String> values = {};

  String _key(String source, String chapter) => '$source|$chapter';

  @override
  Future<void> ensureLoaded() async {}

  @override
  String? get(String sourceId, String chapterUrl) =>
      values[_key(sourceId, chapterUrl)];

  @override
  Future<void> put(String sourceId, String chapterUrl, String content) async {
    values[_key(sourceId, chapterUrl)] = content;
  }

  @override
  Future<void> remove(String sourceId, String chapterUrl) async {
    values.remove(_key(sourceId, chapterUrl));
  }
}
