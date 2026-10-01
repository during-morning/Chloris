import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Native file backend for [BlobStore]'s large-value tier.
///
/// Values above the in-prefs threshold (gzip 后仍超 256KB 的章节正文) live in
/// files under the app's support directory instead of one giant SharedPreferences
/// entry; the prefs row keeps only a pointer (`@f:<相对路径>`). All IO failures
/// degrade to "backend unavailable" — the caller then skips persisting that
/// value, exactly like the old over-limit skip, but only for genuinely huge
/// blobs.
class BlobFileBackend {
  BlobFileBackend._();
  static final BlobFileBackend instance = BlobFileBackend._();

  Directory? _root;
  bool _failed = false;

  Future<String?> _resolve(String rel) async {
    if (_failed) return null;
    try {
      var base = _root;
      if (base == null) {
        final support = await getApplicationSupportDirectory();
        base = Directory(p.join(support.path, 'cblob'));
        if (!base.existsSync()) base.createSync(recursive: true);
        _root = base;
      }
      final path = p.normalize(p.join(base.path, rel));
      // 防目录穿越：rel 是哈希文件名，但归一化后仍校验前缀。
      if (!p.isWithin(base.path, path)) {
        return null;
      }
      return path;
    } catch (_) {
      // 目录创建失败（权限/磁盘）：本次会话内不再尝试，避免每个章节重试。
      _failed = true;
      return null;
    }
  }

  Future<bool> write(String rel, Uint8List bytes) async {
    final path = await _resolve(rel);
    if (path == null) return false;
    File? temp;
    try {
      final f = File(path);
      await f.parent.create(recursive: true);
      temp = File('$path.${pid}.${DateTime.now().microsecondsSinceEpoch}.tmp');
      await temp.writeAsBytes(bytes, flush: true);
      try {
        await temp.rename(path);
      } on FileSystemException {
        // Some Windows filesystems do not replace an existing target on
        // rename. The temp file remains on the same volume, so this fallback
        // still avoids exposing a partially written document.
        if (await f.exists()) await f.delete();
        await temp.rename(path);
      }
      return true;
    } catch (_) {
      try {
        if (temp != null && await temp.exists()) await temp.delete();
      } catch (_) {}
      return false;
    }
  }

  Future<Uint8List?> read(String rel) async {
    final path = await _resolve(rel);
    if (path == null) return null;
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String rel) async {
    final path = await _resolve(rel);
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }
}
