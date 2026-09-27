import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';

import '../persist/kv_settings.dart';

/// legado 未测速时的占位（3 分钟），不当作真实耗时。
const int unsetRespondTimeMs = 180000;

bool isHttpSearchUrl(BookSource source) {
  final u = (source.searchUrl ?? '').trim().toLowerCase();
  return u.startsWith('http://') || u.startsWith('https://');
}

int effectiveRespondTime(BookSource source) {
  final t = source.respondTime;
  if (t <= 0 || t >= unsetRespondTimeMs) return unsetRespondTimeMs;
  return t;
}

/// EMA：历史 75% + 本次 25%。失败源加倍，但仍保留在队列里。
int blendRespondTime(int previous, int sampleMs, {bool failed = false}) {
  var sample = sampleMs.clamp(40, 30000);
  if (failed) sample = (sample * 2).clamp(1000, 30000);
  if (previous <= 0 || previous >= unsetRespondTimeMs) return sample;
  return ((previous * 3 + sample) / 4).round();
}

/// 快源优先出结果，慢源仍全部入队（legado 全源扇出 + 测速排序）。
List<BookSource> orderSearchSources(List<BookSource> sources) {
  final list = List<BookSource>.from(sources);
  list.sort((a, b) {
    final ah = isHttpSearchUrl(a) ? 0 : 1;
    final bh = isHttpSearchUrl(b) ? 0 : 1;
    if (ah != bh) return ah - bh;
    final aq = SourceHealthStore.quality(a.bookSourceUrl);
    final bq = SourceHealthStore.quality(b.bookSourceUrl);
    // Reliability gets a meaningful vote, but a new/low-sample source keeps
    // the neutral prior so it is still explored.
    if ((aq - bq).abs() >= 0.12) return bq.compareTo(aq);
    final ar = effectiveRespondTime(a);
    final br = effectiveRespondTime(b);
    if (ar != br) return ar.compareTo(br);
    final order = a.customOrder.compareTo(b.customOrder);
    if (order != 0) return order;
    return b.weight.compareTo(a.weight);
  });
  return list;
}

class CachedSourceHits {
  CachedSourceHits(this.books, this.at);

  final List<SearchBook> books;
  final DateTime at;

  bool get isFresh => DateTime.now().difference(at) < SearchHitCache.ttl;
}

/// Stable cache identity for a single source search. Keeping construction in
/// one value object prevents callers from accidentally omitting page or the
/// semantic source context when they build a key.
class SearchCacheKey {
  const SearchCacheKey({
    required this.query,
    required this.page,
    required this.sourceUrl,
    this.context = '',
  });

  final String query;
  final int page;
  final String sourceUrl;
  final String context;

  String get value =>
      '$page\u0001$sourceUrl\u0001${query.trim()}\u0001$context';

  factory SearchCacheKey.fromSource({
    required BookSource source,
    required String query,
    required int page,
  }) =>
      SearchCacheKey(
        query: query,
        page: page,
        sourceUrl: source.bookSourceUrl,
        context: searchCacheContext(source),
      );
}

/// 同关键词 + 页 + 书源的短期命中缓存。未命中的源照常请求。
class SearchHitCache {
  SearchHitCache({this.maxEntries = 400});

  static const ttl = Duration(minutes: 20);
  static final instance = SearchHitCache();

  final int maxEntries;
  final _map = <String, CachedSourceHits>{};
  final _order = <String>[];

  /// Include the request/rule context in the key.  A source can keep the
  /// same URL while changing its search selectors, headers, login state, or
  /// JS library; serving an old hit in that case is a silent semantic
  /// mismatch.  [context] is optional for backwards-compatible callers and
  /// tests that use a raw source URL.
  String keyOf(
    String query,
    int page,
    String sourceUrl, {
    String context = '',
  }) => SearchCacheKey(
        query: query,
        page: page,
        sourceUrl: sourceUrl,
        context: context,
      ).value;

