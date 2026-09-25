import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:html/dom.dart';
import 'package:pointycastle/export.dart';

import '../local/encoding_detect.dart';

import '../analyze/analyze_rule.dart';
import '../analyze/analyze_url.dart';
import '../analyze/rule_data.dart';
import '../debug/debug_log.dart';
import '../font/font_query.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../net/cookie_store.dart';
import '../net/engine_limits.dart';
import '../net/file_port.dart';
import '../net/host_environment.dart';
import '../net/http_port.dart';
import '../net/network_utils.dart';
import '../models/domain_protocol.dart';
import 'js_crypto.dart';
import '../net/rate_limiter.dart';
import '../net/str_response.dart';
import '../net/web_view_port.dart';
import '../purify/chinese_convert.dart';
import 'js_runtime.dart';

/// Methods exposed as `java.*` inside JS.
class JavaHost {
  JavaHost({
    required this.http,
    required this.cookieStore,
    this.analyzeRule,
    this.jsRuntime,
    this.source,
    this.book,
    this.chapter,
    this.ruleData,
    this.webViewPort,
    this.filePort = const UnsupportedFilePort(),
    this.hostEnvironment = const DefaultHostEnvironment(),
  });

  final HttpPort http;
  final CookieStore cookieStore;
  AnalyzeRule? analyzeRule;
  JsRuntime? jsRuntime;
  BookSource? source;
  Book? book;
  BookChapter? chapter;
  RuleData? ruleData;
  WebViewPort? webViewPort;

  /// File access for `java.readFile` / `java.downloadFile` / `java.unzipFile`.
  /// Defaults to a port that reports the capability as absent.
  final FilePort filePort;

  /// Platform interactions for `java.openUrl` / `java.startBrowserAwait` and
  /// the settings getters. Defaults to "no host UI attached".
  final HostEnvironment hostEnvironment;
  final Map<String, String> _vars = {};

  /// Backing store for the `cache.*` facade that rule scripts see.
  ///
  /// Legado's CacheManager is a three-tier store (memory / Room / file). The
  /// bridge exposes the memory tier plus a file tier that delegates to
  /// [cacheFile]; entries do not survive a restart. That is a deliberate,
  /// documented limitation rather than a silent one.
  final Map<String, String> _ruleCache = {};

  /// The "disk" tier of [CacheManager] (`appDb.cacheDao`), kept in process.
  ///
  /// 对齐 Legado-E `help/CacheManager.kt`：那边 `get(key)` 先查内存再查 Room，
  /// 而 `get(key, onlyDisk = true)` **只**查 Room。`chloris_engine` 不持有存储，
  /// 所以这里用进程内 map 顶替 Room 层 —— 命中条件、deadline 与「onlyDisk 走哪
  /// 一层」的语义都与 Legado 一致，唯一差异是不跨重启（刻意且已文档化）。
  final Map<String, _DiskCacheEntry> _diskCache = {};

  /// Live parser nodes handed to JS through `java.getElement` / `getElements`.
  ///
  /// The bridge is JSON-only, so a real jsoup `Element` cannot cross it. Instead
  /// the Dart side keeps the node here and ships an opaque handle; the JS prelude
  /// rebuilds a method-bearing facade on top of it (see [JsHostBridge.prelude]).
  /// Bounded and FIFO: a long-lived script cannot leak nodes indefinitely.
  static const int _elementRegistryCap = 128;
  final Map<int, Element> _elements = {};
  int _elementSeq = 0;

  static const int _cacheMaxBytes = 2 * 1024 * 1024;
  static const Duration _cacheTtl = Duration(minutes: 2);
  static final Map<String, _CacheEntry> _fileCache = {};

  void bindContext({
    JsRuntime? jsRuntime,
    BookSource? source,
    Book? book,
    BookChapter? chapter,
    RuleData? ruleData,
    WebViewPort? webViewPort,
  }) {
    if (jsRuntime != null) this.jsRuntime = jsRuntime;
    if (webViewPort != null) this.webViewPort = webViewPort;
    this.source = source;
    this.book = book;
    this.chapter = chapter;
    this.ruleData = ruleData;
  }

  JsRuntime? get _runtime => jsRuntime ?? analyzeRule?.jsRuntime;
  BookSource? get _source => source ?? analyzeRule?.source;
  Book? get _book => book ?? analyzeRule?.book;
  BookChapter? get _chapter => chapter ?? analyzeRule?.chapter;
  RuleData? get _ruleData => ruleData ?? analyzeRule?.ruleData;

