import 'dart:typed_data';

import 'package:chloris/core/persist/blob_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('BlobStore 按键读写，不合成一张大表', () async {
    SharedPreferences.setMockInitialValues({});
    final store = BlobStore.instance;
    await Future.wait([store.keys(), store.keys()]);
    await store.put('chapter/a', Uint8List.fromList([1, 2, 3]));
    final hit = await store.get('chapter/a');
    expect(hit, isNotNull);
    expect(hit!.toList(), [1, 2, 3]);
    await store.clearPrefix('chapter/');
    expect(await store.get('chapter/a'), isNull);
  });
}
