import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'music_export.dart';
import 'package:crypto/crypto.dart';
import 'package:web/web.dart' as web;

@JS('chlorisMusicStorage')
external JSObject get _storage;
Future<JSAny?> _call(String method, List<JSAny?> args) async =>
    await (_storage.callMethodVarArgs(method.toJS, args) as JSPromise<JSAny?>)
        .toDart;

class StoredAudio {
  const StoredAudio(this.key, this.url, this.size);
  final String key, url;
  final int size;
  void release() => web.URL.revokeObjectURL(url);
}

class AudioFileStore {
  Future<StoredAudio> importFile(String path, String extension) async =>
      throw UnsupportedError('请通过浏览器文件选择器导入音频');
  Future<StoredAudio> importBytes(Uint8List bytes, String extension) async {
    final key = '${sha256.convert(bytes)}.$extension';
    await write(key, Stream.value(bytes));
    return open(key);
  }

  Future<StoredAudio> open(String key) async {
    final value = await _call('open', [key.toJS]) as JSObject;
    return StoredAudio(
      key,
      (value.getProperty('url'.toJS) as JSString).toDart,
      (value.getProperty('size'.toJS) as JSNumber).toDartInt,
    );
  }

  Future<int> partialSize(String key) async =>
      (await _call('size', ['$key.part'.toJS]) as JSNumber).toDartInt;
  Future<void> write(
    String key,
    Stream<List<int>> bytes, {
    bool append = false,
    bool partial = false,
  }) async {
    final target = partial ? '$key.part' : key;
    await _call('begin', [target.toJS, append.toJS]);
    try {
      await for (final data in bytes) {
        await _call('append', [target.toJS, Uint8List.fromList(data).toJS]);
      }
      await _call('end', [target.toJS]);
    } catch (_) {
      await _call('end', [target.toJS]);
      rethrow;
    }
  }

  Future<void> commit(String key) async {
    await _call('commit', [key.toJS]);
  }

  Future<Uint8List> prefix(String key, {int limit = 1024 * 1024}) async =>
      (await _call('bytes', [key.toJS, limit.toJS]) as JSUint8Array).toDart;
  Future<Uint8List> tail(String key, {int limit = 1024 * 1024}) async =>
      (await _call('tail', [key.toJS, limit.toJS]) as JSUint8Array).toDart;
  Future<Uint8List?> companion(String path) async => null;
  Future<Uint8List> read(String key) => prefix(key, limit: 0);
  Future<void> delete(String key) async {
    for (final name in [key, '$key.part']) {
      await _call('remove', [name.toJS]);
    }
  }

  Future<void> exportBundle(
    List<String> keys,
    Map<String, dynamic> metadata,
    String destination,
  ) async {
    final entries = <String, Uint8List>{};
    for (final key in keys) {
      entries[key] = await read(key);
    }
    entries['manifest.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode(metadata)),
    );
    final bytes = await compute(_zip, entries);
    await saveMusicBytes(bytes, destination);
  }

  Future<void> exportFile(String key, String destination) async {
    await _call('export', [key.toJS, destination.toJS]);
  }
}

Uint8List _zip(Map<String, Uint8List> entries) {
  final archive = Archive();
  for (final e in entries.entries) {
    archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive, level: 0));
}
