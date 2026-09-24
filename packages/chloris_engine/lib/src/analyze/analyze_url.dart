import 'dart:convert';

import '../constants/constants.dart';
import '../debug/debug_log.dart';
import '../js/java_host.dart';
import '../js/js_host_bridge.dart';
import '../js/js_runtime.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../models/domain_protocol.dart';
import '../net/cookie_store.dart';
import '../net/engine_limits.dart';
import '../net/http_port.dart';
import '../net/network_utils.dart';
import '../net/rate_limiter.dart';
import '../net/str_response.dart';
import '../net/web_view_port.dart';
import 'analyze_rule.dart';
import 'rule_data.dart';

class UrlOption {
  UrlOption({
    this.method,
    this.charset,
    this.headers,
    this.body,
    this.retry,
    this.type,
    this.webView = false,
    this.webJs,
    this.js,
    this.bodyJs,
    this.origin,
    this.dnsIp,
    this.serverID,
    this.webViewDelayTime,
    this.proxy,
  });

  String? method;
  String? charset;
  Map<String, String>? headers;
  String? body;
  int? retry;
  String? type;
  bool webView = false;
  String? webJs;
  String? js;
  String? bodyJs;
  String? origin;
  String? dnsIp;
  String? serverID;
  int? webViewDelayTime;
  String? proxy;

  factory UrlOption.fromJson(Map<String, dynamic> json) {
    Map<String, String>? headers;
    final raw = json['headers'];
    if (raw is Map) {
      headers = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          headers = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      } catch (_) {}
    }
    String? body;
    final b = json['body'];
    if (b is String) {
      body = b;
    } else if (b != null) {
      body = jsonEncode(b);
    }
    return UrlOption(
      method: json['method']?.toString(),
      charset: json['charset']?.toString(),
      headers: headers,
      body: body,
      retry: json['retry'] is num ? (json['retry'] as num).toInt() : null,
      type: json['type']?.toString(),
      webView: json['webView'] == true || json['webView'] == 'true',
      webJs: json['webJs']?.toString(),
      js: json['js']?.toString(),
      bodyJs: json['bodyJs']?.toString(),
      origin: json['origin']?.toString(),
      dnsIp: json['dnsIp']?.toString(),
      serverID: json['serverID']?.toString(),
      webViewDelayTime: json['webViewDelayTime'] is num
          ? (json['webViewDelayTime'] as num).toInt()
          : int.tryParse(json['webViewDelayTime']?.toString() ?? ''),
      proxy: json['proxy']?.toString(),
    );
  }
}

class AnalyzeUrl {
  AnalyzeUrl({
    required this.mUrl,
    required this.http,
    required this.jsRuntime,
    this.key,
    this.page,
    this.baseUrl = '',
    this.source,
    this.ruleData,
    this.chapter,
    this.book,
    this.cookieStore,
    this.javaHost,
    this.webViewPort,
    this.allowInteractiveLogin = false,
    this.timeout,
    Map<String, String>? headerMapF,
  }) {
    if (headerMapF != null) headerMap.addAll(headerMapF);
    javaHost?.bindContext(
      jsRuntime: jsRuntime,
      source: source,
      book: book,
      chapter: chapter,
      ruleData: ruleData,
      webViewPort: webViewPort,
    );
  }

  final String mUrl;
  final HttpPort http;
  final JsRuntime jsRuntime;
  final String? key;
  final int? page;
  String baseUrl;
  final BookSource? source;
  final RuleData? ruleData;
  final BookChapter? chapter;
  final Book? book;
  final CookieStore? cookieStore;
  final JavaHost? javaHost;
  final WebViewPort? webViewPort;
  final bool allowInteractiveLogin;
  final Duration? timeout;
  bool _askedInteractive = false;

  final headerMap = <String, String>{};
  String ruleUrl = '';
  String url = '';
  String? body;
  String method = 'GET';
  String? charset;
  int retry = 0;
  bool useWebView = false;
  String? webJs;
  String? bodyJs;
  String? type;
  String? origin;
  String? dnsIp;
  String? serverID;
  int? webViewDelayTime;
  String? proxy;

