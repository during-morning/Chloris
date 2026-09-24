import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chloris/application/download/download_recovery.dart';
import 'package:chloris/application/download/download_use_cases.dart';
import 'package:chloris/application/online/online_book_port.dart';
import 'package:chloris/application/online/online_reading_use_cases.dart';
import 'package:chloris/features/book_detail/cache_provider.dart';

void main() {
  test('resolver rebuilds fetch closures from persisted metadata', () async {
    final port = _RecordingContentPort();
    final content = LoadOnlineChapterContentUseCase(
      port,
      _MemoryContentStore(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://source.example',
      bookSourceName: '示例源',
    );
    const jobMetadata = BatchDownloadMetadata(
      sourceId: 'https://source.example',
      bookUrl: 'https://source.example/book',
      tocUrl: 'https://source.example/toc',
      chapters: [
        BatchDownloadChapterRef(
          index: 1,
          title: '第一章',
          url: 'https://source.example/c/1',
          baseUrl: 'https://source.example',
        ),
        BatchDownloadChapterRef(
          index: 2,
          title: '第二章',
          url: 'https://source.example/c/2',
          baseUrl: 'https://source.example',
        ),
      ],
    );

    final handler = resolvePersistedDownloadJob(
      metadata: jobMetadata,
      bookName: '仙逆',
      sources: [source],
      content: content,
    );
    expect(handler, isNotNull);
    expect(handler!.hostOf!(2), 'source.example');
    await handler.fetchChapter(2);
    expect(port.urls, ['https://source.example/c/2']);
    expect(port.nextUrls, [isNull]);
  });

  test('resolver returns null when source or chapter urls are missing', () {
    final content = LoadOnlineChapterContentUseCase(
      _RecordingContentPort(),
      _MemoryContentStore(),
    );
    expect(
      resolvePersistedDownloadJob(
        metadata: null,
        bookName: '无元数据',
        sources: const [],
        content: content,
      ),
      isNull,
    );

    const unknownSource = BatchDownloadMetadata(
      sourceId: 'https://missing.example',
      bookUrl: 'https://missing.example/book',
      chapters: [
        BatchDownloadChapterRef(index: 0, url: 'https://missing.example/c/1'),
      ],
    );
    expect(
      resolvePersistedDownloadJob(
        metadata: unknownSource,
        bookName: '未知源',
        sources: [BookSource(bookSourceUrl: 'https://other.example')],
        content: content,
      ),
      isNull,
    );
  });

  test('resolver passes the next chapter URL for content pagination', () async {
    final port = _RecordingContentPort();
    final content = LoadOnlineChapterContentUseCase(
      port,
      _MemoryContentStore(),
    );
    final source = BookSource(bookSourceUrl: 'https://source.example');
    const jobMetadata = BatchDownloadMetadata(
      sourceId: 'https://source.example',
      bookUrl: 'https://source.example/book',
      chapters: [
        BatchDownloadChapterRef(
          index: 0,
          title: '一',
          url: 'https://source.example/c/0',
        ),
        BatchDownloadChapterRef(
          index: 1,
          title: '二',
          url: 'https://source.example/c/1',
        ),
      ],
    );
    final handler = resolvePersistedDownloadJob(
      metadata: jobMetadata,
      bookName: '续页书',
      sources: [source],
      content: content,
    )!;
    await handler.fetchChapter(0);
    expect(port.nextUrls.single, 'https://source.example/c/1');
  });
}

class _RecordingContentPort implements OnlineBookPort {
  final urls = <String>[];
  final nextUrls = <String?>[];

  @override
  Future<List<SearchBook>> search(
    BookSource source,
    String query, {
    int page = 1,
    bool Function(String name, String author, String? kind)? filter,
  }) async => const [];

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
  }) async => const [];

  @override
  Future<String> loadChapterContent(
    BookSource source,
    Book book,
    BookChapter chapter, {
    String? nextChapterUrl,
    int maxHops = 32,
  }) async {
    urls.add(chapter.url);
    nextUrls.add(nextChapterUrl);
    return '正文 ${chapter.url}';
  }

  @override
  void cancelSession(String sessionId) {}
}

class _MemoryContentStore implements ChapterContentStore {
  final values = <String, String>{};

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
