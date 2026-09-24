import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chloris/features/book_detail/toc_cache.dart';
import 'package:chloris/core/search/search_schedule.dart';

void main() {
  test('SearchHitCache 并发首次加载共享同一个 Future', () async {
    SharedPreferences.setMockInitialValues({});

    final first = SearchHitCache.ensureLoaded();
    final second = SearchHitCache.ensureLoaded();

    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
  });

  test('SourceLatencyStore 并发首次加载共享同一个 Future', () async {
    SharedPreferences.setMockInitialValues({});

    final first = SourceLatencyStore.ensureLoaded();
    final second = SourceLatencyStore.ensureLoaded();

    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
  });

  test('TocCache 并发首次加载共享同一个 Future', () async {
    SharedPreferences.setMockInitialValues({});

    final first = TocCache.instance.ensureLoaded();
    final second = TocCache.instance.ensureLoaded();

    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
  });
}
