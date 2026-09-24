import 'dart:typed_data';

/// 非 IO 平台（Web）的空文件后端：Web 端大值由 IndexedDB 分支承担，
/// 本后端永远返回不可用，BlobStore 据此跳过文件分流。
class BlobFileBackend {
  BlobFileBackend._();
  static final BlobFileBackend instance = BlobFileBackend._();

  Future<bool> write(String rel, Uint8List bytes) async => false;

  Future<Uint8List?> read(String rel) async => null;

  Future<void> delete(String rel) async {}
}
