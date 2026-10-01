import 'dart:typed_data';

class StoredAudio {
  const StoredAudio(this.key, this.url, this.size);
  final String key, url;
  final int size;
  void release() {}
}

class AudioFileStore {
  Future<StoredAudio> importFile(String path, String extension) async =>
      throw UnsupportedError('文件存储不可用');
  Future<StoredAudio> importBytes(Uint8List bytes, String extension) async =>
      throw UnsupportedError('文件存储不可用');
  Future<StoredAudio> open(String key) async =>
      throw UnsupportedError('文件存储不可用');
  Future<int> partialSize(String key) async => 0;
  Future<void> write(
    String key,
    Stream<List<int>> bytes, {
    bool append = false,
    bool partial = false,
  }) async => throw UnsupportedError('文件存储不可用');
  Future<void> commit(String key) async => throw UnsupportedError('文件存储不可用');
  Future<Uint8List> prefix(String key, {int limit = 1024 * 1024}) async =>
      Uint8List(0);
  Future<Uint8List> tail(String key, {int limit = 1024 * 1024}) async =>
      Uint8List(0);
  Future<Uint8List?> companion(String path) async => null;
  Future<Uint8List> read(String key) async => Uint8List(0);
  Future<void> delete(String key) async {}
  Future<void> exportBundle(
    List<String> keys,
    Map<String, dynamic> metadata,
    String destination,
  ) async => throw UnsupportedError('文件存储不可用');
  Future<void> exportFile(String key, String destination) async =>
      throw UnsupportedError('文件存储不可用');
}