  Future<String?> ajax(Object url) async {
    final spec = url is List ? url.first.toString() : url.toString();
    try {
      final res = await _sendAjax(spec);
      return res.body;
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<StrResponse>> ajaxAll(List<String> urls) async {
    return Future.wait(
      urls.map((u) async {
        try {
          return await _sendAjax(u);
        } catch (e) {
          return StrResponse(url: u, body: e.toString(), code: 500, error: e);
        }
      }),
    );
  }

  Future<StrResponse> _sendAjax(
    String url, {
    Map<String, String>? headers,
  }) async {
    final runtime = _runtime;
    if (runtime == null) {
      return http.send(HttpRequestSpec(url: url, headers: headers ?? const {}));
    }
    final src = _source;
    final analyzeUrl = AnalyzeUrl(
      mUrl: url,
      http: http,
      jsRuntime: runtime,
      baseUrl:
          analyzeRule?.redirectUrl ??
          analyzeRule?.baseUrl ??
          src?.bookSourceUrl ??
          '',
      source: src,
      ruleData: _ruleData,
      book: _book,
      chapter: _chapter,
      cookieStore: cookieStore,
      javaHost: this,
      webViewPort: webViewPort,
      headerMapF: headers,
    );
    return analyzeUrl.getStrResponse();
  }

  Future<Map<String, Object?>> connect(String url, [Object? header]) async {
    try {
      final res = await _sendAjax(url, headers: _asHeaderMap(header));
      return _toJsResponse(res);
    } catch (e) {
      return _toJsResponse(
        StrResponse(url: url, body: e.toString(), code: 500, error: e),
      );
    }
  }

  Future<Map<String, Object?>> httpGet(String url, [Object? headers]) async {
    return _toJsResponse(
      await _plainSend(url, method: 'GET', headers: _asHeaderMap(headers)),
    );
  }

  Future<Map<String, Object?>> httpPost(
    String url,
    String body, [
    Object? headers,
  ]) async {
    return _toJsResponse(
      await _plainSend(
        url,
        method: 'POST',
        headers: _asHeaderMap(headers),
        body: body,
      ),
    );
  }

  Future<Map<String, Object?>> httpHead(String url, [Object? headers]) async {
    return _toJsResponse(
      await _plainSend(url, method: 'HEAD', headers: _asHeaderMap(headers)),
    );
  }

  Future<StrResponse> _plainSend(
    String url, {
    required String method,
    Map<String, String>? headers,
    String? body,
  }) async {
    final src = _source;
    final headerMap = <String, String>{};
    _applySourceHeader(src, headerMap);
    if (headers != null) headerMap.addAll(headers);
    if (src?.enabledCookieJar == true) {
      final cookie = cookieStore.get(src!.bookSourceUrl);
      if (cookie.isNotEmpty) headerMap['Cookie'] = cookie;
    }
    await RateLimiter.shared(src?.bookSourceUrl, src?.concurrentRate).acquire();
    return http.send(
      HttpRequestSpec(url: url, method: method, headers: headerMap, body: body),
    );
  }

  void _applySourceHeader(BookSource? src, Map<String, String> headerMap) {
    final h = src?.header?.trim();
    if (h == null || h.isEmpty || !h.startsWith('{')) return;
    try {
      final map = jsonDecode(h);
      if (map is Map) {
        map.forEach((k, v) => headerMap[k.toString()] = v.toString());
      }
    } catch (_) {}
  }

  Map<String, String>? _asHeaderMap(Object? raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (s.startsWith('{')) {
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          return decoded.map(
            (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
          );
        }
      } catch (_) {}
    }
    return null;
  }

  Map<String, Object?> _toJsResponse(StrResponse res) {
    return {
      'body': res.body ?? '',
      'url': res.url,
      'code': res.code,
      'headers': res.headers,
    };
  }

  String md5Encode(String str) => md5.convert(utf8.encode(str)).toString();

  String md5Encode16(String str) {
    final s = md5Encode(str);
    return s.substring(8, 24);
  }

  String base64EncodeStr(String str) => base64.encode(utf8.encode(str));

  String base64DecodeStr(String str) {
    try {
      final bytes = base64.decode(str.replaceAll(RegExp(r'\s+'), ''));
      try {
        return utf8.decode(bytes);
      } catch (_) {
        return base64.encode(bytes);
      }
    } catch (_) {
      return str;
    }
  }

  String aesDecryptStr(String data, String key, [String? iv]) {
    final raw = Uint8List.fromList(_asBytes(data));
    final keyBytes = _asAesKey(key);
    Uint8List? ivBytes;
    if (iv != null && iv.isNotEmpty) {
      ivBytes = Uint8List.fromList(_asBytes(iv));
      if (ivBytes.length < 16) {
        final padded = Uint8List(16);
        padded.setAll(0, ivBytes);
        ivBytes = padded;
      } else if (ivBytes.length > 16) {
        ivBytes = ivBytes.sublist(0, 16);
      }
    }
    final aligned = _blockAlign(raw);
    final out = aesDecrypt(aligned, keyBytes, iv: ivBytes);
    return base64.encode(_pkcs7Unpad(out));
  }

  String hexDecodeToString(String hex) {
    final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final bytes = <int>[];
    for (var i = 0; i + 1 < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  String hexEncodeToString(String utf) {
    return utf8
        .encode(utf)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  String htmlFormatStr(String s) => htmlFormat(s);

  void removeCookie(String tag) {
    cookieStore.remove(tag);
    if (tag != (_source?.bookSourceUrl ?? '')) {
      cookieStore.remove(_source?.bookSourceUrl ?? tag);
    }
  }

  String getCookie(String tag, [String? key]) {
    if (key == null || key.isEmpty) return cookieStore.get(tag);
    return cookieStore.getKey(tag, key);
  }

  Future<String?> getString(String rule) async {
    if (analyzeRule == null) return '';
    return analyzeRule!.getString(rule);
  }

  Future<List<String>> getStringList(String rule) async {
    if (analyzeRule == null) return const [];
    return analyzeRule!.getStringList(rule);
  }

  /// `java.getElement` —— 对齐 Legado-E `AnalyzeRule.getElement`：返回**首个**
  /// 命中节点，未命中返回 `null`。
  ///
  /// 与旧实现的区别：不再把解析节点降级成 markup 字符串，而是回一个自识别信封
  /// `{"__el": {...}}`（见 [elementEnvelope]），由 JS prelude 还原成带
  /// `.text()` / `.attr()` / `.select()` 的门面对象。Legado 那边交给脚本的是
  /// 真实 jsoup `Element`，而 Chloris 的桥是 JSON-only，这是能做到的最接近形态。
  Future<Object?> getElement(String rule) async {
    if (analyzeRule == null) return null;
    final value = await analyzeRule!.getElement(rule);
    return elementEnvelope(value);
  }

  /// `java.getElements` —— 返回节点列表信封 `{"__els": [...]}`。
  ///
  /// 非元素结果（例如正则后端返回的字符串）走 `{"__raws": [...]}`，JS 侧原样
  /// 取回数组，保持旧行为不变。
  Future<Object?> getElements(String rule) async {
    if (analyzeRule == null) return const {'__els': <Object?>[]};
    return elementsEnvelope(await analyzeRule!.getElements(rule));
  }

  /// Wraps a single rule result for the JS element facade.
  ///
  /// 非 `Element` 结果原样透传 —— JS 侧的 `__elFrom` 只认 `__el` / `__els` /
  /// `__raws` 三种信封，其余值照旧当字符串用，所以这是纯增量改动。
  Object? elementEnvelope(Object? value) {
    if (value is Element) return {'__el': _elementDescriptor(value)};
    return value;
  }

  /// Wraps a rule's element list for the JS element facade.
  Object? elementsEnvelope(List<Object> values) {
    if (values.isEmpty) return const {'__els': <Object?>[]};
    if (values.every((e) => e is Element)) {
      return {
        '__els': <Object?>[
          for (final e in values) _elementDescriptor(e as Element),
        ],
      };
    }
    return {
      '__raws': <Object?>[...values],
    };
  }

  /// Serves one facade method that needs to touch the live node.
  ///
  /// The facade carries most of what a rule needs (text / attrs / html) inside
  /// its descriptor, so only the *descending* methods need a round trip. This is
  /// reached through `invokeSync`, which stringifies its result — hence a JSON
  /// **string** rather than a map.
  String elementOp(Object? handle, String op, Object? argument) {
    final id = handle is num
        ? handle.toInt()
        : int.tryParse(handle?.toString() ?? '') ?? -1;
    final node = _elements[id];
    if (node == null) {
      // 句柄被 LRU 淘汰或从未注册：留一条可见告警，不要静默返回空。
      DebugLog.error('java.element', 'element handle expired: $handle ($op)');
      return '';
    }
    final arg = argument?.toString() ?? '';
    final Object? out = switch (op) {
      'select' => elementsEnvelope(_asElements(node.querySelectorAll(arg))),
      'selectFirst' => elementEnvelope(node.querySelector(arg)),
      'children' => elementsEnvelope(List<Object>.from(node.children)),
      'parent' => elementEnvelope(node.parent),
      'tag' => elementsEnvelope(
        List<Object>.from(node.getElementsByTagName(arg)),
      ),
      'class' => elementsEnvelope(
        List<Object>.from(node.getElementsByClassName(arg)),
      ),
      _ => '',
    };
    if (out is String) return out;
    return jsonEncode(out);
  }

  static List<Object> _asElements(Iterable<Element> nodes) =>
      List<Object>.from(nodes);

  Map<String, Object?> _elementDescriptor(Element e) => {
    'h': _registerElement(e),
    'tag': (e.localName ?? '').toLowerCase(),
    'id': e.id,
    'cls': e.className,
    'attrs': {
      for (final entry in e.attributes.entries)
        entry.key.toString(): entry.value.toString(),
    },
    'text': e.text.trim(),
    'own': _ownTextOf(e),
    'html': e.innerHtml,
    'outer': e.outerHtml,
  };

  static String _ownTextOf(Element e) =>
      e.nodes.whereType<Text>().map((n) => n.text).join().trim();

  /// Registers a live node and returns its handle, evicting the oldest first.
  int _registerElement(Element e) {
    final handle = ++_elementSeq;
    _elements[handle] = e;
    while (_elements.length > _elementRegistryCap) {
      _elements.remove(_elements.keys.first);
    }
    return handle;
  }

  String timeFormat(int time) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      time < 10000000000 ? time * 1000 : time,
    );
    return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
  }

  String timeFormatUTC(int time, String format, int sh) {
    final ms = time < 10000000000 ? time * 1000 : time;
    final offset = sh.abs() <= 18
        ? Duration(hours: sh)
        : Duration(milliseconds: sh);
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).add(offset);
    return _formatDate(dt, format);
  }

  String _formatDate(DateTime dt, String format) {
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return format
        .replaceAll('yyyy', '${dt.year}')
        .replaceAll('SSS', three(dt.millisecond))
        .replaceAll('MM', two(dt.month))
        .replaceAll('dd', two(dt.day))
        .replaceAll('HH', two(dt.hour))
        .replaceAll('mm', two(dt.minute))
        .replaceAll('ss', two(dt.second));
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  /// Mirrors Java's `URLEncoder.encode(str, enc)`.
  ///
  /// Legado-E exposes this under the name `encodeURI`, but it is deliberately
  /// *not* the JavaScript `encodeURI`: spaces become `+`, and `/ ? : & = #`
  /// are all escaped rather than preserved. Only `A-Za-z0-9.-*_` survive
  /// unescaped. Book sources build query strings on the assumption of that
  /// behaviour, so following the JS spec here would silently produce a
  /// different URL than Legado for the same rule.
  ///
  /// Reference: `JsExtensions.kt` `encodeURI(str)` / `encodeURI(str, enc)`.
  String encodeURI(String str, [String? enc]) {
    if (str.isEmpty) return '';
    try {
      final bytes = CharsetEncoder.encode(str, enc ?? 'UTF-8');
      final out = StringBuffer();
      for (final raw in bytes) {
        final c = raw & 0xff;
        final safe =
            (c >= 0x41 && c <= 0x5a) || // A-Z
            (c >= 0x61 && c <= 0x7a) || // a-z
            (c >= 0x30 && c <= 0x39) || // 0-9
            c == 0x2e || // .
            c == 0x2d || // -
            c == 0x2a || // *
            c == 0x5f; // _
        if (safe) {
          out.writeCharCode(c);
        } else if (c == 0x20) {
          out.write('+');
        } else {
          out.write('%');
          out.write(c.toRadixString(16).toUpperCase().padLeft(2, '0'));
        }
      }
      return out.toString();
    } catch (_) {
      return '';
    }
  }

  String t2s(String text) => ChineseConvert.t2s(text);

  String s2t(String text) => ChineseConvert.s2t(text);

  String randomUUID() {
    late Random rng;
    try {
      rng = Random.secure();
    } catch (_) {
      rng = Random(DateTime.now().microsecondsSinceEpoch);
    }
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String h(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }

  String? toNumChapter(String? s) {
    if (s == null) return null;
    final m = RegExp(r'(第)(.+?)(章)').firstMatch(s);
    if (m == null) return s;
    return '${m.group(1)}${_stringToInt(m.group(2)!)}${m.group(3)}${s.substring(m.end)}';
  }

  Future<String> cacheFile(String url, [int saveTime = 0]) async {
    final key = md5Encode16(url);
    final now = DateTime.now();
    final hit = _fileCache[key];
    if (hit != null && hit.until.isAfter(now)) return hit.body;
    final body = (await ajax(url)) ?? '';
    final bytes = utf8.encode(body).length;
    if (bytes <= _cacheMaxBytes) {
      final ttl = saveTime > 0 ? Duration(seconds: saveTime) : _cacheTtl;
      _fileCache[key] = _CacheEntry(body, now.add(ttl));
      if (_fileCache.length > 64) {
        final stale = _fileCache.entries
            .where((e) => e.value.until.isBefore(now))
            .map((e) => e.key)
            .toList();
        for (final k in stale) {
          _fileCache.remove(k);
        }
      }
    }
    return body;
  }

  String androidId() => 'chloris0000000000';

  /// `cache.put` —— Legado `CacheManager.put(key, value, saveTime = 0)`。
  ///
  /// `saveTime` 单位为**秒**，`0` 表示永不失效（`CacheManager.kt:54-70`）；
  /// 写入时同时落内存层与 disk 层。
  String cachePut(String key, String value, [int saveTime = 0]) {
    if (key.isEmpty) return value;
    _ruleCache[key] = value;
    _diskCache[key] = _DiskCacheEntry(
      value,
      saveTime == 0 ? null : DateTime.now().add(Duration(seconds: saveTime)),
    );
    return value;
  }

  /// `cache.putMemory` —— 只写内存层（`CacheManager.kt:72-74`）。
  String cachePutMemory(String key, String value) {
    if (key.isEmpty) return value;
    _ruleCache[key] = value;
    return value;
  }

  /// `cache.get` —— 对齐 `CacheManager.get(key, onlyDisk)`。
  ///
  /// * `onlyDisk == false`：内存层优先，未命中再查 disk 层并**回填内存**
  ///   （`CacheManager.kt:85-93`）。
  /// * `onlyDisk == true`：**只**查 disk 层，既不读内存也不回填
  ///   （`CacheManager.kt:98-104`）。
  ///
  /// ⚠️ 第二参**不是默认值**。旧实现把它当默认值，于是 `cache.get(k, true)`
  /// 在两侧语义正好相反；该条在差异文档 §12 里记为 P2。依赖「默认值」写法的
  /// 规则是 Chloris 独有扩展，不属 Legado 书源。
  String cacheGet(String key, [Object? onlyDisk]) {
    if (key.isEmpty) return '';
    final diskOnly = onlyDisk == true;
    if (!diskOnly) {
      final memory = _ruleCache[key];
      if (memory != null) return memory;
    }
    final fromDisk = _diskGet(key);
    if (fromDisk.isEmpty) return '';
    if (!diskOnly) _ruleCache[key] = fromDisk;
    return fromDisk;
  }

  /// `cache.getFromMemory` —— 只读内存层（`CacheManager.kt:77-79`）。
  String cacheGetFromMemory(String key) =>
      key.isEmpty ? '' : (_ruleCache[key] ?? '');

  /// `cache.getInt` / `cache.getDouble`。
  ///
  /// 对齐 `CacheManager.kt:106-130`：先看内存层，再退回**只读 disk 层**。
  /// 缺值时 Legado 返回 `null`；同步桥会把标量统一 `toString()`，所以这里
  /// 返回 `''`（同样是 falsy，`x || 0` 类写法结果一致）。
  String cacheGetInt(String key) => cacheGet(key, true);
  String cacheGetDouble(String key) => cacheGet(key, true);

  String _diskGet(String key) {
    final entry = _diskCache[key];
    if (entry == null) return '';
    final deadline = entry.deadline;
    if (deadline != null && !DateTime.now().isBefore(deadline)) {
      _diskCache.remove(key);
      return '';
    }
    return entry.body;
  }

  /// `cache.delete` —— 两层都清。
  String cacheDelete(String key) {
    _ruleCache.remove(key);
    _diskCache.remove(key);
    return '';
  }

  /// `cache.deleteMemory` —— 只清内存层（`CacheManager.kt:81-83`）。
  String cacheDeleteMemory(String key) {
    _ruleCache.remove(key);
    return '';
  }

  // ------------------------------------------------------------ file system

  String _fileNameFor(String url) {
    final uri = Uri.tryParse(url);
    final last = (uri?.pathSegments.isNotEmpty ?? false)
        ? uri!.pathSegments.last
        : url.split('/').last;
    final clean = last.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return clean.isEmpty ? md5Encode16(url) : clean;
  }

  static String _baseName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  static DomainError _archiveUnsupported(String format, String detail) =>
      DomainError(
        code: 'archive_unsupported',
        stage: DomainErrorStage.request,
        message: '$format 压缩格式不被当前后端支持',
        cause: detail,
        recoverable: false,
        retryable: false,
        suggestedAction: '当前仅支持 zip；rar/7z 需要额外解码库',
      );

  /// `java.readTxtFile(path)`.
  Future<String> readTxtFile(String path, [String? charset]) async {
    final bytes = await filePort.readBytes(path);
    if (bytes == null || bytes.isEmpty) return '';
    if (charset != null && charset.trim().isNotEmpty) {
      return CharsetDecoder.decode(bytes, charset);
    }
    return EncodingDetect.decode(bytes, EncodingDetect.getEncode(bytes));
  }

  /// `java.downloadFile(url)` and `java.getFile(url)`.
  ///
  /// Returns the local path, because a JS value cannot be a file handle over
  /// the JSON bridge.
  Future<String> downloadFile(String url, [String? content]) async {
    final dir = await filePort.downloadDirectory();
    final path = '$dir/${_fileNameFor(url)}';
    final bytes = content != null
        ? Uint8List.fromList(utf8.encode(content))
        : await http.getBytes(url);
    await filePort.writeBytes(path, bytes);
    return path;
  }

  Future<String> getFile(String url) => downloadFile(url);

  /// `java.readFile(path)`. Returns the path when the file exists, empty when
  /// it does not — matching how a script probes for an optional asset.
  Future<String> readFile(String path) async {
    final bytes = await filePort.readBytes(path);
    return bytes == null ? '' : path;
  }

  Future<String> deleteFile(String path) async =>
      (await filePort.delete(path)) ? 'true' : 'false';

  Future<List<String>> getTxtInFolder(String directory) async {
    final files = await filePort.list(directory);
    return [
      for (final f in files)
        if (f.toLowerCase().endsWith('.txt')) f,
    ];
  }

  /// `java.unzipFile(path)` extracts a zip and returns the target directory.
  Future<String> unzipFile(String path) async {
    final bytes = await filePort.readBytes(path);
    if (bytes == null || bytes.isEmpty) {
      throw DomainError(
        code: 'archive_empty',
        stage: DomainErrorStage.request,
        message: '压缩文件不存在或为空: $path',
        recoverable: false,
      );
    }
    final outDir = await filePort.resolve('${_baseName(path)}_unzip');
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    for (final file in archive) {
      if (!file.isFile) continue;
      await filePort.writeBytes(
        '$outDir/${file.name}',
        Uint8List.fromList(file.content as List<int>),
      );
    }
    return outDir;
  }

  /// `java.unArchiveFile(path)` dispatches on the extension.
  Future<String> unArchiveFile(String path) async {
    final lower = path.toLowerCase();
    if (lower.endsWith('.zip')) return unzipFile(path);
    if (lower.endsWith('.7z')) throw _archiveUnsupported('7z', path);
    if (lower.endsWith('.rar')) throw _archiveUnsupported('rar', path);
    throw _archiveUnsupported(lower.split('.').last, path);
  }

  Future<String> un7zFile(String path) async =>
      throw _archiveUnsupported('7z', path);

  Future<String> unrarFile(String path) async =>
      throw _archiveUnsupported('rar', path);

  Future<Object?> getRarStringContent(
    String url,
    String path, [
    String? charset,
  ]) async => throw _archiveUnsupported('rar', path);

  Future<Object?> get7zStringContent(
    String url,
    String path, [
    String? charset,
  ]) async => throw _archiveUnsupported('7z', path);

  Future<Object?> getRarByteArrayContent(String url, String path) async =>
      throw _archiveUnsupported('rar', path);

  Future<Object?> get7zByteArrayContent(String url, String path) async =>
      throw _archiveUnsupported('7z', path);

  // ------------------------------------------------- host environment

  /// `java.getWebViewUA()`.
  String getWebViewUA() => hostEnvironment.userAgent();

  /// `java.openUrl(url[, mimeType])`.
  Future<bool> openUrl(String url, [String? mimeType]) =>
      hostEnvironment.openUrl(url, mimeType: mimeType);

  /// `java.openVideoPlayer(url, title[, isFloat])`.
  Future<bool> openVideoPlayer(
    String url,
    String title, [
    bool isFloat = false,
  ]) => hostEnvironment.openVideo(url, title, float: isFloat);

  /// `java.startBrowser(url, title[, html])`.
  Future<bool> startBrowser(String url, String title) async =>
      hostEnvironment.openUrl(url, mimeType: null);

  /// `java.startBrowserAwait(url, title[, refetch][, html])` — returns the body.
  Future<String> startBrowserAwait(
    String url,
    String title, [
    bool refetchAfterSuccess = false,
    String? html,
  ]) => hostEnvironment.startBrowser(
    url,
    title: title,
    refetchAfterSuccess: refetchAfterSuccess,
  );

  /// `java.getVerificationCode(imageUrl)`.
  Future<String> getVerificationCode(String imageUrl) =>
      hostEnvironment.verificationCode(imageUrl);

  /// `java.getReadBookConfig()` / `java.getReadBookConfigMap()`.
  String getReadBookConfig() => jsonEncode(hostEnvironment.readBookConfig());

  Map<String, Object?> getReadBookConfigMap() =>
      hostEnvironment.readBookConfig();

  /// `java.getThemeConfig()` / `java.getThemeConfigMap()`.
  String getThemeConfig() => jsonEncode(hostEnvironment.themeConfig());

  Map<String, Object?> getThemeConfigMap() => hostEnvironment.themeConfig();

  /// `java.getThemeMode()`.
  int getThemeMode() => hostEnvironment.themeMode();

  /// `java.ajaxTestAll(urlList, timeout)` — like `ajaxAll`, with a timeout.
  Future<List<StrResponse>> ajaxTestAll(
    List<String> urls, [
    int timeoutMs = 60000,
  ]) async {
    final out = <StrResponse>[];
    for (final url in urls) {
      try {
        final res = await ajax(url).timeout(Duration(milliseconds: timeoutMs));
        out.add(StrResponse(url: url, body: res ?? ''));
      } catch (e) {
        out.add(StrResponse(url: url, body: '', code: 500, error: e));
      }
    }
    return out;
  }

  /// `java.toURL(url, baseUrl)` resolves a possibly relative URL.
  String toURL(String url, [String? baseUrl]) {
    final direct = Uri.tryParse(url);
    if (direct != null && direct.hasScheme) return url;
    final base = baseUrl ?? this.baseUrl ?? source?.bookSourceUrl ?? '';
    if (base.isEmpty) return url;
    final parsed = Uri.tryParse(base);
    if (parsed == null) return url;
    return parsed.resolve(url).toString();
  }

  /// The `baseUrl` in scope, if the caller bound one.
  String? baseUrl;

  /// `java.getSource()` / `java.getTag()`.
  String getSource() => source?.bookSourceUrl ?? '';
  String getTag() => source?.bookSourceUrl ?? '';

  // ------------------------------------------------------------- font query

  /// Parsed font handles. Kept bounded because book-source scripts can run for
  /// the lifetime of the application and may return a fresh font per chapter.
  static const _fontRegistryCap = 32;
  static const _fontCacheCap = 8;
  final Map<String, FontQuery> _fonts = {};
  final Map<String, FontQuery> _fontCache = {};
  int _fontSeq = 0;
  int _fontCacheHits = 0;
  int _fontCacheMisses = 0;

  int get fontCacheHits => _fontCacheHits;
  int get fontCacheMisses => _fontCacheMisses;

  // ----------------------------------------------------------- byte handles

  /// 字节句柄注册表：`java.strToBytes` / `getByteArray` 把字节留在宿主侧，
  /// JS 拿到不透明句柄（JSON 桥无法传二进制），后续 `bytesToStr` /
  /// `queryTTF` 等消费方按句柄取回。与 `getElement`/`queryTTF` 同一模式。
  final Map<String, Uint8List> _byteHandles = {};
  int _byteSeq = 0;

  /// `java.strToBytes(s[, charset])` — 返回字节句柄。
  String strToBytes(String? s, [String? charset]) {
    final text = s ?? '';
    final bytes = (charset == null || charset.trim().isEmpty)
        ? Uint8List.fromList(utf8.encode(text))
        : Uint8List.fromList(CharsetDecoder.encode(text, charset));
    final handle = 'bytes${++_byteSeq}';
    _byteHandles[handle] = bytes;
    return handle;
  }

  /// `java.bytesToStr(handle[, charset])` — 句柄反解为文本。
  String bytesToStr(String? handle, [String? charset]) {
    final bytes = _byteHandles[handle ?? ''];
    if (bytes == null) return '';
    if (charset == null || charset.trim().isEmpty) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    return CharsetDecoder.decode(bytes, charset);
  }

  /// `java.getByteArray(url)` — 取网络字节存入注册表，返回句柄
  /// （对齐 legado `getByteArray(urlStr)` 返回 ByteArray 的用法）。
  Future<String> getByteArray(Object? url) async {
    final u = url?.toString() ?? '';
    if (u.isEmpty) return '';
    final bytes = await http.getBytes(u);
    final handle = 'bytes${++_byteSeq}';
    _byteHandles[handle] = bytes;
    return handle;
  }

  Uint8List? _resolveBytesHandle(Object? data) {
    if (data is Uint8List) return data;
    final text = data?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return _byteHandles[text];
  }

  Future<Uint8List?> _fontBytes(Object? data) async {
    if (data == null) return null;
    if (data is Uint8List) return data;
    // 字节句柄：strToBytes/getByteArray 的产物直接取回。
    final fromHandle = _resolveBytesHandle(data);
    if (fromHandle != null) return fromHandle;
    final text = data.toString().trim();
    if (text.isEmpty) return null;
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return http.getBytes(text);
    }
    try {
      return Uint8List.fromList(base64.decode(base64.normalize(text)));
    } catch (_) {
      // Not base64, so treat it as a local path handled by the file port.
      return filePort.readBytes(text);
    }
  }

  /// `java.queryTTF(data)` — accepts a URL, a local path, raw bytes or base64.
  ///
  /// Returns an opaque handle rather than an object, because the bridge is
  /// JSON-only; the prelude wraps it so a script still writes
  /// `java.replaceFont(text, errorFont, correctFont)`.
  Future<String> queryTTF(Object? data, [bool useCache = true]) async {
    final bytes = await _fontBytes(data);
    if (bytes == null || bytes.isEmpty) {
      throw DomainError(
        code: 'font_unreadable',
        stage: DomainErrorStage.render,
        message: '字体数据为空或无法读取',
        recoverable: false,
        suggestedAction: '检查字体地址是否可访问，或规则是否传入了正确的字体数据',
      );
    }
    final digest = sha256.convert(bytes).toString();
    FontQuery? parsed;
    if (useCache) {
      parsed = _fontCache.remove(digest);
      if (parsed != null) {
        _fontCache[digest] = parsed;
        _fontCacheHits++;
      } else {
        _fontCacheMisses++;
      }
    }
    parsed ??= FontQuery.parse(bytes);
    if (parsed == null) {
      throw DomainError(
        code: 'font_unsupported',
        stage: DomainErrorStage.render,
        message: '无法解析该字体（缺少 glyf/cmap 表，或为 CFF 轮廓）',
        recoverable: false,
        retryable: false,
        suggestedAction: '字体反爬目前只支持 TrueType 轮廓（glyf）',
      );
    }
    if (useCache && !_fontCache.containsKey(digest)) {
      if (_fontCache.length >= _fontCacheCap) {
        _fontCache.remove(_fontCache.keys.first);
      }
      _fontCache[digest] = parsed;
    }
    final handle = 'ttf${++_fontSeq}';
    _fonts[handle] = parsed;
    while (_fonts.length > _fontRegistryCap) {
      _fonts.remove(_fonts.keys.first);
    }
    return handle;
  }

  /// `java.queryBase64TTF(data)` — deprecated alias in Legado, kept for parity.
  Future<String> queryBase64TTF(String? data) => queryTTF(data);

  /// `java.replaceFont(text, errorQueryTTF, correctQueryTTF[, filter])`.
  ///
  /// Matches each character's glyph *outline* in the error font against the
  /// correct font, which is how a shuffled font is undone. [filter] drops
  /// characters whose outline does not exist in the error font.
  String replaceFont(
    String text,
    String? errorHandle,
    String? correctHandle, [
    bool filter = false,
  ]) {
    final error = _fonts[errorHandle];
    final correct = _fonts[correctHandle];
    if (error == null || correct == null) return text;
    final out = StringBuffer();
    for (final rune in text.runes) {
      if (FontQuery.isBlankUnicode(rune)) {
        out.writeCharCode(rune);
        continue;
      }
      if (filter && error.glyphIdByUnicode(rune) == 0) continue;
      final outline = error.glyfByUnicode(rune);
      final code = correct.unicodeByGlyf(outline);
      out.writeCharCode(code != 0 ? code : rune);
    }
    return out.toString();
  }

  Future<String> getZipStringContent(
    String url,
    String path, [
    String? charset,
  ]) async {
    final bytes = await getZipByteArrayContent(url, path);
    if (bytes == null || bytes.isEmpty) return '';
    if (charset != null && charset.trim().isNotEmpty) {
      return CharsetDecoder.decode(bytes, charset);
    }
    final data = Uint8List.fromList(bytes);
    return EncodingDetect.decode(data, EncodingDetect.getEncode(data));
  }

  Future<Uint8List?> getZipByteArrayContent(String url, String path) async {
    try {
      Uint8List bytes;
      if (url.toLowerCase().startsWith('http://') ||
          url.toLowerCase().startsWith('https://')) {
        bytes = await http.getBytes(url);
      } else {
        bytes = Uint8List.fromList(_asBytes(url));
      }
      if (bytes.isEmpty) return null;
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      for (final file in archive) {
        if (!file.isFile) continue;
        if (file.name == path || file.name.endsWith('/$path')) {
          return Uint8List.fromList(file.content as List<int>);
        }
      }
    } catch (e) {
      DebugLog.error('java.getZip', path, e);
    }
    return null;
  }

  Future<String> webViewGetSource(
    String? html,
    String? url,
    String? js,
    String sourceRegex,
  ) async {
    final sniffed = await _webViewOrSniff(
      html: html,
      url: url,
      js: js,
      regex: sourceRegex,
    );
    return sniffed;
  }

  Future<String> webViewGetOverrideUrl(
    String? html,
    String? url,
    String? js,
    String overrideUrlRegex,
  ) async {
    return _webViewOrSniff(
      html: html,
      url: url,
      js: js,
      regex: overrideUrlRegex,
    );
  }

  Future<String> _webViewOrSniff({
    required String? html,
    required String? url,
    required String? js,
    required String regex,
  }) async {
    final port = webViewPort;
    if (port != null) {
      try {
        final result = await port.run(
          WebViewRequest(
            url: url ?? '',
            html: html,
            javaScript: js,
            sourceRegex: regex,
          ),
        );
        if (result != null && result.body.trim().isNotEmpty) {
          return result.body;
        }
      } catch (e) {
        DebugLog.error('java.webViewGetSource', url ?? '', e);
      }
    }
    var body = html ?? '';
    if (body.isEmpty &&
        url != null &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      body = (await ajax(url)) ?? '';
    }
    return sniffResourceUrl(body, regex) ?? '';
  }

  Future<String> webView(String? html, String? url, String? js) async {
    final port = webViewPort;
    if (port == null) {
      DebugLog.error('java.missing.webView', 'WebViewPort not attached');
      return '';
    }
    try {
      final result = await port.run(
        WebViewRequest(url: url ?? '', html: html, javaScript: js),
      );
      return result?.body ?? '';
    } catch (e) {
      DebugLog.error('java.webView', 'webView', e);
      return '';
    }
  }

  String put(String key, String value) {
    _vars[key] = value;
    final ch = _chapter;
    final bk = _book;
    final rd = _ruleData;
    final src = _source;
    if (ch != null) {
      ch.putVariable(key, value);
    } else if (bk != null) {
      bk.putVariable(key, value);
    } else if (rd != null) {
      rd.put(key, value);
    } else {
      src?.put(key, value);
    }
    return value;
  }

  String get(String key) {
    if (key == 'bookName' && _book != null) return _book!.name;
    if (key == 'title' && _chapter != null) return _chapter!.title;
    final fromChapter = _chapter?.getVariable(key) ?? '';
    if (fromChapter.isNotEmpty) return fromChapter;
    final fromBook = _book?.getVariable(key) ?? '';
    if (fromBook.isNotEmpty) return fromBook;
    final fromRule = _ruleData?.get(key) ?? '';
    if (fromRule.isNotEmpty) return fromRule;
    final fromSource = _source?.get(key) ?? '';
    if (fromSource.isNotEmpty) return fromSource;
    return _vars[key] ?? '';
  }

  void log(Object? msg) {
    final text = msg?.toString() ?? '';
    DebugLog.log('java.log', text);
    if (EngineLimits.debugVerbose) {
      // ignore: avoid_print
      print('[java.log] $text');
    }
  }

  /// Dispatch a `java.*` call from a real JS runtime.
  Future<Object?> invoke(String name, List<Object?> args) async {
    switch (name) {
      case 'ajax':
        if (args.isEmpty) return '';
        return ajax(args.first!);
      case 'md5Encode':
        return md5Encode(_arg(args, 0));
      case 'md5Encode16':
        return md5Encode16(_arg(args, 0));
      case 'base64Encode':
      case 'base64EncodeStr':
        return base64EncodeStr(_arg(args, 0));
      case 'base64Decode':
      case 'base64DecodeStr':
        return base64DecodeStr(_arg(args, 0));
      case 'hexEncodeToString':
        return hexEncodeToString(_arg(args, 0));
      case 'hexDecodeToString':
        return hexDecodeToString(_arg(args, 0));
      case 'htmlFormatStr':
      case 'htmlFormat':
        return htmlFormatStr(_arg(args, 0));
      case 'getCookie':
        return getCookie(
          _arg(args, 0),
          args.length > 1 ? args[1]?.toString() : null,
        );
      case 'removeCookie':
        removeCookie(_arg(args, 0));
        return '';
      case 'timeFormat':
        final t = args.isNotEmpty && args[0] is num
            ? (args[0] as num).toInt()
            : int.tryParse(_arg(args, 0)) ?? 0;
        return timeFormat(t);
      case 'timeFormatUTC':
        final t = args.isNotEmpty && args[0] is num
            ? (args[0] as num).toInt()
            : int.tryParse(_arg(args, 0)) ?? 0;
        return timeFormatUTC(
          t,
          args.length > 1 ? _arg(args, 1) : 'yyyy-MM-dd HH:mm:ss',
          args.length > 2
              ? (args[2] is num
                    ? (args[2] as num).toInt()
                    : int.tryParse(_arg(args, 2)) ?? 0)
              : 0,
        );
      case 'put':
        if (args.length >= 2) {
          put(args[0].toString(), args[1].toString());
          return args[1];
        }
        return '';
      case 'get':
        if (args.length >= 2) {
          return httpGet(_arg(args, 0), args[1]);
        }
        return get(_arg(args, 0));
      case 'log':
      case 'toast':
        log(args.isEmpty ? '' : args[0]);
        return '';
      case 'sha256Encode':
        return sha256Encode(_arg(args, 0));
      case 'aesDecrypt':
        return aesDecryptStr(
          _arg(args, 0),
          _arg(args, 1),
          args.length > 2 ? args[2]?.toString() : null,
        );
      case 'ajaxAll':
        final urls = args.isEmpty
            ? const <String>[]
            : args.first is List
            ? (args.first as List).map((e) => e.toString()).toList()
            : args.map((e) => e.toString()).toList();
        final list = await ajaxAll(urls);
        return list.map(_toJsResponse).toList();
      case 'getString':
        return getString(_arg(args, 0));
      case 'getStringList':
        return getStringList(_arg(args, 0));
      case 'getElement':
        return getElement(_arg(args, 0));
      case 'getElements':
        return getElements(_arg(args, 0));
      case 'encodeURI':
        return encodeURI(
          _arg(args, 0),
          args.length > 1 ? args[1]?.toString() : null,
        );
      case 't2s':
        return t2s(_arg(args, 0));
      case 's2t':
        return s2t(_arg(args, 0));
      case 'randomUUID':
        return randomUUID();
      case 'toNumChapter':
        return toNumChapter(args.isEmpty ? null : args[0]?.toString());
      case 'cacheFile':
        final save = args.length > 1 && args[1] is num
            ? (args[1] as num).toInt()
            : int.tryParse(args.length > 1 ? _arg(args, 1) : '') ?? 0;
        return cacheFile(_arg(args, 0), save);
      case 'webView':
        return webView(
          args.isNotEmpty ? args[0]?.toString() : null,
          args.length > 1 ? args[1]?.toString() : null,
          args.length > 2 ? args[2]?.toString() : null,
        );
      case 'webViewGetSource':
        return webViewGetSource(
          args.isNotEmpty ? args[0]?.toString() : null,
          args.length > 1 ? args[1]?.toString() : null,
          args.length > 2 ? args[2]?.toString() : null,
          args.length > 3 ? _arg(args, 3) : '',
        );
      case 'webViewGetOverrideUrl':
        return webViewGetOverrideUrl(
          args.isNotEmpty ? args[0]?.toString() : null,
          args.length > 1 ? args[1]?.toString() : null,
          args.length > 2 ? args[2]?.toString() : null,
          args.length > 3 ? _arg(args, 3) : '',
        );
      case 'getZipStringContent':
        return getZipStringContent(
          _arg(args, 0),
          args.length > 1 ? _arg(args, 1) : '',
          args.length > 2 ? args[2]?.toString() : null,
        );
      case 'getZipByteArrayContent':
        final zip = await getZipByteArrayContent(
          _arg(args, 0),
          args.length > 1 ? _arg(args, 1) : '',
        );
        return zip == null ? '' : base64Encode(zip);
      case 'androidId':
        return androidId();
      case 'connect':
        return connect(_arg(args, 0), args.length > 1 ? args[1] : null);
      case 'post':
        return httpPost(
          _arg(args, 0),
          args.length > 1 ? args[1]?.toString() ?? '' : '',
          args.length > 2 ? args[2] : null,
        );
      case 'head':
        return httpHead(_arg(args, 0), args.length > 1 ? args[1] : null);
      case 'readTxtFile':
        return readTxtFile(
          _arg(args, 0),
          args.length > 1 ? args[1]?.toString() : null,
        );
      case 'readFile':
        return readFile(_arg(args, 0));
      case 'getFile':
        return getFile(_arg(args, 0));
      case 'downloadFile':
        return downloadFile(
          _arg(args, 0),
          args.length > 1 ? args[1]?.toString() : null,
        );
      case 'deleteFile':
        return deleteFile(_arg(args, 0));
      case 'getTxtInFolder':
        return getTxtInFolder(_arg(args, 0));
      case 'unzipFile':
        return unzipFile(_arg(args, 0));
      case 'unArchiveFile':
        return unArchiveFile(_arg(args, 0));
      case 'un7zFile':
        return un7zFile(_arg(args, 0));
      case 'unrarFile':
        return unrarFile(_arg(args, 0));
      case 'getRarStringContent':
        return getRarStringContent(
          _arg(args, 0),
          _arg(args, 1),
          args.length > 2 ? args[2]?.toString() : null,
        );
      case 'get7zStringContent':
        return get7zStringContent(
          _arg(args, 0),
          _arg(args, 1),
          args.length > 2 ? args[2]?.toString() : null,
        );
      case 'getRarByteArrayContent':
        return getRarByteArrayContent(_arg(args, 0), _arg(args, 1));
      case 'get7zByteArrayContent':
        return get7zByteArrayContent(_arg(args, 0), _arg(args, 1));
      case 'importScript':
        return readTxtFile(_arg(args, 0));
      case 'ajaxTestAll':
        final urls = args.isEmpty
            ? const <String>[]
            : args.first is List
            ? (args.first as List).map((e) => e.toString()).toList()
            : args.map((e) => e.toString()).toList();
        final list = await ajaxTestAll(
          urls,
          args.length > 1
              ? (args[1] is num ? (args[1] as num).toInt() : 60000)
              : 60000,
        );
        return list.map(_toJsResponse).toList();
      case 'openUrl':
        return openUrl(_arg(args, 0), args.length > 1 ? _arg(args, 1) : null);
      case 'openVideoPlayer':
        return openVideoPlayer(
          _arg(args, 0),
          _arg(args, 1),
          args.length > 2 && args[2] == true,
        );
      case 'startBrowser':
        return startBrowser(_arg(args, 0), _arg(args, 1));
      case 'startBrowserAwait':
        return startBrowserAwait(
          _arg(args, 0),
          _arg(args, 1),
          args.length > 2 && args[2] == true,
          args.length > 3 ? args[3]?.toString() : null,
        );
      case 'getVerificationCode':
        return getVerificationCode(_arg(args, 0));
      case 'queryTTF':
        return queryTTF(
          args.isEmpty ? null : args[0],
          args.length > 1 ? args[1] == true : true,
        );
      case 'strToBytes':
        return strToBytes(
          args.isEmpty ? null : _arg(args, 0),
          args.length > 1 ? args[1]?.toString() : null,
        );
      case 'bytesToStr':
        return bytesToStr(
          args.isEmpty ? null : _arg(args, 0),
          args.length > 1 ? args[1]?.toString() : null,
        );
      case 'getByteArray':
        return getByteArray(args.isEmpty ? null : args[0]);
      case 'queryBase64TTF':
        return queryBase64TTF(args.isEmpty ? null : _arg(args, 0));
      case 'replaceFont':
        // 字体反爬在真实 JS 引擎（invoke）与宽松解释器（invokeSync）两条
        // 路径都必须可用：此前只有 invokeSync 有分发，QuickJS 下会静默
        // 返回空串，正文被整段清空。
        return replaceFont(
          _arg(args, 0),
          args.length > 1 ? args[1]?.toString() : null,
          args.length > 2 ? args[2]?.toString() : null,
          args.length > 3 && args[3] == true,
        );
      default:
        DebugLog.error('java.missing.$name', name);
        return '';
    }
  }

  Object? invokeSync(String name, List<Object?> args) {
    switch (name) {
      case 'md5Encode':
        return md5Encode(_arg(args, 0));
      case 'md5Encode16':
        return md5Encode16(_arg(args, 0));
      case 'base64Encode':
      case 'base64EncodeStr':
        return base64EncodeStr(_arg(args, 0));
      case 'base64Decode':
      case 'base64DecodeStr':
        return base64DecodeStr(_arg(args, 0));
      case 'hexEncodeToString':
        return hexEncodeToString(_arg(args, 0));
      case 'hexDecodeToString':
        return hexDecodeToString(_arg(args, 0));
      case 'htmlFormatStr':
      case 'htmlFormat':
        return htmlFormatStr(_arg(args, 0));
      case 'getCookie':
        return getCookie(
          _arg(args, 0),
          args.length > 1 ? args[1]?.toString() : null,
        );
      case 'removeCookie':
        removeCookie(_arg(args, 0));
        return '';
      case 'timeFormat':
        final t = args.isNotEmpty && args[0] is num
            ? (args[0] as num).toInt()
            : int.tryParse(_arg(args, 0)) ?? 0;
        return timeFormat(t);
      case 'timeFormatUTC':
        final t = args.isNotEmpty && args[0] is num
            ? (args[0] as num).toInt()
            : int.tryParse(_arg(args, 0)) ?? 0;
        return timeFormatUTC(
          t,
          args.length > 1 ? _arg(args, 1) : 'yyyy-MM-dd HH:mm:ss',
          args.length > 2
              ? (args[2] is num
                    ? (args[2] as num).toInt()
                    : int.tryParse(_arg(args, 2)) ?? 0)
              : 0,
        );
      case 'put':
        if (args.length >= 2) {
          put(args[0].toString(), args[1].toString());
          return args[1];
        }
        return '';
      case 'get':
        if (args.length >= 2) return null;
        return get(_arg(args, 0));
      case 'log':
      case 'toast':
        log(args.isEmpty ? '' : args[0]);
        return '';
      case 'sha256Encode':
        return sha256Encode(_arg(args, 0));
      case 'aesDecrypt':
        return aesDecryptStr(
          _arg(args, 0),
          _arg(args, 1),
          args.length > 2 ? args[2]?.toString() : null,
        );
      case 'encodeURI':
        return encodeURI(
          _arg(args, 0),
          args.length > 1 ? args[1]?.toString() : null,
        );
      case 't2s':
        return t2s(_arg(args, 0));
      case 's2t':
        return s2t(_arg(args, 0));
      case 'randomUUID':
        return randomUUID();
      case 'toNumChapter':
        return toNumChapter(args.isEmpty ? null : args[0]?.toString());
      case 'androidId':
        return androidId();
      case 'digestHex':
        return JsCrypto.digestHex(_arg(args, 0), _arg(args, 1));
      case 'digestBase64Str':
        return JsCrypto.digestBase64(_arg(args, 0), _arg(args, 1));
      case 'HMacHex':
        return JsCrypto.hmacHex(_arg(args, 0), _arg(args, 1), _arg(args, 2));
      case 'HMacBase64':
        return JsCrypto.hmacBase64(_arg(args, 0), _arg(args, 1), _arg(args, 2));
      // Single entry point for createSymmetricCrypto and the flat
      // aes*/des*/tripleDES* helpers. The JS side owns the argument shuffling
      // (see the prelude), so only one host case is needed.
      case 'symmetricCrypto':
        return JsCrypto.symmetric(
          transformation: _arg(args, 0),
          key: _arg(args, 1),
          iv: args.length > 2 ? args[2]?.toString() : null,
          data: _arg(args, 3),
          operation: _arg(args, 4),
          keyIsBase64: args.length > 5 && args[5] == true,
          ivIsBase64: args.length > 6 && args[6] == true,
        );
      case 'cachePut':
        return cachePut(
          _arg(args, 0),
          _arg(args, 1),
          args.length > 2 && args[2] != null
              ? (args[2] is num
                    ? (args[2] as num).toInt()
                    : int.tryParse(args[2].toString()) ?? 0)
              : 0,
        );
      case 'cachePutMemory':
        return cachePutMemory(_arg(args, 0), _arg(args, 1));
      case 'cacheGet':
        // 第二参是 onlyDisk 布尔量，不是默认值（CacheManager.kt:98）。
        return cacheGet(_arg(args, 0), args.length > 1 ? args[1] : null);
      case 'cacheGetFromMemory':
        return cacheGetFromMemory(_arg(args, 0));
      case 'cacheGetInt':
        return cacheGetInt(_arg(args, 0));
      case 'cacheGetDouble':
        return cacheGetDouble(_arg(args, 0));
      case 'cacheDelete':
        return cacheDelete(_arg(args, 0));
      case 'cacheDeleteMemory':
        return cacheDeleteMemory(_arg(args, 0));
      // java.getElement(rule).select(...) / .children() / .parent() 一族的同步回落。
      // 门面把 text/attr/html 都装在描述符里，只有「继续下钻」需要回来问一次。
      case 'elementOp':
        return elementOp(
          args.isEmpty ? null : args[0],
          args.length > 1 ? _arg(args, 1) : '',
          args.length > 2 ? args[2] : null,
        );
      case 'getWebViewUA':
        return getWebViewUA();
      case 'toURL':
        return toURL(_arg(args, 0), args.length > 1 ? _arg(args, 1) : null);
      case 'getSource':
        return getSource();
      case 'getTag':
        return getTag();
      case 'getReadBookConfig':
        return getReadBookConfig();
      // The Map variants are returned as JSON text because the bridge hands
      // `invokeSync` results back as strings; the prelude parses them.
      case 'getReadBookConfigMap':
        return getReadBookConfig();
      case 'getThemeConfig':
        return getThemeConfig();
      case 'getThemeConfigMap':
        return getThemeConfig();
      case 'getThemeMode':
        return getThemeMode();
      case 'longToast':
      case 'logType':
        log(args.isEmpty ? '' : args[0]);
        return '';
      case 'replaceFont':
        return replaceFont(
          _arg(args, 0),
          args.length > 1 ? args[1]?.toString() : null,
          args.length > 2 ? args[2]?.toString() : null,
          args.length > 3 && args[3] == true,
        );
      case 'strToBytes':
        return strToBytes(
          args.isEmpty ? null : _arg(args, 0),
          args.length > 1 ? args[1]?.toString() : null,
        );
      case 'bytesToStr':
        return bytesToStr(
          args.isEmpty ? null : _arg(args, 0),
          args.length > 1 ? args[1]?.toString() : null,
        );
      case 'getByteArray':
        // invokeSync 无异步网络能力：与 legado 一致此处返回空句柄，
        // 真实取字节走 invoke（QuickJS 会话）。
        return '';
      default:
        return '';
    }
  }

  static String _arg(List<Object?> args, int i) =>
      i < args.length ? args[i]?.toString() ?? '' : '';

  String sha256Encode(String str) =>
      sha256.convert(utf8.encode(str)).toString();

  Uint8List aesDecrypt(Uint8List data, Uint8List key, {Uint8List? iv}) {
    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv ?? Uint8List(16)));
    final out = Uint8List(data.length);
    var offset = 0;
    while (offset < data.length) {
      offset += cipher.processBlock(data, offset, out, offset);
    }
    return out;
  }

