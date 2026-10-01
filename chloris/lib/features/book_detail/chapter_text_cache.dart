import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import '../../application/download/downloaded_chapter_store.dart';
import '../../application/online/online_book_port.dart';
import '../../core/persist/kv_settings.dart';
import '../../core/persist/blob_store.dart';

/// Chapter cache with lazy disk reads, a byte-bounded plaintext LRU and a
/// serialized dirty-only writer. Persisted text is expendable; downloaded
/// chapters are stored separately by the download repository.
class ChapterTextCache
    implements ChapterContentStore, AsyncChapterContentStore {
  ChapterTextCache._();
  static final ChapterTextCache instance = ChapterTextCache._();

  static const _legacyKey = 'chapterTextCacheV2';
  static const _legacyKey1 = 'chapterTextCacheV1';
  static const _orderKey = 'chapterCacheOrderV1';
  static const _maxMemBytes = 16 * 1024 * 1024;
  static const _maxDiskBytes = 256 * 1024 * 1024;
  static const _maxDiskEntries = 80;
  static const _maxEntryBytes = 4 * 1024 * 1024;

  final Map<String, String> _mem = {};
  final LinkedHashSet<String> _memOrder = LinkedHashSet<String>();
  final Map<String, String> _dirty = {};
  final Map<String, Future<String?>> _reads = {};
  final LinkedHashSet<String> _diskOrder = LinkedHashSet<String>();
  final Map<String, int> _diskSize = {};

  int _memBytes = 0;
  int _diskBytes = 0;
  bool _loaded = false;
  Future<void>? _loadFuture;
  Future<void>? _legacyFuture;
  Future<void>? _persistFuture;
  Timer? _retry;
  int _retryCount = 0;
  bool _retryPending = false;

  String _k(String source, String url) => '$source|$url';
  String _blobKey(String key) => 'chapter/$key';

  @override
  String? get(String sourceId, String chapterUrl) {
    final key = _k(sourceId, chapterUrl);
    final value = _mem[key];
    if (value != null) _touchMemory(key);
    return value;
  }

  @override
  Future<String?> read(String sourceId, String chapterUrl) async {
    await ensureLoaded();
    final key = _k(sourceId, chapterUrl);
    final hot = _mem[key];
    if (hot != null) {
      _touchMemory(key);
      return hot;
    }
    final existing = _reads[key];
    if (existing != null) return existing;
    final future = _readDisk(key);
    _reads[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_reads[key], future)) _reads.remove(key);
    }
  }

  Future<String?> _readDisk(String key) async {
    final separator = key.indexOf('|');
    if (separator > 0 && separator < key.length - 1) {
      final downloaded = await DownloadedChapterStore.instance.get(
        key.substring(0, separator),
        key.substring(separator + 1),
      );
      if (downloaded != null && downloaded.isNotEmpty) {
        _remember(key, downloaded);
        return downloaded;
      }
    }
    var raw = await BlobStore.instance.get(_blobKey(key));
    final migration = _legacyFuture;
    if (raw == null && migration != null) {
      await migration;
      raw = await BlobStore.instance.get(_blobKey(key));
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final text = await compute(_inflateChapter, raw);
      if (text.isEmpty) return null;
      _diskSize[key] = raw.length;
      _touchDisk(key);
      _remember(key, text);
      return text;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> put(String sourceId, String chapterUrl, String text) async {
    if (text.isEmpty) return;
    final key = _k(sourceId, chapterUrl);
    final bytes = utf8.encode(text).length;
    if (bytes > _maxEntryBytes) return;
    _remember(key, text);
    _dirty[key] = text;
    if (_retryCount >= 3) _retryCount = 0;
    // The caller sees the same low-latency behavior as before; flush() is the
    // explicit durability barrier used during lifecycle suspension.
    _schedulePersist();
  }

  void _remember(String key, String text) {
    final size = utf8.encode(text).length;
    if (size > _maxMemBytes) return;
    final old = _mem.remove(key);
    if (old != null) _memBytes -= utf8.encode(old).length;
    _mem[key] = text;
    _touchMemory(key);
    _memBytes += size;
    while (_memBytes > _maxMemBytes && _memOrder.isNotEmpty) {
      final oldest = _memOrder.first;
      _memOrder.remove(oldest);
      final value = _mem.remove(oldest);
      if (value != null) _memBytes -= utf8.encode(value).length;
    }
  }

  void _touchMemory(String key) {
    _memOrder.remove(key);
    _memOrder.add(key);
  }

  void _touchDisk(String key) {
    _diskOrder.remove(key);
    _diskOrder.add(key);
  }

  void _schedulePersist() {
    if (_persistFuture != null || _dirty.isEmpty || _retryPending) return;
    scheduleMicrotask(() {
      if (_persistFuture == null && _dirty.isNotEmpty) {
        unawaited(_runPersist().catchError((Object _) {}));
      }
    });
  }

  Future<void> _runPersist() {
    final running = _persistFuture;
    if (running != null) return running;
    final future = _drainDirty();
    _persistFuture = future;
    return future.then(
      (_) {
        if (identical(_persistFuture, future)) _persistFuture = null;
        _retryCount = 0;
        if (_dirty.isNotEmpty) _schedulePersist();
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_persistFuture, future)) _persistFuture = null;
        _retryCount++;
        if (_dirty.isNotEmpty && _retryCount <= 3) {
          _retryPending = true;
          _retry = Timer(Duration(seconds: _retryCount), () {
            _retryPending = false;
            _retry = null;
            _schedulePersist();
          });
        }
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  Future<void> _drainDirty() async {
    await ensureLoaded();
    while (_dirty.isNotEmpty) {
      final snapshot = Map<String, String>.from(_dirty);
      for (final entry in snapshot.entries) {
        final bytes = await compute(_compressChapter, entry.value);
        if (!await BlobStore.instance.putDurable(_blobKey(entry.key), bytes)) {
          throw StateError('无法持久保存章节缓存：${entry.key}');
        }
        if (_dirty[entry.key] == entry.value) _dirty.remove(entry.key);
        final oldSize = _diskSize[entry.key] ?? 0;
        _diskSize[entry.key] = bytes.length;
        _diskBytes += bytes.length - oldSize;
        _touchDisk(entry.key);
      }
      await _evictDiskIfNeeded();
      _retryCount = 0;
    }
  }

  Future<void> _evictDiskIfNeeded() async {
    while (_diskOrder.length > _maxDiskEntries || _diskBytes > _maxDiskBytes) {
      String? victim;
      for (final key in _diskOrder) {
        if (!_dirty.containsKey(key)) {
          victim = key;
          break;
        }
      }
      if (victim == null) break;
      _diskOrder.remove(victim);
      _diskBytes -= _diskSize.remove(victim) ?? 0;
      await BlobStore.instance.remove(_blobKey(victim));
    }
    await _saveDiskIndex();
  }

  Future<void> _saveDiskIndex() async {
    try {
      final p = await KvSettings.ready();
      await p.setString(
        _orderKey,
        jsonEncode([
          for (final key in _diskOrder) [key, _diskSize[key] ?? 0],
        ]),
      );
    } catch (_) {}
  }

  /// Waits for writes already running and all writes queued at call time.
  Future<void> flush() async {
    _retry?.cancel();
    _retry = null;
    _retryPending = false;
    while (_dirty.isNotEmpty || _persistFuture != null) {
      final running = _persistFuture;
      if (running != null) {
        await running;
      } else {
        await _runPersist();
      }
    }
  }

  @override
  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    final existing = _loadFuture;
    if (existing != null) return existing;
    final future = _loadIndex();
    _loadFuture = future;
    return future.whenComplete(() {
      if (identical(_loadFuture, future)) _loadFuture = null;
      _loaded = true;
    });
  }

  Future<void> _loadIndex() async {
    try {
      final p = await KvSettings.ready();
      final rawOrder = p.getString(_orderKey);
      if (rawOrder != null && rawOrder.isNotEmpty) {
        final rows = jsonDecode(rawOrder) as List<dynamic>;
        for (final row in rows) {
          if (row is! List || row.length < 2) continue;
          final key = row.first?.toString();
          final size = int.tryParse(row[1].toString()) ?? 0;
          if (key == null || key.isEmpty) continue;
          _diskOrder.add(key);
          _diskSize[key] = size;
          _diskBytes += size;
        }
      }
      for (final blob in await BlobStore.instance.keys(prefix: 'chapter/')) {
        final key = blob.substring('chapter/'.length);
        _diskOrder.add(key);
      }
    } catch (_) {}
    // A one-time compatibility migration. It runs only when a reader asks for
    // the cache, and compression is performed off the UI isolate.
    _loaded = true;
    _legacyFuture = _migrateLegacy();
  }

  Future<void> _migrateLegacy() async {
    try {
      final p = await KvSettings.ready();
      final raw = p.getString(_legacyKey) ?? p.getString(_legacyKey1);
      if (raw == null || raw.isEmpty) return;
      final rows = jsonDecode(raw) as List<dynamic>;
      for (final row in rows) {
        if (row is! Map) continue;
        final key = row['k']?.toString();
        if (key == null || key.isEmpty || _diskOrder.contains(key)) continue;
        var text = row['t']?.toString();
        final gzip = row['g']?.toString();
        if (gzip != null && gzip.isNotEmpty) {
          try {
            text = await compute(_inflateLegacy, gzip);
          } catch (_) {}
        }
        if (text == null ||
            text.isEmpty ||
            _mem.containsKey(key) ||
            _dirty.containsKey(key) ||
            utf8.encode(text).length > _maxEntryBytes) {
          continue;
        }
        _dirty[key] = text;
      }
      if (_dirty.isNotEmpty) await _runPersist();
      await p.remove(_legacyKey);
      await p.remove(_legacyKey1);
    } catch (_) {
      // Keep legacy data intact if migration could not complete.
    }
  }

  /// Drops only the in-memory view and rehydrates the index on next access.
  Future<void> reload() async {
    await flush();
    _mem.clear();
    _memOrder.clear();
    _memBytes = 0;
    _loaded = false;
    await ensureLoaded();
  }

  @override
  Future<void> remove(String sourceId, String chapterUrl) async {
    final key = _k(sourceId, chapterUrl);
    final old = _mem.remove(key);
    if (old != null) _memBytes -= utf8.encode(old).length;
    _memOrder.remove(key);
    _dirty.remove(key);
    _diskOrder.remove(key);
    _diskBytes -= _diskSize.remove(key) ?? 0;
    await BlobStore.instance.remove(_blobKey(key));
    await _saveDiskIndex();
  }

  Future<void> removeChapters(
    String origin,
    Iterable<String> chapterUrls,
  ) async {
    for (final url in chapterUrls) {
      await remove(origin, url);
    }
  }

  Future<void> clear() async {
    await flush();
    _mem.clear();
    _memOrder.clear();
    _memBytes = 0;
    _dirty.clear();
    _diskOrder.clear();
    _diskSize.clear();
    _diskBytes = 0;
    _loaded = true;
    await BlobStore.instance.clearPrefix('chapter/');
    try {
      final p = await KvSettings.ready();
      await p.remove(_legacyKey);
      await p.remove(_legacyKey1);
      await p.remove(_orderKey);
    } catch (_) {}
  }

  int get chapterCount => _mem.length;
  int get approxBytes => _memBytes;

  String dumpAll() {
    final buf = StringBuffer();
    for (final key in _memOrder.toList().reversed) {
      final value = _mem[key];
      if (value == null || value.isEmpty) continue;
      buf.writeln('===== $key =====');
      buf.writeln(value);
      buf.writeln();
    }
    return buf.toString();
  }
}

Uint8List _compressChapter(String text) =>
    Uint8List.fromList(GZipEncoder().encode(utf8.encode(text)));

String _inflateChapter(Uint8List bytes) =>
    utf8.decode(GZipDecoder().decodeBytes(bytes));

String _inflateLegacy(String text) =>
    utf8.decode(GZipDecoder().decodeBytes(base64Decode(text)));
