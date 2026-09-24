import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import '../../application/online/online_book_port.dart';
import '../../core/persist/kv_settings.dart';

import '../../core/persist/blob_store.dart';

/// 目录缓存：只保存 ≥5 章的结果。按书 blob，旧 prefs 大 JSON 只读一次。
class TocCache implements ChapterCatalogStore {
  TocCache._();
  static final TocCache instance = TocCache._();

  static const _legacyKey = 'tocCacheV1';
  static const _maxBooks = 24;

  final Map<String, List<BookChapter>> _mem = {};
  bool _loaded = false;
  Future<void>? _loadFuture;
  final Set<String> _skipOnce = {};

  @override
  void skipNext(String bookUrl) => _skipOnce.add(bookUrl);

  @override
  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loadFuture ??= _load();
  }

  @override
  Future<void> hydrate(String bookUrl) async {
    await ensureLoaded();
    if (bookUrl.isEmpty || _mem.containsKey(bookUrl)) return;
    try {
      final bytes = await BlobStore.instance.get('toc/$bookUrl');
      if (bytes == null || bytes.isEmpty) return;
      final list = _decodeChapters(jsonDecode(utf8.decode(bytes)));
      if (list.length >= 5) _mem[bookUrl] = list;
    } catch (_) {}
  }

  Future<void> _load() async {
    final legacyEntries = <MapEntry<String, List<BookChapter>>>[];
    try {
      final p = await KvSettings.ready();
      final raw = p.getString(_legacyKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            for (final e in decoded.entries) {
              final list = _decodeChapters(e.value);
              final bookUrl = e.key.toString();
              if (list.length >= 5 && !_mem.containsKey(bookUrl)) {
                _mem[bookUrl] = list;
                legacyEntries.add(MapEntry(bookUrl, list));
              }
            }
          }
        } catch (_) {
          // A corrupt legacy snapshot must not prevent current blob entries
          // from hydrating.
        }
      }

      // Copy legacy entries before awaiting writes; put/remove may mutate
      // _mem while the migration is flushing blobs.
      for (final e in legacyEntries) {
        await _writeBlob(e.key, e.value);
      }
      if (raw != null && raw.isNotEmpty) await p.remove(_legacyKey);
    } catch (_) {
    } finally {
      _loaded = true;
      _loadFuture = null;
    }
  }

  List<BookChapter> _decodeChapters(Object? value) {
    if (value is! List) return <BookChapter>[];
    return [
      for (final c in value)
        if (c is Map) BookChapter.fromJson(Map<String, dynamic>.from(c)),
    ];
  }

  @override
  List<BookChapter>? take(String bookUrl) {
    if (_skipOnce.remove(bookUrl)) return null;
    return _mem[bookUrl];
  }

  /// Compatibility alias for feature code that needs a one-shot read.
  List<BookChapter>? get(String bookUrl) => take(bookUrl);

  @override
  List<BookChapter>? peek(String bookUrl) => _mem[bookUrl];

  @override
  Future<void> put(String bookUrl, List<BookChapter> chapters) async {
    if (bookUrl.isEmpty || chapters.length < 5) return;
    _mem[bookUrl] = chapters;
    while (_mem.length > _maxBooks) {
      final old = _mem.keys.first;
      _mem.remove(old);
      await BlobStore.instance.remove('toc/$old');
    }
    await _writeBlob(bookUrl, chapters);
  }

  @override
  Future<void> remove(String bookUrl) async {
    _mem.remove(bookUrl);
    await BlobStore.instance.remove('toc/$bookUrl');
  }

  Future<void> _writeBlob(String bookUrl, List<BookChapter> chapters) async {
    try {
      final raw = jsonEncode(chapters.map((c) => c.toJson()).toList());
      await BlobStore.instance.put(
        'toc/$bookUrl',
        Uint8List.fromList(utf8.encode(raw)),
      );
    } catch (_) {}
  }
}
