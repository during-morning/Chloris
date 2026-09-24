import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:shared_preferences/shared_preferences.dart';

import 'blob_file_stub.dart' if (dart.library.io) 'blob_file_io.dart';
import 'blob_idb_stub.dart' if (dart.library.html) 'blob_idb_web.dart';

/// Per-key binary store. Memory first; Web uses IndexedDB (dual-reads old
/// prefs keys). VM/tests stay on one prefs entry per key, never a giant JSON.
class BlobStore {
  BlobStore._();
  static final BlobStore instance = BlobStore._();

  static const _prefix = 'cblob:';

  /// 大值分流阈值：gzip 后超过该大小的值不再进 SharedPreferences（base64
  /// 膨胀 1.33 倍后会把 prefs 撑到几百 KB），改落文件、prefs 只存指针。
  static const int fileThreshold = 256 * 1024;

  /// 文件层硬上限：超过即放弃持久化（保留内存），防御异常巨型值。
  static const int fileHardCap = 8 * 1024 * 1024;

  /// prefs 指针前缀：值以 `@f:` 开头表示真身在该相对路径的文件里。
  static const _filePointer = '@f:';

  final Map<String, Uint8List> _mem = {};
  final Set<String> _index = {};
  bool _indexLoaded = false;
  Future<void>? _indexFuture;

  Future<void> _ensureIndex() {
    if (_indexLoaded) return Future<void>.value();
    return _indexFuture ??= _loadIndex();
  }

  Future<void> _loadIndex() async {
    try {
      try {
        final p = await SharedPreferences.getInstance();
        final raw = p.getStringList('cblobIndex');
        if (raw != null) _index.addAll(raw);
      } catch (_) {}
      try {
        _index.addAll(await idbListKeys());
      } catch (_) {}
    } finally {
      _indexLoaded = true;
      _indexFuture = null;
    }
  }

  Future<Uint8List?> get(String key) async {
    final hit = _mem[key];
    if (hit != null) return hit;
    await _ensureIndex();
    final fromIdb = await idbGet(key);
    if (fromIdb != null) {
      _mem[key] = fromIdb;
      return fromIdb;
    }
    try {
      final p = await SharedPreferences.getInstance();
      final stored = p.getString(_prefix + key);
      if (stored == null || stored.isEmpty) return null;
      // 大值指针：真身在文件层。
      if (stored.startsWith(_filePointer)) {
        final bytes = await BlobFileBackend.instance
            .read(stored.substring(_filePointer.length));
        if (bytes == null) return null;
        _mem[key] = bytes;
        return bytes;
      }
      final bytes = base64Decode(stored);
      _mem[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String key, Uint8List bytes) async {
    _mem[key] = bytes;
    _index.add(key);
    final idbOk = await idbPut(key, bytes);
    if (idbOk) return;
    try {
      final p = await SharedPreferences.getInstance();
      // 大值分流：gzip 后仍超过阈值的值落文件，prefs 只存指针；
      // 超过硬上限（异常巨型值）则放弃持久化（与旧「超限跳过」一致，
      // 但阈值从 512KB 降到文件层可承接的 256KB 起）。
      if (bytes.length >= fileThreshold) {
        if (bytes.length > fileHardCap) return;
        final rel =
            'blob/${crypto.sha1.convert(utf8.encode(key)).toString()}.gz';
        final ok = await BlobFileBackend.instance.write(rel, bytes);
        if (ok) {
          await p.setString(_prefix + key, '$_filePointer$rel');
          await p.setStringList('cblobIndex', _index.toList());
          return;
        }
        // 文件层不可用：回退 prefs 仅当仍低于旧单条安全线（512KB）。
        if (bytes.length > 512 * 1024) return;
      }
      await p.setString(_prefix + key, base64Encode(bytes));
      await p.setStringList('cblobIndex', _index.toList());
    } catch (_) {}
  }

  Future<void> remove(String key) async {
    _mem.remove(key);
    _index.remove(key);
    await idbRemove(key);
    try {
      final p = await SharedPreferences.getInstance();
      final stored = p.getString(_prefix + key);
      // 大值指针：连同文件一起删。
      if (stored != null && stored.startsWith(_filePointer)) {
        await BlobFileBackend.instance
            .delete(stored.substring(_filePointer.length));
      }
      await p.remove(_prefix + key);
      await p.setStringList('cblobIndex', _index.toList());
    } catch (_) {}
  }

  Future<void> clearPrefix(String prefix) async {
    await _ensureIndex();
    final drop = _index.where((k) => k.startsWith(prefix)).toList();
    await idbClearKeys(drop);
    for (final k in drop) {
      await remove(k);
    }
  }

  /// Lists persisted keys so feature caches can restore after an app restart.
  /// The in-memory index and IndexedDB are merged because either backend may
  /// be unavailable on a given platform.
  Future<List<String>> keys({String? prefix}) async {
    await _ensureIndex();
    try {
      _index.addAll(await idbListKeys());
    } catch (_) {}
    final all = _index.toList(growable: false);
    if (prefix == null || prefix.isEmpty) return all;
    return all.where((key) => key.startsWith(prefix)).toList(growable: false);
  }
}
