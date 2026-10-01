import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredAudio {
  const StoredAudio(this.key, this.url, this.size);
  final String key, url;
  final int size;
  void release() {}
}

class AudioFileStore {
  AudioFileStore({this.directory});
  final Directory? directory;
  Future<Directory> get root async =>
      directory ??
      Directory(p.join((await getApplicationSupportDirectory()).path, 'music'));
  Future<File> file(String key, {bool partial = false}) async {
    if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(key)) {
      throw const FormatException('音频文件标识无效');
    }
    final r = await root;
    await r.create(recursive: true);
    return File(p.join(r.path, partial ? '$key.part' : key));
  }

  Future<StoredAudio> importFile(String path, String extension) async {
    final r = (await root).path;
    return Isolate.run(() async {
      final source = File(path);
      final hash = (await sha256.bind(source.openRead()).first).toString();
      final key =
          '$hash.${extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
      final dir = Directory(r);
      await dir.create(recursive: true);
      final target = File(p.join(r, key));
      if (!await target.exists()) {
        final temp = File(
          '${target.path}.${DateTime.now().microsecondsSinceEpoch}.import',
        );
        await source.copy(temp.path);
        await temp.rename(target.path);
      }
      return StoredAudio(
        key,
        Uri.file(target.path).toString(),
        await target.length(),
      );
    });
  }

  Future<StoredAudio> importBytes(Uint8List bytes, String extension) async {
    final key = '${sha256.convert(bytes)}.$extension';
    await write(key, Stream.value(bytes));
    return open(key);
  }

  Future<int> partialSize(String key) async {
    final f = await file(key, partial: true);
    return await f.exists() ? await f.length() : 0;
  }

  Future<void> write(
    String key,
    Stream<List<int>> bytes, {
    bool append = false,
    bool partial = false,
  }) async {
    final f = await file(key, partial: partial);
    final sink = f.openWrite(mode: append ? FileMode.append : FileMode.write);
    try {
      await sink.addStream(bytes);
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<void> commit(String key) async {
    final src = await file(key, partial: true);
    final dest = await file(key);
    // File.rename replaces an existing file atomically on supported platforms.
    await src.rename(dest.path);
  }

  Future<StoredAudio> open(String key) async {
    final f = await file(key);
    if (!await f.exists()) throw const FileSystemException('音频文件不存在');
    return StoredAudio(key, Uri.file(f.path).toString(), await f.length());
  }

  Future<Uint8List> prefix(String key, {int limit = 1024 * 1024}) async {
    final f = await file(key);
    final handle = await f.open();
    try {
      return await handle.read(limit);
    } finally {
      await handle.close();
    }
  }

  Future<Uint8List> tail(String key, {int limit = 1024 * 1024}) async {
    final f = await file(key),
        length = await f.length(),
        handle = await f.open();
    try {
      await handle.setPosition((length - limit).clamp(0, length));
      return await handle.read(limit);
    } finally {
      await handle.close();
    }
  }

  Future<Uint8List?> companion(String path) async {
    for (final ext in ['lrc', 'vtt', 'srt', 'txt']) {
      final f = File(p.setExtension(path, '.$ext'));
      if (await f.exists() && await f.length() <= 2 * 1024 * 1024) {
        return f.readAsBytes();
      }
    }
    return null;
  }

  Future<Uint8List> read(String key) async => (await file(key)).readAsBytes();
  Future<void> delete(String key) async {
    for (final part in [false, true]) {
      final f = await file(key, partial: part);
      if (await f.exists()) await f.delete();
    }
  }

  Future<void> exportBundle(
    List<String> keys,
    Map<String, dynamic> metadata,
    String destination,
  ) async {
    final paths = <String, String>{};
    for (final key in keys) {
      paths[key] = (await file(key)).path;
    }
    await Isolate.run(() async {
      final temp = '$destination.part';
      final encoder = ZipFileEncoder()..create(temp, level: 0);
      try {
        for (final entry in paths.entries) {
          await encoder.addFile(File(entry.value), entry.key, 0);
        }
        encoder.addArchiveFile(
          ArchiveFile.string('manifest.json', jsonEncode(metadata)),
        );
      } finally {
        await encoder.close();
      }
      await File(temp).rename(destination);
    });
  }

  Future<void> exportFile(String key, String destination) async {
    await (await file(key)).copy(destination);
  }
}