  late final RateLimiter _limiter = RateLimiter.shared(
    source?.bookSourceUrl,
    source?.concurrentRate,
  );

  // 对齐 Legado-E CookieManager.mergeCookiesToMap（CookieManager.kt:101-107）：
  // 后者 putAll 前者，因此后传入的规则 Cookie 在键冲突时覆盖 jar Cookie。
  String? _mergeCookie(String jar, String rule) {
    final map = <String, String>{};
    for (final part in jar.split(';')) {
      final eq = part.indexOf('=');
      if (eq > 0) map[part.substring(0, eq).trim()] = part.substring(eq + 1).trim();
    }
    for (final part in rule.split(';')) {
      final eq = part.indexOf('=');
      if (eq > 0) map[part.substring(0, eq).trim()] = part.substring(eq + 1).trim();
    }
    if (map.isEmpty) return null;
    return map.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<void> init() async {
    ruleUrl = mUrl;
    await _analyzeJs();
    _peekUrlOption();
    await _replaceKeyPageJs();
    await _analyzeUrl();
    // 只有「本该是 http 却没解析出来」才尝试用宽松解释器补救。
    // `data:` URI 是合法的一等形态（见 getStrResponse 的字节通道），不能走这里 ——
    // 否则会被当成解析失败，进而触发一段与它无关的 JS 求值。
    final scheme = url.toLowerCase();
    if (!scheme.startsWith('http') && !scheme.startsWith('data:')) {
      final recovered = LenientJsRuntime.interpretJs(
        mUrl,
        JsScope(
          variables: {
            'result': mUrl,
            'baseUrl': baseUrl,
            'key': key ?? '',
            'page': page ?? 1,
            'java': javaHost,
          },
        ),
      )?.toString();
      if (recovered != null && recovered.toLowerCase().startsWith('http')) {
        url = recovered;
      }
    }
    // 对齐 Legado-E AnalyzeUrl.kt:703-725 + CookieManager.mergeCookies：
    // 请求 Cookie = 规则 Cookie（已通过 opt.headers / source.header 进入 headerMap）覆盖 jar Cookie。
    // 仅当 jar 非空时合并，规则一方后 putAll 因而胜出；enabledCookieJar==false 时 jar 为空、
    // 不被合并，规则里写的 Cookie 仍按原样随请求发送（与 Legado 一致）。
    if (cookieStore != null && source != null) {
      final jar = cookieStore!.get(source!.bookSourceUrl);
      if (jar.isNotEmpty) {
        final rule = headerMap['Cookie'] ?? '';
        final merged = _mergeCookie(jar, rule);
        if (merged != null) headerMap['Cookie'] = merged;
      }
    }
  }

  /// `isTest` / `skipRateLimit` 对齐 Legado-E `AnalyzeUrl.kt:415-433,516-536`。
  ///
  /// * `skipRateLimit`：旁路限速（源检查器用），Legado 用同一个开关。
  /// * `isTest`：**不抛异常**，而是把网络异常折叠成一个带负错误码的响应，
  ///   码值与 Legado 一一对应（见 [_testErrorCode]）。非测试模式下异常照常上抛。
  Future<StrResponse> getStrResponse({
    String? jsStr,
    String? sourceRegex,
    bool isTest = false,
    bool skipRateLimit = false,
  }) {
    return _getStrResponse(
      jsStr: jsStr,
      sourceRegex: sourceRegex,
      isTest: isTest,
      skipRateLimit: skipRateLimit,
    );
  }

  Future<StrResponse> _getStrResponse({
    String? jsStr,
    String? sourceRegex,
    required bool isTest,
    required bool skipRateLimit,
  }) async {
    await init();
    final tag = source?.bookSourceUrl ?? url;
    // `data:` URI 走字节通道（Legado AnalyzeUrl.kt:634-645 的 getByteArrayIfDataUri），
    // 它由 `type` 选项启用，所以只在那条分支里放行。
    final isDataUri = url.toLowerCase().startsWith('data:');
    if (isDataUri) {
      if (type == null || type!.trim().isEmpty) {
        // Legado 只在字节通道里识别 data: URI；走普通请求路径会在 okhttp 上
        // 抛「unknown protocol: data」。这里给出明确原因，而不是让它变成一个
        // 看不清来路的底层异常。
        throw StateError('data: URI 需要配合 type 选项才能解析: $url');
      }
    } else if (!url.toLowerCase().startsWith('http://') &&
        !url.toLowerCase().startsWith('https://')) {
      // 非 http(s) 的自定义 scheme（书旗的 qb://、某些源的 local://）会一路走到
      // dart:io 的 HttpClient，在那里变成一句
      // 「Bad state: Invalid argument(s): Unsupported scheme 'qb' in URI …」——
      // 用户既看不懂，也不知道该去换源。这里在入口就讲清楚。
      final scheme = Uri.tryParse(url)?.scheme ?? '';
      DebugLog.error(tag, '不支持的请求协议: $mUrl');
      throw StateError(
        '该章节使用的是自定义协议「${scheme.isEmpty ? url.substring(0, url.length.clamp(0, 24)) : scheme}://」，'
        '当前网络层只能请求 http/https。请换源。',
      );
    }
    // Legado's `type` option switches the response path to bytes and exposes
    // a hexadecimal string to rule evaluators.
    if (type != null && type!.trim().isNotEmpty) {
      final dataBytes = _decodeDataUri(url);
      if (dataBytes != null) {
        // 对齐 Legado-E AnalyzeUrl.kt:424-426：data: URI 直接解出字节再转 hex，
        // 不发请求、也不受限速与 Cookie 约束。
        return StrResponse(
          url: url,
          body: _hex(dataBytes),
          code: 200,
          headers: const {},
        );
      }
      final bytes = await http.getBytes(url, headers: headerMap);
      return StrResponse(
        url: url,
        body: _hex(bytes),
        code: 200,
        headers: const {},
      );
    }
    // 对齐 Legado-E AnalyzeUrl.kt:427-432：skipRateLimit 时直接执行，不等限速。
    if (!skipRateLimit) await _limiter.acquire();
    if (headerMap['User-Agent'] == null) {
      headerMap['User-Agent'] =
          EngineLimits.userAgent ??
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36';
    }
    if (headerMap['Accept'] == null) {
      headerMap['Accept'] =
          'text/html,application/json,application/xhtml+xml,*/*;q=0.8';
    }
    if (headerMap['Referer'] == null && baseUrl.isNotEmpty) {
      headerMap['Referer'] = baseUrl;
    }
    DebugLog.log(tag, '$method $url', phase: 'http');
    late StrResponse res;
    try {
      res = await _sendCurrent();
    } catch (e) {
      DebugLog.error(tag, '$method $url', e);
      final recovered = await _loginCheckOnError(e);
      if (recovered != null) return recovered;
      if (!isTest) rethrow;
      // 对齐 Legado-E AnalyzeUrl.kt:516-536：测试模式不抛异常，改为回一个带负
      // 错误码的响应，让源检查界面能显示「是超时还是域名不存在」。
      return StrResponse(
        url: url,
        body: e.toString(),
        callTime: _testErrorCode(e),
      );
    }
    // 对齐 Legado-E AnalyzeUrl.kt:507-510：bodyJs 作用于响应 body，而非请求 body。
    if (bodyJs != null && bodyJs!.trim().isNotEmpty && !useWebView) {
      final evaluated = await _evalJs(bodyJs!, res.body ?? '');
      if (evaluated != null) {
        res = StrResponse(
          url: res.url,
          body: evaluated.toString(),
          code: res.code,
          headers: res.headers,
        );
      }
    }
    if (res.code >= 500) {
      // HttpPort implementations may return a response object for transport
      // errors. Never feed a server error document into rule extraction.
      if (isTest) {
        return StrResponse(url: url, body: 'HTTP ${res.code} $url', callTime: -7);
      }
      throw StateError('HTTP ${res.code} $url');
    }
    DebugLog.log(
      tag,
      '≡获取成功:$url ${res.code} ${res.body?.length ?? 0}B',
      state: 1,
      phase: 'http',
    );
    if (source?.enabledCookieJar == true && cookieStore != null) {
      cookieStore!.mergeSetCookie(
        source!.bookSourceUrl,
        res.headers['set-cookie'] ?? res.headers['Set-Cookie'],
      );
    }
    var out = await _applyRealWebView(res, jsStr, sourceRegex);
    if (identical(out, res)) {
      out = _applyWebViewSniff(res, sourceRegex);
      final postJs = (jsStr ?? webJs)?.trim();
      if (postJs != null && postJs.isNotEmpty && out.body != null) {
        final eval = await _evalJs(postJs, out.body);
        final next = _asResponseBody(eval, out);
        if (next != null) out = next;
      }
    }
    out = await _applyLoginCheck(out);
    if (allowInteractiveLogin &&
        !_askedInteractive &&
        webViewPort != null &&
        (source?.loginUrl ?? '').trim().isNotEmpty &&
        looksLikeLoginWall(out.body)) {
      _askedInteractive = true;
      final session = await webViewPort!.run(
        WebViewRequest(
          url: source!.loginUrl!,
          headers: headerMap,
          interactive: true,
          title: source!.bookSourceName,
        ),
      );
      if (session != null) {
        if ((session.cookie ?? '').isNotEmpty && cookieStore != null) {
          cookieStore!.set(source!.bookSourceUrl, session.cookie!);
          cookieStore!.set(source!.loginUrl!, session.cookie!);
        }
        if (session.body.isNotEmpty) {
          out = StrResponse(
            url: session.url,
            body: session.body,
            code: out.code,
            headers: out.headers,
          );
        } else {
          try {
            out = await _sendCurrent();
          } catch (_) {}
        }
      }
    }
    return out;
  }

  Future<StrResponse> _applyRealWebView(
    StrResponse res,
    String? jsStr,
    String? sourceRegex,
  ) async {
    final port = webViewPort;
    if (port == null) return res;
    final want =
        useWebView ||
        (sourceRegex != null && sourceRegex.trim().isNotEmpty) ||
        ((jsStr ?? webJs)?.contains('document.') ?? false);
    if (!want) return res;
    try {
      final delay = webViewDelayTime ?? 0;
      if (delay > 0) {
        await Future<void>.delayed(
          Duration(milliseconds: delay.clamp(0, 10000)),
        );
      }
      final result = await port.run(
        WebViewRequest(
          url: url,
          html: res.body,
          javaScript: (jsStr ?? webJs)?.trim().isNotEmpty == true
              ? (jsStr ?? webJs)
              : 'document.documentElement.outerHTML',
          sourceRegex: sourceRegex,
          headers: headerMap,
        ),
      );
      if (result == null || result.body.isEmpty) return res;
      if ((result.cookie ?? '').isNotEmpty &&
          cookieStore != null &&
          source != null) {
        cookieStore!.set(source!.bookSourceUrl, result.cookie!);
      }
      return StrResponse(
        url: result.url.isEmpty ? res.url : result.url,
        body: result.body,
        code: res.code,
        headers: res.headers,
      );
    } catch (e) {
      DebugLog.error(source?.bookSourceUrl ?? url, 'webView', e);
      return res;
    }
  }

  Future<StrResponse> _sendCurrent() {
    var requestBody = body;
    final contentType = headerMap.entries
        .firstWhere(
          (e) => e.key.toLowerCase() == 'content-type',
          orElse: () => const MapEntry('', ''),
        )
        .value
        .toLowerCase();
    if (requestBody != null &&
        contentType.contains('application/x-www-form-urlencoded')) {
      requestBody = _encodeForm(requestBody);
    }
    return http.send(
      HttpRequestSpec(
        url: url,
        method: method,
        headers: headerMap,
        body: requestBody,
        charset: charset,
        retry: retry,
        timeout: timeout ?? EngineLimits.httpTimeout,
        origin: origin,
        dnsIp: dnsIp,
        serverID: serverID,
        proxy: proxy,
      ),
    );
  }

  String _encodeForm(String raw) {
    return raw
        .split('&')
        .map((pair) {
          final eq = pair.indexOf('=');
          if (eq < 0) return Uri.encodeQueryComponent(pair);
          final key = pair.substring(0, eq);
          final value = pair.substring(eq + 1);
          String encode(String value) =>
              RegExp(r'%[0-9A-Fa-f]{2}').hasMatch(value)
              ? value
              : Uri.encodeQueryComponent(value);
          return '${encode(key)}=${encode(value)}';
        })
        .join('&');
  }

  String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// 对齐 Legado-E `AppPattern.dataUriRegex = ^data:.*?;base64,(.*)`
  /// （`AppPattern.kt:20`）与 `AnalyzeUrl.kt:634-645`。
  ///
  /// 只在形如 `data:<mime>;base64,<payload>` 时返回字节；其它形态（例如不带
  /// `;base64,` 的明文 data URI）返回 `null`，由调用方走正常请求路径 —— 与
  /// Legado 的「匹配不到就返回 null」一致，不擅自扩展。
  static List<int>? _decodeDataUri(String raw) {
    if (!raw.toLowerCase().startsWith('data:')) return null;
    final m = RegExp(r'^data:.*?;base64,(.*)', dotAll: true).firstMatch(raw);
    if (m == null) return null;
    final payload = m.group(1) ?? '';
    if (payload.isEmpty) return null;
    try {
      return base64.decode(payload);
    } catch (_) {
      // 非法 base64：对 Legado 而言这是异常路径（Base64.decode 会抛），
      // 这里退化为「不是 data URI」，让调用方报出真实的网络错误而不是静默空。
      return null;
    }
  }

  /// 测试模式下的负错误码。
  ///
  /// 码值与顺序对齐 `AnalyzeUrl.kt:520-532`，但**判定方式必须换**：Java 与 Dart
  /// 的异常类型不是一一对应的，照抄 `is SocketTimeoutException` 这种类型判断在
  /// Dart 侧编译都过不了。
  ///
  /// 另外这里**不能**用 `SocketException` 之类的类型判断：`chloris_engine` 同时
  /// 要编到 Web，`analyze_url.dart` 引入 `dart:io` 会直接打断 Web 构建。所以按
  /// 消息特征判定 —— 平台的网络层抛错本来就带这些特征串。
  ///
  /// | Legado 分支 | Legado 码 | 本实现判据 |
  /// |---|---|---|
  /// | `InterruptedIOException` 含 "timeout" | -1 超过设定时间 | 含 `TimeoutException` |
  /// | `SocketTimeoutException` | -2 超时 | 含 `timed out` |
  /// | `UnknownHostException` | -3 未找到域名 | 含 `Failed host lookup` / `UnknownHost` |
  /// | `ConnectException` | -4 连接被拒 | 含 `Connection refused` |
  /// | `SocketException` | -5 Socket 错误 | 含 `SocketException` / `Connection reset` |
  /// | `SSLException` | -6 SSL/握手 | 含 `HandshakeException` / `SSL` |
  /// | 其它 | -7 | 其它 |
  static int _testErrorCode(Object error) {
    final text = error.toString();
    if (text.contains('TimeoutException')) return -1;
    if (text.contains('timed out')) return -2;
    if (text.contains('Failed host lookup') || text.contains('UnknownHost')) {
      return -3;
    }
    if (text.contains('Connection refused')) return -4;
    if (text.contains('SocketException') ||
        text.contains('Connection reset')) {
      return -5;
    }
    if (text.contains('HandshakeException') ||
        text.contains('SSL') ||
        text.contains('TlsException')) {
      return -6;
    }
    return -7;
  }

  StrResponse _applyWebViewSniff(StrResponse res, String? sourceRegex) {
    final regex = (sourceRegex ?? '').trim();
    if (regex.isEmpty && !useWebView) return res;
    final html = res.body ?? '';
    if (html.isEmpty) return res;
    if (regex.isNotEmpty) {
      final sniffed = sniffResourceUrl(html, regex);
      if (sniffed != null) {
        DebugLog.log(
          source?.bookSourceUrl ?? url,
          'webView sniff $sniffed',
          phase: 'http',
        );
        return StrResponse(
          url: res.url,
          body: sniffed,
          code: res.code,
          headers: res.headers,
        );
      }
    }
    return res;
  }

  Future<StrResponse> _applyLoginCheck(StrResponse out) async {
    final checkJs = source?.loginCheckJs?.trim();
    if (checkJs == null || checkJs.isEmpty) return out;
    try {
      final eval = await _evalJs(checkJs, {
        'body': out.body,
        'url': out.url,
        'code': out.code,
        'headers': out.headers,
      });
      final next = await _resolveLoginResult(eval, out);
      return next ?? out;
    } catch (e) {
      DebugLog.error(source?.bookSourceUrl ?? url, 'loginCheckJs', e);
      return out;
    }
  }

  Future<StrResponse?> _loginCheckOnError(Object error) async {
    final checkJs = source?.loginCheckJs?.trim();
    if (checkJs == null || checkJs.isEmpty) return null;
    try {
      final eval = await _evalJs(checkJs, {
        'body': error.toString(),
        'url': url,
        'code': 500,
        'headers': const <String, String>{},
      });
      return _resolveLoginResult(
        eval,
        StrResponse(url: url, body: error.toString(), code: 500),
      );
    } catch (_) {
      return null;
    }
  }

  Future<StrResponse?> _resolveLoginResult(
    Object? eval,
    StrResponse current,
  ) async {
    if (eval == null) return null;
    if (eval is StrResponse) return eval;
    if (eval is Map) {
      final body = eval['body']?.toString();
      final nextUrl = eval['url']?.toString();
      final nextCode = eval['code'] is num
          ? (eval['code'] as num).toInt()
          : current.code;
      // JS engines differ in how they expose a returned StrResponse.  A
      // plain object is the common dartified form; preserve it when only the
      // URL/code changed as well as when the body changed.
      if (body != null &&
          (body != current.body ||
              nextUrl != null && nextUrl != current.url ||
              nextCode != current.code)) {
        return StrResponse(
          url: nextUrl ?? current.url,
          body: body,
          code: nextCode,
          headers: eval['headers'] is Map
              ? (eval['headers'] as Map).map(
                  (k, v) => MapEntry(k.toString(), v.toString()),
                )
              : current.headers,
        );
      }
      return null;
    }
    final text = eval.toString();
    // QuickJS stringifies a returned JavaScript response object as
    // "[object Object]".  Treat that as the unchanged response; otherwise a
    // loginCheckJs of `else result` would replace the real HTML with this
    // marker and make every search appear empty.
    if (text.isEmpty ||
        text == current.body ||
        text == '[object Object]' ||
        text == 'undefined' ||
        text == 'null') {
      return null;
    }
    if (text.startsWith('http://') || text.startsWith('https://')) {
      if (text == current.url) return null;
      try {
        final again = await http.send(
          HttpRequestSpec(
            url: text,
            method: 'GET',
            headers: headerMap,
            timeout: timeout ?? EngineLimits.httpTimeout,
          ),
        );
        return again;
      } catch (e) {
        DebugLog.error(source?.bookSourceUrl ?? url, 'loginCheckJs retry', e);
        return StrResponse(url: text, body: text, code: current.code);
      }
    }
    return StrResponse(
      url: current.url,
      body: text,
      code: current.code,
      headers: current.headers,
    );
  }

  StrResponse? _asResponseBody(Object? eval, StrResponse current) {
    if (eval == null) return null;
    final text = eval.toString();
    if (text.isEmpty || text == current.body) return null;
    return StrResponse(
      url: current.url,
      body: text,
      code: current.code,
      headers: current.headers,
    );
  }

  Future<void> _analyzeJs() async {
    var start = 0;
    var result = ruleUrl;
    for (final m in AppPattern.js.allMatches(ruleUrl)) {
      if (m.start > start) {
        final prefix = ruleUrl.substring(start, m.start).trim();
        if (prefix.isNotEmpty) {
          result = prefix.replaceAll('@result', result);
        }
      }
      result = (await _evalJs(
        m.group(2) ?? m.group(1) ?? '',
        result,
      )).toString();
      start = m.end;
    }
    if (ruleUrl.length > start) {
      final rest = ruleUrl.substring(start).trim();
      if (rest.isNotEmpty) result = rest.replaceAll('@result', result);
    }
    ruleUrl = result;
  }

  Future<void> _replaceKeyPageJs() async {
    var s = restoreLegadoPlaceholders(ruleUrl);
    // 对齐 Legado-E AnalyzeUrl.kt:190-204：先替换内嵌 {{}} 规则，再替换页数模板，
    // 避免内嵌规则中的大于小于号被页模板正则误切。
    s = s.replaceAll('{{key}}', encodeQueryWithCharset(key ?? '', charset));
    s = s.replaceAll('{{page}}', '${page ?? 1}');
    s = s.replaceAll('{{source.bookSourceUrl}}', source?.bookSourceUrl ?? '');
    s = s.replaceAll('{{source.key}}', source?.bookSourceUrl ?? '');
    if (s.contains('{{')) {
      final buf = StringBuffer();
      var last = 0;
      for (final m in AppPattern.exp.allMatches(s)) {
        buf.write(s.substring(last, m.start));
        final inner = m.group(1)!;
        if (inner == 'key') {
          buf.write(encodeQueryWithCharset(key ?? '', charset));
        } else if (inner == 'page') {
          buf.write('${page ?? 1}');
        } else {
          buf.write(await _evalJs(inner, s));
        }
        last = m.end;
      }
      buf.write(s.substring(last));
      s = buf.toString();
    }
    if (page != null) {
      // 对齐 Legado-E AnalyzeUrl.kt:206-216：页模板按索引取 pages[page-1]，
      // 越界取 pages.last()，不做步长外推。
      s = s.replaceAllMapped(RegExp(r'<([^>]*)>'), (m) {
        final inner = m.group(1)!;
        final parts = inner.split(',');
        if (parts.length == 1) {
          return page == 1 ? '' : parts[0].replaceAll('index', '${page! - 1}');
        }
        if (page! < parts.length) return parts[page! - 1].trim();
        return parts.last.trim();
      });
    }
    ruleUrl = s;
  }

  void _peekUrlOption() {
    if (charset != null && charset!.trim().isNotEmpty) return;
    final comma = _optionComma(ruleUrl);
    if (comma < 0) return;
    try {
      final decoded = jsonDecode(ruleUrl.substring(comma + 1).trim());
      if (decoded is Map) {
        final cs = decoded['charset']?.toString();
        if (cs != null && cs.trim().isNotEmpty) charset = cs;
      }
    } catch (_) {}
  }

  Future<void> _analyzeUrl() async {
    final comma = _optionComma(ruleUrl);
    final urlPart = comma < 0 ? ruleUrl : ruleUrl.substring(0, comma);
    url = getAbsoluteUrl(baseUrl, urlPart.trim());
    final baseOrigin = getBaseUrl(url);
    if (baseOrigin != null) baseUrl = baseOrigin;
    UrlOption? opt;
    if (comma >= 0) {
      final optStr = ruleUrl.substring(comma + 1).trim();
      try {
        final decoded = jsonDecode(optStr);
        if (decoded is Map<String, dynamic>) {
          opt = UrlOption.fromJson(decoded);
          method = (opt.method ?? 'GET').toUpperCase();
          charset = opt.charset;
          body = opt.body;
          retry = opt.retry ?? 0;
          useWebView = opt.webView;
          webJs = opt.webJs;
          bodyJs = opt.bodyJs;
          type = opt.type;
          origin = opt.origin;
          dnsIp = opt.dnsIp;
          serverID = opt.serverID;
          webViewDelayTime = opt.webViewDelayTime;
          proxy = opt.proxy;
          if (opt.js != null && opt.js!.isNotEmpty) {
            url = (await _evalJs(opt.js!, url)).toString();
          }
          // bodyJs 作用于响应 body（见 getStrResponse），此处不再修改请求 body。
        }
      } catch (_) {}
    }
    // 对齐 Legado-E AnalyzeUrl.kt:133-141：源 header 先落地。
    if (source?.header != null && source!.header!.trim().isNotEmpty) {
      final h = source!.header!.trim();
      if (h.startsWith('{')) {
        try {
          final map = jsonDecode(h);
          if (map is Map) {
            map.forEach((k, v) => headerMap[k.toString()] = v.toString());
          }
        } catch (_) {}
      }
    }
    // 对齐 Legado-E AnalyzeUrl.kt:248-250：opt.headers 覆盖源 header。
    if (opt?.headers != null) headerMap.addAll(opt!.headers!);
  }

  int _optionComma(String s) {
    var depth = 0;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '{') depth++;
      if (c == '}') depth--;
      if (c == ',' && depth == 0) {
        final rest = s.substring(i + 1).trimLeft();
        if (rest.startsWith('{')) return i;
      }
    }
    return -1;
  }

  Future<Object?> _evalJs(String code, Object? result) async {
    final scope = JsScope(
      variables: {
        'result': result,
        'baseUrl': baseUrl,
        'key': key ?? '',
        'page': page ?? 1,
        'book': book,
        'chapter': chapter,
        'source': source,
        // `src` is the current URL/script input in the Android rule scope;
        // exposing the BookSource object here makes `src.includes(...)` and
        // other string operations fail before a login-check script can
        // replace it with the response body.
        'src': result,
        'cookie': source == null || cookieStore == null
            ? ''
            : cookieStore!.get(source!.bookSourceUrl),
        'nextChapterUrl': chapter?.url ?? '',
        // Legado's URL scope adds these on top of the rule scope. Binding them
        // (empty when not applicable) keeps scripts that probe them from
        // failing with ReferenceError and silently returning their input.
        'title': chapter?.title ?? '',
        'rssArticle': null,
        'speakText': '',
        'speakSpeed': '',
        'infoMap': const <String, Object?>{},
        'java': javaHost,
      },
    );
    try {
      return await JsHostBridge.evalWithDeadline(
        jsRuntime,
        JsHostBridge.prependJsLib(source?.jsLib, code),
        scope,
        timeout: EngineLimits.jsEvalTimeout,
        rule: code,
      );
    } on DomainError catch (e) {
      // 超时透传，不落进宽松解释器回退（否则死循环脚本会被「猜中」假装成功）。
      if (e.code == 'js_deadline') rethrow;
      return LenientJsRuntime.interpretJs(code, scope);
    } catch (_) {
      return LenientJsRuntime.interpretJs(code, scope);
    }
  }

  AnalyzeRule createAnalyzeRule() {
    return AnalyzeRule(
        ruleData: ruleData,
        source: source,
        jsRuntime: jsRuntime,
        javaHost: javaHost,
      )
      ..setBook(book)
      ..setChapter(chapter)
      ..page = page ?? 1;
  }
}

/// Legado WebView `sourceRegex` sniff: first http(s) URL in HTML that matches.
String? sniffResourceUrl(String html, String regex) {
  if (html.isEmpty || regex.isEmpty) return null;
  late final RegExp re;
  try {
    re = RegExp(regex);
  } catch (_) {
    return null;
  }
  if (re.hasMatch(html) &&
      (html.startsWith('http://') || html.startsWith('https://'))) {
    return html;
  }
  for (final m in RegExp(
    r'''https?://[^\s"'<>\\)]+''',
    caseSensitive: false,
  ).allMatches(html)) {
    final url = m.group(0)!;
    if (re.hasMatch(url)) return url;
  }
  final quoted = re.firstMatch(html);
  if (quoted != null) {
    final hit = quoted.group(0) ?? '';
    if (hit.startsWith('http://') || hit.startsWith('https://')) return hit;
  }
  return null;
}