  List<int> _asBytes(String s) {
    final t = s.trim();
    try {
      return base64.decode(t.replaceAll(RegExp(r'\s+'), ''));
    } catch (_) {}
    if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(t) && t.length % 2 == 0) {
      final bytes = <int>[];
      for (var i = 0; i + 1 < t.length; i += 2) {
        bytes.add(int.parse(t.substring(i, i + 2), radix: 16));
      }
      return bytes;
    }
    return utf8.encode(s);
  }

  Uint8List _asAesKey(String key) {
    final utf = utf8.encode(key);
    if (utf.length == 16 || utf.length == 24 || utf.length == 32) {
      return Uint8List.fromList(utf);
    }
    var raw = _asBytes(key);
    if (raw.length == 16 || raw.length == 24 || raw.length == 32) {
      return Uint8List.fromList(raw);
    }
    if (raw.length > 32) raw = raw.sublist(0, 32);
    final n = raw.length <= 16
        ? 16
        : raw.length <= 24
        ? 24
        : 32;
    final out = Uint8List(n);
    out.setRange(0, raw.length, raw);
    return out;
  }

  Uint8List _blockAlign(Uint8List data) {
    if (data.length % 16 == 0) return data;
    final n = (data.length + 15) ~/ 16 * 16;
    final out = Uint8List(n);
    out.setAll(0, data);
    return out;
  }

  Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final pad = data.last;
    if (pad < 1 || pad > 16 || pad > data.length) return data;
    for (var i = data.length - pad; i < data.length; i++) {
      if (data[i] != pad) return data;
    }
    return data.sublist(0, data.length - pad);
  }
}

