import 'dart:typed_data';

import 'local_document_store_stub.dart'
    if (dart.library.io) 'local_document_store_io.dart'
    if (dart.library.html) 'local_document_store_web.dart'
    as backend;

/// Durable storage for imported/downloaded books. Unlike the evictable cache,
/// this store has no per-value size limit or automatic eviction.
class LocalDocumentStore {
  const LocalDocumentStore._();
  static const instance = LocalDocumentStore._();

  Future<bool> write(String key, Uint8List bytes) async {
    try {
      return await backend.write(key, bytes);
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List?> read(String key) async {
    try {
      return await backend.read(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      await backend.delete(key);
    } catch (_) {}
  }
}
