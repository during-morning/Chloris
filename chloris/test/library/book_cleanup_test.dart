import 'dart:io';

import 'package:chloris/features/book_detail/chapter_text_cache.dart';
import 'package:chloris/features/library/book_cleanup.dart';
import 'package:chloris/features/library/reading_progress_provider.dart';
import 'package:chloris/features/reader/bookmark_provider.dart';
import 'package:chloris/features/settings/read_record_provider.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drift resolves its database file through path_provider, which has no
/// implementation under `flutter test`. Replacing the platform instance is the
/// supported seam; a method-channel mock does not reach drift's lazy open.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = _FakePathProvider(
      Directory.systemTemp.createTempSync('chloris_test').path,
    );
    ChapterTextCache.instance.clear();
  });

  group('per-book removal primitives', () {
    test('reading progress can be removed for one book', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(readingProgressProvider.notifier);
      // The notifier loads asynchronously; give the microtask a turn.
      await Future<void>.delayed(Duration.zero);

      notifier.save(bookUrl: 'b1', chapterIndex: 3, chapterTitle: 'c3');
      notifier.save(bookUrl: 'b2', chapterIndex: 1);
      expect(container.read(readingProgressProvider), hasLength(2));

      await notifier.remove('b1');
      final left = container.read(readingProgressProvider);
      expect(left.containsKey('b1'), isFalse);
      expect(left.containsKey('b2'), isTrue);
    });

    test('removing an unknown book is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(readingProgressProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      notifier.save(bookUrl: 'b1', chapterIndex: 1);
      await notifier.remove('nope');
      expect(container.read(readingProgressProvider), hasLength(1));
    });

    test('bookmarks are removed by book identity, not timestamp', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(bookmarkListProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      notifier.addAll([
        Bookmark(
          time: 1,
          bookName: 'A',
          bookAuthor: 'x',
          chapterIndex: 0,
          chapterPos: 0,
          chapterName: 'c',
          bookText: '',
          content: 'a',
        ),
        Bookmark(
          time: 2,
          bookName: 'A',
          bookAuthor: 'x',
          chapterIndex: 1,
          chapterPos: 0,
          chapterName: 'c',
          bookText: '',
          content: 'b',
        ),
        Bookmark(
          time: 3,
          bookName: 'B',
          bookAuthor: 'y',
          chapterIndex: 0,
          chapterPos: 0,
          chapterName: 'c',
          bookText: '',
          content: 'c',
        ),
      ]);

      notifier.removeByBook('A', 'x');
      final left = container.read(bookmarkListProvider);
      expect(left, hasLength(1));
      expect(left.single.bookName, 'B');
    });

    test('the same title by a different author is left alone', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(bookmarkListProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      notifier.addAll([
        Bookmark(
          time: 1,
          bookName: '同名',
          bookAuthor: '甲',
          chapterIndex: 0,
          chapterPos: 0,
          chapterName: 'c',
          bookText: '',
          content: 'a',
        ),
        Bookmark(
          time: 2,
          bookName: '同名',
          bookAuthor: '乙',
          chapterIndex: 0,
          chapterPos: 0,
          chapterName: 'c',
          bookText: '',
          content: 'b',
        ),
      ]);

      notifier.removeByBook('同名', '甲');
      final left = container.read(bookmarkListProvider);
      expect(left, hasLength(1));
      expect(left.single.bookAuthor, '乙');
    });

    test('read records are removed by bookUrl', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(readRecordProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      notifier.add(bookName: 'A', chapterTitle: 'c1', bookUrl: 'u1');
      notifier.add(bookName: 'B', chapterTitle: 'c2', bookUrl: 'u2');
      notifier.removeByBook('u1');
      final left = container.read(readRecordProvider);
      expect(left, hasLength(1));
      expect(left.single.bookUrl, 'u2');
    });
  });

  group('chapter text cache', () {
    test('removes only the named chapters of the named source', () async {
      final cache = ChapterTextCache.instance;
      await cache.put('sourceA', 'ch1', 'text one');
      await cache.put('sourceA', 'ch2', 'text two');
      // Same chapter URL under a different source must survive.
      await cache.put('sourceB', 'ch1', 'other source');

      await cache.removeChapters('sourceA', ['ch1']);

      expect(cache.get('sourceA', 'ch1'), isNull);
      expect(cache.get('sourceA', 'ch2'), 'text two');
      expect(cache.get('sourceB', 'ch1'), 'other source');
    });
  });

  group('BookCleanup', () {
    test('clears progress, bookmarks and read history together', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final progress = container.read(readingProgressProvider.notifier);
      final bookmarks = container.read(bookmarkListProvider.notifier);
      final records = container.read(readRecordProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      progress.save(bookUrl: 'u1', chapterIndex: 5);
      bookmarks.add(
        Bookmark(
          time: 1,
          bookName: 'A',
          bookAuthor: 'auth',
          chapterIndex: 0,
          chapterPos: 0,
          chapterName: 'c',
          bookText: '',
          content: 'x',
        ),
      );
      records.add(bookName: 'A', chapterTitle: 'c', bookUrl: 'u1');

      await container.read(bookCleanupProvider).cleanBook(
            bookUrl: 'u1',
            name: 'A',
            author: 'auth',
            sourceUrl: 'sourceA',
          );

      expect(container.read(readingProgressProvider).containsKey('u1'), isFalse);
      expect(container.read(bookmarkListProvider), isEmpty);
      expect(container.read(readRecordProvider), isEmpty);
    });

    test('an empty bookUrl is ignored rather than clearing everything', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final progress = container.read(readingProgressProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      progress.save(bookUrl: 'u1', chapterIndex: 1);

      await container.read(bookCleanupProvider).cleanBook(
            bookUrl: '',
            name: '',
            author: '',
            sourceUrl: '',
          );

      expect(container.read(readingProgressProvider), hasLength(1));
    });
  });
}
