import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_db.dart';
import '../../data/database/app_database.dart' as db;
import 'blob_file_stub.dart' if (dart.library.io) 'blob_file_io.dart';
import 'blob_idb_stub.dart' if (dart.library.html) 'blob_idb_web.dart';

/// Per-key binary store. Memory first; Web uses IndexedDB (dual-reads old
/// prefs keys). VM/tests stay on one prefs entry per key, never a giant JSON.
class BlobStore {
  BlobStore._();
  static final BlobStore instance = BlobStore._();

  static const _prefix = 'cblob:';

  /// Native values are files by default; SharedPreferences keeps only a
  /// pointer and the compatibility index. Web persists values in IndexedDB.
  static const int fileThreshold = 0;

  /// Bound a single expendable cache object; permanent documents use the
  /// separate LocalDocumentStore and have no size cap.
  static const int fileHardCap = 256 * 1024 * 1024;

  /// prefs 指针前缀：值以 `@f:` 开头表示真身在该相对路径的文件里。
  static const _filePointer = '@f:';
  static const int memoryBudgetBytes = 8 * 1024 * 1024;

  final LinkedHashMap<String, Uint8List> _mem = LinkedHashMap();
  final Set<String> _index = {};
  final Map<String, int> _lastIndexTouch = {};
  int _memBytes = 0;
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
      try {
        final database = AppDb.current;
        if (database != null) {
          final rows = await database.select(database.blobEntries).get();
          _index.addAll(rows.map((row) => row.key));
        }
      } catch (_) {}
    } finally {
      _indexLoaded = true;
      _indexFuture = null;
    }
  }

  Future<Uint8List?> get(String key) async {
    final hit = _mem.remove(key);
    if (hit != null) {
      _mem[key] = hit;
      unawaited(_touchPersistentIndex(key, hit.lengthInBytes));
      return hit;
    }
    await _ensureIndex();
    final fromIdb = await idbGet(key);
    if (fromIdb != null) {
      _remember(key, fromIdb);
      unawaited(_touchPersistentIndex(key, fromIdb.lengthInBytes));
      return fromIdb;
    }
    try {
      final p = await SharedPreferences.getInstance();
      final stored = p.getString(_prefix + key);
      if (stored == null || stored.isEmpty) return null;
      // 大值指针：真身在文件层。
      if (stored.startsWith(_filePointer)) {
        final bytes = await BlobFileBackend.instance.read(
          stored.substring(_filePointer.length),
        );
        if (bytes == null) return null;
        _remember(key, bytes);
        unawaited(_touchPersistentIndex(key, bytes.lengthInBytes));
        return bytes;
      }
      final bytes = base64Decode(stored);
      _remember(key, bytes);
      unawaited(_touchPersistentIndex(key, bytes.lengthInBytes));
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String key, Uint8List bytes) async {
    await putDurable(key, bytes);
  }

  /// Persists a value and reports whether a durable backend accepted it.
  /// Callers with retryable dirty state (for example chapter downloads) must
  /// not clear that state when all persistent backends are unavailable.
  Future<bool> putDurable(String key, Uint8List bytes) async {
    await _ensureIndex();
    _remember(key, bytes);
    try {
      final idbOk = await idbPut(key, bytes);
      if (idbOk) {
        _index.add(key);
        await _touchPersistentIndex(key, bytes.lengthInBytes, force: true);
        return true;
      }
      final p = await SharedPreferences.getInstance();
      var persisted = false;
      // 大值分流：gzip 后仍超过阈值的值落文件，prefs 只存指针；
      // 超过硬上限（异常巨型值）则放弃持久化（与旧「超限跳过」一致，
      // 但阈值从 512KB 降到文件层可承接的 256KB 起）。
      if (bytes.length >= fileThreshold) {
        if (bytes.length > fileHardCap) return false;
        final rel =
            'blob/${crypto.sha1.convert(utf8.encode(key)).toString()}.blob';
        final ok = await BlobFileBackend.instance.write(rel, bytes);
        if (ok) {
          persisted = await p.setString(_prefix + key, '$_filePointer$rel');
          if (!persisted) await BlobFileBackend.instance.delete(rel);
        }
        // 文件层不可用：回退 prefs 仅当仍低于旧单条安全线（512KB）。
        if (!persisted && bytes.length > 512 * 1024) return false;
      }
      if (!persisted) {
        persisted = await p.setString(_prefix + key, base64Encode(bytes));
      }
      if (persisted) {
        _index.add(key);
        final indexed = await p.setStringList('cblobIndex', _index.toList());
        if (!indexed) return false;
        await _touchPersistentIndex(key, bytes.lengthInBytes, force: true);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> remove(String key) async {
    _forget(key);
    _index.remove(key);
    _lastIndexTouch.remove(key);
    await idbRemove(key);
    try {
      final database = AppDb.current;
      if (database != null) {
        await (database.delete(
          database.blobEntries,
        )..where((entry) => entry.key.equals(key))).go();
      }
    } catch (_) {}
    try {
      final p = await SharedPreferences.getInstance();
      final stored = p.getString(_prefix + key);
      // 大值指针：连同文件一起删。
      if (stored != null && stored.startsWith(_filePointer)) {
        await BlobFileBackend.instance.delete(
          stored.substring(_filePointer.length),
        );
      }
      await p.remove(_prefix + key);
      await p.setStringList('cblobIndex', _index.toList());
    } catch (_) {}
  }

  Future<void> clearPrefix(String prefix) async {
    final drop = await keys(prefix: prefix);
    await idbClearKeys(drop);
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    for (final k in drop) {
      _forget(k);
      await idbRemove(k);
      if (prefs != null) {
        final stored = prefs.getString(_prefix + k);
        if (stored != null && stored.startsWith(_filePointer)) {
          await BlobFileBackend.instance.delete(
            stored.substring(_filePointer.length),
          );
        }
        await prefs.remove(_prefix + k);
      }
      _index.remove(k);
      _lastIndexTouch.remove(k);
      try {
        final database = AppDb.current;
        if (database != null) {
          await (database.delete(
            database.blobEntries,
          )..where((entry) => entry.key.equals(k))).go();
        }
      } catch (_) {}
    }
    if (prefs != null) {
      await prefs.setStringList('cblobIndex', _index.toList());
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
    try {
      final database = AppDb.current;
      if (database != null) {
        final rows = await database.select(database.blobEntries).get();
        _index.addAll(rows.map((row) => row.key));
      }
    } catch (_) {}
    final all = _index.toList(growable: false);
    if (prefix == null || prefix.isEmpty) return all;
    return all.where((key) => key.startsWith(prefix)).toList(growable: false);
  }

  Future<void> _touchPersistentIndex(
    String key,
    int size, {
    bool force = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && !_index.contains(key)) return;
    final last = _lastIndexTouch[key] ?? 0;
    if (!force && now - last < const Duration(minutes: 1).inMilliseconds) {
      return;
    }
    _lastIndexTouch[key] = now;
    try {
      final database = AppDb.current;
      if (database == null) return;
      await database
          .into(database.blobEntries)
          .insertOnConflictUpdate(
            db.BlobEntriesCompanion.insert(
              key: key,
              size: drift.Value(size),
              lastAccess: drift.Value(now),
            ),
          );
    } catch (_) {}
  }

  void _remember(String key, Uint8List bytes) {
    _forget(key);
    if (bytes.lengthInBytes > memoryBudgetBytes) return;
    _mem[key] = bytes;
    _memBytes += bytes.lengthInBytes;
    while (_memBytes > memoryBudgetBytes && _mem.isNotEmpty) {
      final oldest = _mem.keys.first;
      _memBytes -= _mem.remove(oldest)!.lengthInBytes;
    }
  }

  void _forget(String key) {
    final old = _mem.remove(key);
    if (old != null) _memBytes -= old.lengthInBytes;
  }
}