  List<SearchBook>? take(
    String query,
    int page,
    String sourceUrl, {
    String context = '',
  }) {
    final key = keyOf(query, page, sourceUrl, context: context);
    final hit = _map[key];
    if (hit == null || !hit.isFresh) {
      if (hit != null) {
        _map.remove(key);
        _order.remove(key);
      }
      return null;
    }
    _order.remove(key);
    _order.add(key);
    return hit.books;
  }

  List<SearchBook>? takeForSource(
    BookSource source,
    String query, {
    int page = 1,
  }) {
    final key = SearchCacheKey.fromSource(
      source: source,
      query: query,
      page: page,
    );
    return takeKey(key);
  }

  /// Uses a key captured before rule execution. A JS rule may mutate runtime
  /// variables while searching; recomputing the context for the write would
  /// make the next invocation unable to reproduce the request key.
  List<SearchBook>? takeKey(SearchCacheKey key) =>
      take(key.query, key.page, key.sourceUrl, context: key.context);

  void put(
    String query,
    int page,
    String sourceUrl,
    List<SearchBook> books, {
    String context = '',
  }) {
    final key = keyOf(query, page, sourceUrl, context: context);
    _map[key] = CachedSourceHits(
      List<SearchBook>.unmodifiable(books),
      DateTime.now(),
    );
    _order.remove(key);
    _order.add(key);
    while (_order.length > maxEntries) {
      final old = _order.removeAt(0);
      _map.remove(old);
    }
    _dirty = true;
  }

  void putForSource(
    BookSource source,
    String query,
    List<SearchBook> books, {
    int page = 1,
  }) {
    final key = SearchCacheKey.fromSource(
      source: source,
      query: query,
      page: page,
    );
    putKey(key, books);
  }

  void putKey(SearchCacheKey key, List<SearchBook> books) => put(
        key.query,
        key.page,
        key.sourceUrl,
        books,
        context: key.context,
      );

  static bool _hydrated = false;
  static bool _dirty = false;
  static Future<void>? _loadFuture;

  static Future<void> ensureLoaded() {
    if (_hydrated) return Future<void>.value();
    return _loadFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      final p = await KvSettings.ready();
      final raw = p.getString('searchHitCacheV1');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final cache = instance;
          decoded.forEach((key, value) {
            if (value is! Map) return;
            final at = DateTime.tryParse(value['at']?.toString() ?? '');
            final booksRaw = value['books'];
            if (at == null || booksRaw is! List) return;
            final hit = CachedSourceHits([
              for (final b in booksRaw)
                if (b is Map) SearchBook.fromJson(Map<String, dynamic>.from(b)),
            ], at);
            if (!hit.isFresh) return;
            final k = key.toString();
            // A non-blocking first search may populate the cache while disk
            // hydration is still in flight.  Keep that live result instead
            // of overwriting it with an older persisted snapshot.
            if (cache._map.containsKey(k)) return;
            cache._map[k] = hit;
            cache._order.remove(k);
            cache._order.add(k);
          });
        }
      }
    } catch (_) {}
    _hydrated = true;
    _loadFuture = null;
  }

  Future<void> flush() async {
    if (!_dirty) return;
    _dirty = false;
    try {
      final slice = _order.length > 80
          ? _order.sublist(_order.length - 80)
          : _order;
      final out = <String, dynamic>{};
      for (final k in slice) {
        final hit = _map[k];
        if (hit == null || !hit.isFresh) continue;
        out[k] = {
          'at': hit.at.toIso8601String(),
          'books': [for (final b in hit.books) b.toJson()],
        };
      }
      final p = await KvSettings.ready();
      await p.setString('searchHitCacheV1', jsonEncode(out));
    } catch (_) {}
  }

  void clear() {
    _map.clear();
    _order.clear();
    _dirty = false;
  }

  int get length => _map.length;
}

