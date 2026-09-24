import 'dart:convert';
import 'dart:html';
import 'dart:typed_data';

const _dbName = 'chloris_blobs';
const _storeName = 'blobs';

dynamic _db;

Future<dynamic> _open() async {
  if (_db != null) return _db;
  final factory = window.indexedDB;
  if (factory == null) return null;
  try {
    _db = await factory.open(
      _dbName,
      version: 1,
      onUpgradeNeeded: (e) {
        final db = (e.target as dynamic).result;
        final names = db.objectStoreNames;
        var has = false;
        try {
          has = names.contains(_storeName);
        } catch (_) {
          try {
            has = (names as List).contains(_storeName);
          } catch (_) {}
        }
        if (!has) db.createObjectStore(_storeName);
      },
    );
    return _db;
  } catch (_) {
    _db = null;
    return null;
  }
}

Future<Uint8List?> idbGet(String key) async {
  final db = await _open();
  if (db == null) return null;
  try {
    final tx = db.transaction(_storeName, 'readonly');
    final store = tx.objectStore(_storeName);
    final v = await store.getObject(key);
    if (v is String && v.isNotEmpty) {
      return Uint8List.fromList(base64Decode(v));
    }
    if (v is ByteBuffer) return v.asUint8List();
    if (v is Uint8List) return v;
    return null;
  } catch (_) {
    return null;
  }
}

Future<bool> idbPut(String key, Uint8List bytes) async {
  final db = await _open();
  if (db == null) return false;
  try {
    final tx = db.transaction(_storeName, 'readwrite');
    final store = tx.objectStore(_storeName);
    await store.put(base64Encode(bytes), key);
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> idbRemove(String key) async {
  final db = await _open();
  if (db == null) return;
  try {
    final tx = db.transaction(_storeName, 'readwrite');
    final store = tx.objectStore(_storeName);
    await store.delete(key);
  } catch (_) {}
}

Future<void> idbClearKeys(Iterable<String> keys) async {
  for (final k in keys) {
    await idbRemove(k);
  }
}

Future<List<String>> idbListKeys() async {
  final db = await _open();
  if (db == null) return const [];
  try {
    final tx = db.transaction(_storeName, 'readonly');
    final store = tx.objectStore(_storeName);
    final out = <String>[];
    await for (final cursor in store.openCursor(autoAdvance: true)) {
      final k = cursor.key;
      if (k is String) out.add(k);
    }
    return out;
  } catch (_) {
    return const [];
  }
}
