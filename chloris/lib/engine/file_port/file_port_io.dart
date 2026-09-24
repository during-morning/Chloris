import 'dart:io';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Platforms with a file system get the confined implementation.
FilePort createFilePort() => AppFilePort();

/// File access for rule scripts, confined to a directory the app owns.
///
/// Legado validates rule file paths against the cache directory's canonical
/// prefix. Without that check a rule could read or overwrite anything the
/// process can reach, so every path here is normalised and confined before any
/// I/O happens.
class AppFilePort implements FilePort {
  AppFilePort();

  Directory? _root;

  @override
  bool get isSupported => true;

  Future<Directory> _ensureRoot() async {
    final existing = _root;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'rule_files'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return _root = dir;
  }

  @override
  Future<String> downloadDirectory() async => (await _ensureRoot()).path;

  @override
  Future<String> resolve(String name) async {
    final root = await _ensureRoot();
    final target = p.normalize(p.join(root.path, name));
    _assertInside(root, target);
    return target;
  }

  void _assertInside(Directory root, String target) {
    final rootPath = p.normalize(root.absolute.path);
    final normalized = p.normalize(target);
    // `isWithin` is false for the root itself, which is a legitimate target.
    if (normalized == rootPath || p.isWithin(rootPath, normalized)) return;
    throw DomainError(
      code: 'file_path_denied',
      stage: DomainErrorStage.request,
      message: '文件路径越界: $target',
      recoverable: false,
      retryable: false,
      suggestedAction: '规则只能访问应用自己的缓存目录',
    );
  }

  Future<File> _fileFor(String path) async {
    final root = await _ensureRoot();
    // Absolute paths are only accepted when they already live inside the root;
    // anything else is rejected rather than silently rewritten.
    final target = p.isAbsolute(path)
        ? p.normalize(path)
        : p.normalize(p.join(root.path, path));
    _assertInside(root, target);
    return File(target);
  }

  @override
  Future<Uint8List?> readBytes(String path) async {
    final file = await _fileFor(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<bool> writeBytes(String path, Uint8List bytes) async {
    final file = await _fileFor(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return true;
  }

  @override
  Future<bool> delete(String path) async {
    final file = await _fileFor(path);
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }

  @override
  Future<List<String>> list(String directory) async {
    final root = await _ensureRoot();
    final dirPath = p.isAbsolute(directory)
        ? p.normalize(directory)
        : p.normalize(p.join(root.path, directory));
    _assertInside(root, dirPath);
    final dir = Directory(dirPath);
    if (!await dir.exists()) return const [];
    final out = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) out.add(entity.path);
    }
    return out;
  }
}
