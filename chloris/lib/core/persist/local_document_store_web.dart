import 'dart:typed_data';

import 'blob_idb_web.dart';

Future<bool> write(String key, Uint8List bytes) =>
    idbPut('local-document/$key', bytes);

Future<Uint8List?> read(String key) => idbGet('local-document/$key');

Future<void> delete(String key) => idbRemove('local-document/$key');