class _CacheEntry {
  _CacheEntry(this.body, this.until);
  final String body;
  final DateTime until;
}

/// A `cache.*` entry in the in-process stand-in for Legado's Room tier.
///
/// `deadline == null` means "never expires", matching `CacheManager.put`'s
/// `saveTime == 0` branch (`CacheManager.kt:59-60`).
class _DiskCacheEntry {
  _DiskCacheEntry(this.body, this.deadline);
  final String body;
  final DateTime? deadline;
}

String _fullToHalf(String input) {
  final b = StringBuffer();
  for (final r in input.runes) {
    if (r == 12288) {
      b.write(' ');
      continue;
    }
    if (r >= 65281 && r <= 65374) {
      b.writeCharCode(r - 65248);
      continue;
    }
    b.writeCharCode(r);
  }
  return b.toString();
}

int _stringToInt(String str) {
  final num = _fullToHalf(str).replaceAll(RegExp(r'\s+'), '');
  return int.tryParse(num) ?? _chineseNumToInt(num);
}

const _chnDigits = {
  '零': 0,
  '〇': 0,
  '一': 1,
  '二': 2,
  '两': 2,
  '兩': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '七': 7,
  '八': 8,
  '九': 9,
  '壹': 1,
  '贰': 2,
  '貳': 2,
  '叁': 3,
  '肆': 4,
  '伍': 5,
  '陆': 6,
  '陸': 6,
  '柒': 7,
  '捌': 8,
  '玖': 9,
};

const _chnUnits = {
  '十': 10,
  '拾': 10,
  '百': 100,
  '佰': 100,
  '千': 1000,
  '仟': 1000,
  '万': 10000,
  '萬': 10000,
};

int _chineseNumToInt(String chNum) {
  if (chNum.isEmpty) return -1;
  final chars = [for (final r in chNum.runes) String.fromCharCode(r)];
  if (chars.isNotEmpty && chars.every((c) => _chnDigits.containsKey(c))) {
    final b = StringBuffer();
    for (final c in chars) {
      b.write(_chnDigits[c]);
    }
    return int.tryParse(b.toString()) ?? -1;
  }
  var result = 0;
  var tmp = 0;
  for (var i = 0; i < chars.length; i++) {
    final ch = chars[i];
    final unit = _chnUnits[ch];
    final digit = _chnDigits[ch];
    if (unit != null) {
      if (tmp == 0) tmp = 1;
      result += tmp * unit;
      tmp = 0;
    } else if (digit != null) {
      tmp = tmp * 10 + digit;
    } else {
      return -1;
    }
  }
  return result + tmp;
}
