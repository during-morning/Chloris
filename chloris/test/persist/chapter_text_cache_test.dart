import 'dart:convert';

import 'package:chloris/features/book_detail/chapter_text_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chapter cache round-trips gzipped text', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = ChapterTextCache.instance;
    await cache.clear();
    await cache.put('origin', 'https://x/c1', '第一章正文' * 20);
    expect(cache.get('origin', 'https://x/c1'), contains('第一章正文'));
    expect(cache.chapterCount, 1);
    await cache.flush();
    await cache.reload();
    expect(cache.get('origin', 'https://x/c1'), contains('第一章正文'));
  });

  test('concurrent first reads share one disk initialization', () async {
    final cache = ChapterTextCache.instance;
    await cache.clear();
    SharedPreferences.setMockInitialValues({
      'chapterTextCacheV1': jsonEncode([
        {'k': 'origin|https://x/race', 't': '恢复正文'},
      ]),
    });
    final first = cache.reload();
    final second = cache.ensureLoaded();
    await Future.wait([first, second]);
    expect(cache.get('origin', 'https://x/race'), '恢复正文');
  });
}
