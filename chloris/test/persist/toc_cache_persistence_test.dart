import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris/features/book_detail/toc_cache.dart';
import 'package:chloris/core/persist/blob_store.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('TocCache hydrates directories persisted in BlobStore', () async {
    SharedPreferences.setMockInitialValues({});
    const bookUrl = 'https://cache.example/book';
    final chapters = [
      for (var i = 0; i < 5; i++)
        BookChapter(url: '$bookUrl/$i', title: '第${i + 1}章', index: i),
    ];
    await BlobStore.instance.put(
      'toc/$bookUrl',
      Uint8List.fromList(
        utf8.encode(jsonEncode(chapters.map((c) => c.toJson()).toList())),
      ),
    );

    await TocCache.instance.ensureLoaded();
    await TocCache.instance.hydrate(bookUrl);
    expect(TocCache.instance.peek(bookUrl), hasLength(5));
    expect(TocCache.instance.peek(bookUrl)!.first.title, '第1章');

    await TocCache.instance.remove(bookUrl);
  });
}