/// Stable semantic fingerprint for a source's search request.  Do not use
/// Dart's [Object.hashCode] here: its process-randomized value would make
/// persisted cache entries unusable after restart.  Keeping the JSON payload
/// itself (rather than a lossy hash) also makes cache keys diagnosable in
/// preference/debug tooling.
String searchCacheContext(BookSource source) {
  final runtime = <String, String>{};
  final runtimeKeys = source.runtimeVars.keys.toList()..sort();
  for (final key in runtimeKeys) {
    runtime[key] = source.runtimeVars[key] ?? '';
  }
  final payload = <String, Object?>{
    'searchUrl': source.searchUrl ?? '',
    'ruleSearch': source.ruleSearch?.toJson(),
    'header': source.header ?? '',
    'jsLib': source.jsLib ?? '',
    'loginCheckJs': source.loginCheckJs ?? '',
    'enabledCookieJar': source.enabledCookieJar,
    'bookUrlPattern': source.bookUrlPattern ?? '',
    'runtimeVars': runtime,
  };
  return jsonEncode(payload);
}

/// 书源实测耗时，跨次搜索保留，用来做快慢排序。
class SourceLatencyStore {
  SourceLatencyStore._();

  static const prefsKey = 'sourceRespondTime';
  static final Map<String, int> times = {};
  static bool _loaded = false;
  static bool _dirty = false;
  static Future<void>? _loadFuture;

  static Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loadFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      final prefs = await KvSettings.ready();
      final raw = prefs.getString(prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is num) times[key.toString()] = value.toInt();
          });
        }
      }
    } catch (_) {}
    _loaded = true;
    _loadFuture = null;
  }

  static void applyTo(Iterable<BookSource> sources) {
    for (final source in sources) {
      final ms = times[source.bookSourceUrl];
      if (ms != null && ms > 0) source.respondTime = ms;
    }
  }

  static void record(String url, int ms) {
    times[url] = ms;
    _dirty = true;
  }

  static Future<void> flush() async {
    if (!_dirty) return;
    _dirty = false;
    try {
      final prefs = await KvSettings.ready();
      await prefs.setString(prefsKey, jsonEncode(times));
    } catch (_) {}
  }
}

class _SourceHealthEntry {
  _SourceHealthEntry({this.successes = 0, this.failures = 0});

  int successes;
  int failures;

  double get quality => (successes + 2) / (successes + failures + 4);

  Map<String, dynamic> toJson() => {
    'successes': successes,
    'failures': failures,
  };
}

/// Small, decaying-independent reliability ledger used as a secondary source
/// ordering signal. Latency alone can permanently favor a fast but broken
/// source, so empty/error responses contribute failures and valid responses
/// contribute successes.
class SourceHealthStore {
  SourceHealthStore._();

  static const prefsKey = 'sourceHealthV1';
  static final Map<String, _SourceHealthEntry> _entries = {};
  static bool _loaded = false;
  static bool _dirty = false;
  static Future<void>? _loadFuture;

  static Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loadFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      final prefs = await KvSettings.ready();
      final raw = prefs.getString(prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (value is! Map) return;
            _entries[key.toString()] = _SourceHealthEntry(
              successes: (value['successes'] as num?)?.toInt() ?? 0,
              failures: (value['failures'] as num?)?.toInt() ?? 0,
            );
          });
        }
      }
    } catch (_) {}
    _loaded = true;
    _loadFuture = null;
  }

  static double quality(String sourceUrl) =>
      _entries[sourceUrl]?.quality ?? 0.5;

  static void record(String sourceUrl, {required bool success}) {
    final entry = _entries.putIfAbsent(sourceUrl, _SourceHealthEntry.new);
    if (success) {
      entry.successes++;
    } else {
      entry.failures++;
    }
    // Keep the ledger bounded and let old history lose influence.
    final total = entry.successes + entry.failures;
    if (total > 200) {
      entry.successes = (entry.successes * 0.75).round();
      entry.failures = (entry.failures * 0.75).round();
    }
    _dirty = true;
  }

  static Future<void> flush() async {
    if (!_dirty) return;
    _dirty = false;
    try {
      final prefs = await KvSettings.ready();
      await prefs.setString(
        prefsKey,
        jsonEncode({for (final e in _entries.entries) e.key: e.value.toJson()}),
      );
    } catch (_) {}
  }
}
