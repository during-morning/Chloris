import 'dart:typed_data';

Future<Uint8List?> idbGet(String key) async => null;

Future<bool> idbPut(String key, Uint8List bytes) async => false;

Future<void> idbRemove(String key) async {}

Future<void> idbClearKeys(Iterable<String> keys) async {}

Future<List<String>> idbListKeys() async => const [];
