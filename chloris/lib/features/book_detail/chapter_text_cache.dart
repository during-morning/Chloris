import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import '../../application/online/online_book_port.dart';
import '../../core/persist/kv_settings.dart';

import '../../core/persist/blob_store.dart';

/// 正文 LRU：内存明文 + 按章 blob。旧 prefs 大 JSON 只读一次。
class ChapterTextCache implements ChapterContentStore {
  ChapterTextCache._();
  static final ChapterTextCache instance = ChapterTextCache._();

  static const _legacyKey = 'chapterTextCacheV2';
  static const _legacyKey1 = 'chapterTextCacheV1';
  static const _maxMem = 128;
  static const _maxDisk = 80;
  /// 单章正文持久化上限（utf8 字节数）。BlobStore 的大值文件层可承接
  /// gzip 后 256KB–8MB 的值，这里的上限只需挡住异常巨型章节。
  static const _maxBytes = 4 * 1024 * 1024;

  final Map<String, String> _mem = {};
  final List<String> _order = [];
  bool _diskLoaded = false;
  Future<void>? _loadFuture;
  bool _persistScheduled = false;
  bool _persistRunning = false;
  final Set<String> _dirty = {};

  String _k(String origin, String url) => '$origin|$url';
  String _blobKey(String k) => 'chapter/$k';

  @override
  String? get(String origin, String url) {
    final k = _k(origin, url);
    final v = _mem[k];
    if (v == null) return null;
    _touch(k);
    return v;
  }

  @override
  Future<void> put(String origin, String url, String text) async {
    if (text.isEmpty) return;
    final k = _k(origin, url);
    _mem[k] = text;
    _touch(k);
    _dirty.add(k);
    while (_order.length > _maxMem) {
      final old = _order.removeAt(0);
      _mem.remove(old);
    }
    _schedulePersist();
  }

  void _schedulePersist() {
    if (_persistScheduled || _persistRunning) return;
    _persistScheduled = true;
    scheduleMicrotask(() {
      _persistScheduled = false;
      unawaited(_runPersist());
    });
  }

  Future<void> _runPersist() async {
    if (_persistRunning) return;
    _persistRunning = true;
    try {
      while (_dirty.isNotEmpty) {
        await _persistDirty();
      }
    } finally {
      _persistRunning = false;
      if (_dirty.isNotEmpty) _schedulePersist();
    }
  }

  /// Waits for pending writes before lifecycle suspension or a reload.
  Future<void> flush() => _runPersist();

  void _touch(String k) {
    _order.remove(k);
    _order.add(k);
  }

  @override
  Future<void> ensureLoaded() {
    if (_diskLoaded) return Future<void>.value();
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;
    final future = _loadFromDisk();
    _loadFuture = future;
    return future.whenComplete(() {
      if (identical(_loadFuture, future)) {
        _loadFuture = null;
        _diskLoaded = true;
      }
    });
  }

  Future<void> _loadFromDisk() async {
    try {
      final p = await KvSettings.ready();
      var raw = p.getString(_legacyKey);
      raw ??= p.getString(_legacyKey1);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          if (e is! Map) continue;
          final k = e['k']?.toString();
          if (k == null || k.isEmpty) continue;
          String? t = e['t']?.toString();
          final g = e['g']?.toString();
          if (g != null && g.isNotEmpty) {
            try {
              t = utf8.decode(GZipDecoder().decodeBytes(base64Decode(g)));
            } catch (_) {}
          }
          if (t == null || t.isEmpty) continue;
          _mem[k] = t;
          _touch(k);
          _dirty.add(k);
        }
        await _persistDirty();
        await p.remove(_legacyKey);
        await p.remove(_legacyKey1);
      }
    } catch (_) {}
    // Restore the current per-chapter blobs after process restart. This is
    // deliberately bounded by the same disk LRU budget used on writes.
    try {
      final keys = await BlobStore.instance.keys(prefix: 'chapter/');
      var loaded = 0;
      for (final blobKey in keys.reversed) {
        if (loaded >= _maxDisk) break;
        final raw = await BlobStore.instance.get(blobKey);
        if (raw == null || raw.isEmpty) continue;
        try {
          final key = blobKey.substring('chapter/'.length);
          final text = utf8.decode(GZipDecoder().decodeBytes(raw));
          if (text.isEmpty) continue;
          _mem[key] = text;
          _touch(key);
          loaded++;
        } catch (_) {}
      }
      while (_order.length > _maxMem) {
        final old = _order.removeAt(0);
        _mem.remove(old);
      }
    } catch (_) {}
  }

  /// Drops only the in-memory view and rehydrates persisted chapters. Used by
  /// lifecycle recovery and by the persistence regression test.
  Future<void> reload() async {
    final inFlight = _loadFuture;
    if (inFlight != null) await inFlight;
    _mem.clear();
    _order.clear();
    _diskLoaded = false;
    await ensureLoaded();
  }

  Uint8List _deflate(String text) {
    return Uint8List.fromList(GZipEncoder().encode(utf8.encode(text)));
  }

  Future<void> _persistDirty() async {
    final keys = _dirty.toList();
    _dirty.clear();
    var kept = 0;
    final order = List<String>.from(_order.reversed);
    for (final k in order) {
      if (kept >= _maxDisk) break;
      final t = _mem[k];
      if (t == null) continue;
      if (utf8.encode(t).length > _maxBytes) continue;
      kept++;
      if (!keys.contains(k) && !_mem.containsKey(k)) continue;
      try {
        await BlobStore.instance.put(_blobKey(k), _deflate(t));
      } catch (_) {}
    }
  }

  @override
  Future<void> remove(String origin, String url) async {
    final k = _k(origin, url);
    _mem.remove(k);
    _order.remove(k);
    await BlobStore.instance.remove(_blobKey(k));
  }

  /// Removes the cached text of specific chapters of one book.
  ///
  /// The key is `<origin>|<chapterUrl>` where `origin` is the *source* URL, and
  /// one source hosts many books — so a prefix delete on the source would also
  /// destroy every other book's cache. Callers must pass the exact chapter
  /// URLs they own, which is why this takes a collection rather than a prefix.
  Future<void> removeChapters(
    String origin,
    Iterable<String> chapterUrls,
  ) async {
    for (final url in chapterUrls) {
      await remove(origin, url);
    }
  }

  Future<void> clear() async {
    final inFlight = _loadFuture;
    if (inFlight != null) await inFlight;
    _mem.clear();
    _order.clear();
    _dirty.clear();
    _diskLoaded = true;
    await BlobStore.instance.clearPrefix('chapter/');
    try {
      final p = await KvSettings.ready();
      await p.remove(_legacyKey);
      await p.remove(_legacyKey1);
    } catch (_) {}
  }

  int get chapterCount => _mem.length;

  int get approxBytes => _mem.values.fold<int>(0, (a, t) => a + t.length);

  String dumpAll() {
    final buf = StringBuffer();
    for (final k in _order.reversed) {
      final t = _mem[k];
      if (t == null || t.isEmpty) continue;
      buf.writeln('===== $k =====');
      buf.writeln(t);
      buf.writeln();
    }
    return buf.toString();
  }
}
