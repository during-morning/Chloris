import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'api_contract.dart';
import 'server_backend.dart';

/// Hosts that a proxy request may not reach by default.
///
/// The proxy exists so a browser client can fetch book-source pages that a
/// page script could not reach directly. Pointing it at the loopback interface
/// or a private range turns it into an SSRF gadget against whatever else is
/// listening on the user's machine or LAN, so those targets are refused unless
/// the caller explicitly opts in.
bool isBlockedProxyHost(String host, {bool allowPrivate = false}) {
  if (allowPrivate) return false;
  final h = host.toLowerCase().replaceAll(RegExp(r'^\[|\]$'), '');
  if (h.isEmpty) return true;
  if (h == 'localhost' || h.endsWith('.localhost') || h.endsWith('.local')) {
    return true;
  }
  final addr = InternetAddress.tryParse(h);
  if (addr == null) return false; // A public DNS name; resolution is allowed.
  if (addr.isLoopback) return true;
  if (addr.type == InternetAddressType.IPv4) {
    final b = addr.rawAddress;
    if (b[0] == 10) return true;
    if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
    if (b[0] == 192 && b[1] == 168) return true;
    if (b[0] == 169 && b[1] == 254) return true; // link-local
    if (b[0] == 0) return true;
    if (b[0] >= 224) return true; // multicast / reserved
  } else {
    // fc00::/7 unique-local and fe80::/10 link-local.
    final b = addr.rawAddress;
    if ((b[0] & 0xfe) == 0xfc) return true;
    if (b[0] == 0xfe && (b[1] & 0xc0) == 0x80) return true;
  }
  return false;
}

/// Validates a proxy target before the request is made.
String? proxyTargetError(String url, {bool allowPrivate = false}) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return 'invalid url';
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return 'unsupported scheme: ${uri.scheme}';
  }
  if (isBlockedProxyHost(uri.host, allowPrivate: allowPrivate)) {
    return 'target host is not routable: ${uri.host}';
  }
  return null;
}

/// True when an `Origin` header belongs to this machine.
bool isLoopbackOrigin(String origin) {
  final uri = Uri.tryParse(origin);
  if (uri == null || !uri.hasScheme) return false;
  final host = uri.host.toLowerCase();
  if (host == 'localhost' || host == '127.0.0.1' || host == '::1') return true;
  final addr = InternetAddress.tryParse(host);
  return addr != null && addr.isLoopback;
}

/// Constant-time string comparison, so a token check cannot be timed.
bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

String generateServerToken() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(24, (_) => rnd.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

class ChlorisServer {
  ChlorisServer({
    required this.bookSources,
    required this.replaceRules,
    this.rssSources = const [],
    this.backend,
    this.appVersion = '0.1.0',
    String? token,
    this.bindAddress,
    this.allowPrivateProxyTargets = false,
  }) : token = token ?? generateServerToken();

  final List<BookSource> bookSources;
  final List<ReplaceRule> replaceRules;
  final List<Map<String, dynamic>> rssSources;

  /// Application operations for the state-dependent routes. Null means this
  /// server was started without one, and those routes answer 501 instead of
  /// pretending the state is empty.
  final ServerBackend? backend;

  final String appVersion;

  /// Shared secret required on every request. Generated per start unless the
  /// caller supplies one (tests do).
  final String token;

  /// Loopback by default. Binding every interface would expose book sources,
  /// cookies and WebDAV credentials to the whole network.
  final InternetAddress? bindAddress;

  final bool allowPrivateProxyTargets;

  HttpServer? _http;
  HttpServer? _ws;

  /// Port actually bound, available after [start].
  int get port => _http?.port ?? 0;
  int get webSocketPort => _ws?.port ?? 0;

  Future<void> start({int httpPort = 1234, int wsPort = 1235}) async {
    final router = Router();

    // Route paths come from the shared contract, so the server cannot drift
    // from what a client was written against.
    router.get(
      ChlorisApiRoute.version.path,
      (req) => _envelope(
        ApiEnvelope.ok(
          ServerInfo(
            apiVersion: chlorisApiVersion,
            appVersion: appVersion,
            capabilities: {
              'bookshelf': backend != null,
              'chapterList': backend != null,
              'bookContent': backend != null,
              'cover': backend != null,
              'image': backend != null,
              'proxy': true,
              'rssSources': true,
              'bookSourceDebug': true,
              'searchBook': backend != null,
            },
          ).toJson(),
        ),
      ),
    );

    router.get(
      '/getBookSources',
      (req) => _json(bookSources.map((s) => s.toJson()).toList()),
    );
    router.get('/getBookSource', (req) {
      final url = req.url.queryParameters['url'] ?? '';
      final matches = bookSources.where((s) => s.bookSourceUrl == url).toList();
      return _json(matches.isEmpty ? null : matches.first.toJson());
    });
    router.post('/saveBookSources', (req) async {
      final list = BookSource.listFromJson(
        jsonDecode(await req.readAsString()),
      );
      final byUrl = <String, BookSource>{
        for (final s in bookSources) s.bookSourceUrl: s,
      };
      for (final s in list) {
        byUrl[s.bookSourceUrl] = s;
      }
      bookSources
        ..clear()
        ..addAll(byUrl.values);
      return _json({'ok': true, 'count': bookSources.length});
    });
    router.post('/saveBookSource', (req) async {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final s = BookSource.fromJson(body);
      final i = bookSources.indexWhere(
        (x) => x.bookSourceUrl == s.bookSourceUrl,
      );
      if (i >= 0) {
        bookSources[i] = s;
      } else {
        bookSources.add(s);
      }
      return _json({'ok': true});
    });
    router.post('/deleteBookSources', (req) async {
      final body = jsonDecode(await req.readAsString());
      final urls = body is List
          ? body
                .map(
                  (e) =>
                      e is Map ? e['bookSourceUrl']?.toString() : e.toString(),
                )
                .whereType<String>()
                .toList()
          : <String>[];
      for (final u in urls) {
        bookSources.removeWhere((s) => s.bookSourceUrl == u);
      }
      return _json({'ok': true, 'deleted': urls.length});
    });
    router.get(
      '/getReplaceRules',
      (req) => _json(replaceRules.map((r) => r.toJson()).toList()),
    );
    router.post('/testReplaceRule', (req) async {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final text = body['text']?.toString() ?? '';
      final rule = ReplaceRule.fromJson(body['rule'] as Map<String, dynamic>);
      return _json({'text': _applyRule(rule, text)});
    });
    router.post('/proxy/http', (req) async {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final blocked = proxyTargetError(
        body['url']?.toString() ?? '',
        allowPrivate: allowPrivateProxyTargets,
      );
      if (blocked != null) return _json({'error': blocked, 'code': 400});
      return _json(await proxyHttp(body));
    });
    router.post('/proxy/bytes', (req) async {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final blocked = proxyTargetError(
        body['url']?.toString() ?? '',
        allowPrivate: allowPrivateProxyTargets,
      );
      if (blocked != null) return _json({'error': blocked, 'code': 400});
      return _json(await proxyBytes(body));
    });

    // ---- state-dependent routes (need a ServerBackend) --------------------

    router.get(
      ChlorisApiRoute.getBookshelf.path,
      (req) => _withBackend('书架', (b) async => await b.bookshelf()),
    );
    router.post(ChlorisApiRoute.saveBook.path, (req) async {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      return _withBackend('保存书籍', (b) async {
        await b.saveBook(body);
        return {'ok': true};
      });
    });
    router.post(ChlorisApiRoute.deleteBook.path, (req) async {
      final body = jsonDecode(await req.readAsString());
      final url = body is Map
          ? body['bookUrl']?.toString() ?? ''
          : body.toString();
      return _withBackend('删除书籍', (b) async {
        await b.deleteBook(url);
        return {'ok': true};
      });
    });
    router.post(ChlorisApiRoute.saveBookProgress.path, (req) async {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      return _withBackend('保存进度', (b) async {
        await b.saveProgress(body);
        return {'ok': true};
      });
    });
    router.get(ChlorisApiRoute.getChapterList.path, (req) {
      final q = ChapterListQuery.fromQuery(req.url.queryParameters);
      return _withBackend(
        '目录',
        (b) async => await b.chapterList(q.bookUrl, refresh: q.refresh),
      );
    });
    router.get(ChlorisApiRoute.refreshToc.path, (req) {
      final q = ChapterListQuery.fromQuery(req.url.queryParameters);
      return _withBackend(
        '刷新目录',
        (b) async => await b.chapterList(q.bookUrl, refresh: true),
      );
    });
    router.get(ChlorisApiRoute.getBookContent.path, (req) {
      final q = BookContentQuery.fromQuery(req.url.queryParameters);
      return _withBackend(
        '正文',
        (b) async => await b.bookContent(q.bookUrl, q.chapterIndex),
      );
    });
    router.get(ChlorisApiRoute.getCover.path, (req) async {
      final b = backend;
      if (b == null) return _capabilityMissing('封面');
      final bytes = await b.cover(req.url.queryParameters['url'] ?? '');
      if (bytes == null) return Response.notFound('no cover');
      return Response.ok(bytes, headers: {'content-type': 'image/jpeg'});
    });
    router.get(ChlorisApiRoute.getImage.path, (req) async {
      final b = backend;
      if (b == null) return _capabilityMissing('图片');
      final url = req.url.queryParameters['url'] ?? '';
      final blocked = proxyTargetError(
        url,
        allowPrivate: allowPrivateProxyTargets,
      );
      if (blocked != null) return Response.badRequest(body: blocked);
      final bytes = await b.image(url);
      if (bytes == null) return Response.notFound('no image');
      return Response.ok(bytes, headers: {'content-type': 'image/jpeg'});
    });

    // ---- RSS sources -------------------------------------------------------

    router.get(ChlorisApiRoute.getRssSources.path, (req) => _json(rssSources));
    router.get(ChlorisApiRoute.getRssSource.path, (req) {
      final url = req.url.queryParameters['url'] ?? '';
      final match = rssSources.where((s) => s['sourceUrl'] == url).toList();
      return _json(match.isEmpty ? null : match.first);
    });
    router.post(ChlorisApiRoute.saveRssSources.path, (req) async {
      final body = jsonDecode(await req.readAsString());
      final list = body is List ? body : [body];
      final byUrl = <String, Map<String, dynamic>>{
        for (final s in rssSources)
          if (s['sourceUrl'] != null) s['sourceUrl'].toString(): s,
      };
      for (final raw in list) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final url = map['sourceUrl']?.toString() ?? '';
        if (url.isEmpty) continue;
        byUrl[url] = map;
      }
      rssSources
        ..clear()
        ..addAll(byUrl.values);
      return _json({'ok': true, 'count': rssSources.length});
    });
    router.post(ChlorisApiRoute.deleteRssSources.path, (req) async {
      final body = jsonDecode(await req.readAsString());
      final urls = body is List
          ? body
                .map(
                  (e) => e is Map ? e['sourceUrl']?.toString() : e.toString(),
                )
                .whereType<String>()
                .toList()
          : <String>[];
      for (final u in urls) {
        rssSources.removeWhere((s) => s['sourceUrl'] == u);
      }
      return _json({'ok': true, 'deleted': urls.length});
    });

    // ---- replace rule writes ----------------------------------------------

    router.post('/saveReplaceRule', (req) async {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final rule = ReplaceRule.fromJson(body);
      final i = replaceRules.indexWhere((r) => r.id == rule.id);
      if (i >= 0) {
        replaceRules[i] = rule;
      } else {
        replaceRules.add(rule);
      }
      return _json({'ok': true});
    });
    router.post('/deleteReplaceRule', (req) async {
      final body = jsonDecode(await req.readAsString());
      final ids = body is List
          ? body.map((e) => e is Map ? e['id'] : e).toList()
          : [body];
      final wanted = ids.map((e) => e?.toString()).whereType<String>().toSet();
      replaceRules.removeWhere((r) => wanted.contains(r.id?.toString()));
      return _json({'ok': true});
    });

    final handler = const Pipeline()
        .addMiddleware(_securityHeaders())
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware())
        .addMiddleware(logRequests())
        .addHandler(router.call);
    final address = bindAddress ?? InternetAddress.loopbackIPv4;
    _http = await shelf_io.serve(handler, address, httpPort);

    _ws = await HttpServer.bind(address, wsPort);
    _ws!.listen((req) async {
      if (!_authorizedHttp(req)) {
        req.response.statusCode = HttpStatus.unauthorized;
        await req.response.close();
        return;
      }
      if (req.uri.path == '/searchBook') {
        final ws = await WebSocketTransformer.upgrade(req);
        var closed = false;
        ws.done.whenComplete(() => closed = true);
        ws.listen((msg) async {
          if (closed) return;
          try {
            final data = jsonDecode(msg.toString());
            if (data is! Map)
              throw const FormatException('request must be object');
            final source =
                data['tag']?.toString() ?? data['source']?.toString() ?? '';
            final query =
                data['key']?.toString() ?? data['query']?.toString() ?? '';
            final page = (data['page'] as num?)?.toInt() ?? 1;
            final b = backend;
            if (b == null) {
              ws.add(
                jsonEncode({
                  'error': 'capability_missing',
                  'errorMsg': '搜索功能未装配',
                }),
              );
            } else {
              final books = await b.search(source, query, page: page);
              for (final book in books) {
                if (!closed) ws.add(jsonEncode(book));
              }
              if (!closed) ws.add(jsonEncode({'type': 'end', 'end': true}));
            }
          } catch (e) {
            if (!closed) ws.add(jsonEncode({'error': e.toString()}));
          }
        });
      } else if (req.uri.path == '/bookSourceDebug') {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.listen((msg) {
          final data = jsonDecode(msg.toString()) as Map<String, dynamic>;
          final tag = data['tag']?.toString() ?? '';
          final matches = bookSources
              .where((s) => s.bookSourceUrl == tag || s.bookSourceName == tag)
              .map((s) => s.toJson())
              .toList();
          ws.add(jsonEncode(matches));
        });
      } else {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
      }
    });
  }

  /// Accepts the token from the `Authorization` header, an `X-Chloris-Token`
  /// header, or a `token` query parameter (WebSocket clients cannot set
  /// headers from a browser).
  bool _authorized(Request req) => _authorizedParts(
    req.headers['authorization'],
    req.headers['x-chloris-token'],
    req.url.queryParameters['token'],
  );

  bool _authorizedParts(String? auth, String? header, String? query) {
    if (auth != null) {
      const prefix = 'bearer ';
      if (auth.toLowerCase().startsWith(prefix)) {
        if (constantTimeEquals(auth.substring(prefix.length).trim(), token)) {
          return true;
        }
      }
    }
    if (header != null && constantTimeEquals(header, token)) return true;
    if (query != null && constantTimeEquals(query, token)) return true;
    return false;
  }

  bool _authorizedHttp(HttpRequest req) => _authorizedParts(
    req.headers.value('authorization'),
    req.headers.value('x-chloris-token'),
    req.uri.queryParameters['token'],
  );

  Middleware _authMiddleware() {
    return (Handler inner) {
      return (Request req) async {
        // Preflight carries no credentials by design; it is answered before
        // the token check and leaks no data.
        if (req.method == 'OPTIONS') return inner(req);
        if (!_authorized(req)) {
          return Response(
            HttpStatus.unauthorized,
            body: jsonEncode({'error': 'unauthorized'}),
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return inner(req);
      };
    };
  }

  String _applyRule(ReplaceRule r, String text) {
    if (!r.isRegex) return text.replaceAll(r.pattern, r.replacement);
    try {
      return text.replaceAll(RegExp(r.pattern), r.replacement);
    } catch (_) {
      return text;
    }
  }

  Response _json(Object? data) => Response.ok(
    jsonEncode(data),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Response _envelope(ApiEnvelope envelope, {int status = 200}) => Response(
    status,
    body: jsonEncode({
      'isSuccess': envelope.isSuccess,
      'errorMsg': envelope.errorMsg,
      if (envelope.data != null) 'data': envelope.data,
      if (envelope.stage != null) 'stage': envelope.stage!.name,
      if (envelope.retryable != null) 'retryable': envelope.retryable,
      if (envelope.suggestedAction != null)
        'suggestedAction': envelope.suggestedAction,
    }),
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );

  /// Runs [run] against the backend, or answers 501 when none is attached.
  ///
  /// A missing capability must be distinguishable from empty state: a client
  /// that receives `[]` would show an empty shelf instead of "this server
  /// cannot list books".
  Future<Response> _withBackend(
    String capability,
    Future<Object?> Function(ServerBackend backend) run,
  ) async {
    final b = backend;
    if (b == null) return _capabilityMissing(capability);
    try {
      return _envelope(ApiEnvelope.ok(await run(b)));
    } catch (e) {
      return _envelope(ApiEnvelope.failure(DomainError.from(e)), status: 500);
    }
  }

  Response _capabilityMissing(String capability) => _envelope(
    ApiEnvelope.failure(
      DomainError(
        code: 'capability_missing',
        stage: DomainErrorStage.request,
        message: '$capability 功能未装配',
        recoverable: false,
        retryable: false,
        suggestedAction: '启动 Web 服务时提供 ServerBackend',
      ),
    ),
    status: 501,
  );

  Future<void> stop() async {
    await _http?.close(force: true);
    await _ws?.close(force: true);
    _http = null;
    _ws = null;
  }
}

Map<String, String> _corsFor(Request req) {
  final origin = req.headers['origin'];
  if (origin == null) return const {};
  // Only this machine's own pages may call the API. A wildcard here would let
  // any visited site read the user's book sources and drive the proxy.
  if (!isLoopbackOrigin(origin)) return const {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers':
        'Content-Type, Authorization, X-Chloris-Token',
    'Vary': 'Origin',
  };
}

Middleware _corsMiddleware() {
  return (Handler inner) {
    return (Request req) async {
      final cors = _corsFor(req);
      if (req.method == 'OPTIONS') return Response.ok('', headers: cors);
      final res = await inner(req);
      return res.change(headers: cors);
    };
  };
}

Middleware _securityHeaders() {
  return (Handler inner) {
    return (Request req) async {
      final res = await inner(req);
      return res.change(
        headers: const {
          'X-Content-Type-Options': 'nosniff',
          'Referrer-Policy': 'no-referrer',
        },
      );
    };
  };
}

HttpClient? _sharedProxyClient;
HttpClient _proxyClient() {
  final existing = _sharedProxyClient;
  if (existing != null) return existing;
  final c = HttpClient();
  c.maxConnectionsPerHost = 48;
  c.idleTimeout = const Duration(seconds: 20);
  c.connectionTimeout = const Duration(seconds: 15);
  c.userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36';
  return _sharedProxyClient = c;
}

Future<Map<String, dynamic>> proxyHttp(Map<String, dynamic> body) async {
  final url = body['url']?.toString() ?? '';
  if (url.isEmpty) return {'error': 'missing url', 'code': 400};
  final method = (body['method']?.toString() ?? 'GET').toUpperCase();
  final headers = <String, String>{};
  final rawH = body['headers'];
  if (rawH is Map) {
    rawH.forEach((k, v) => headers[k.toString()] = v.toString());
  }
  final timeoutMs = (body['timeoutMs'] is num)
      ? (body['timeoutMs'] as num).toInt()
      : 30000;
  final timeout = Duration(milliseconds: timeoutMs.clamp(3000, 60000));
  final client = _proxyClient();
  try {
    Future<Map<String, dynamic>> once() async {
      final req = await client.openUrl(method, Uri.parse(url));
      req.followRedirects = true;
      headers.forEach((k, v) {
        if (k.toLowerCase() == 'host') return;
        req.headers.set(k, v);
      });
      final charset = body['charset']?.toString();
      final reqBody = body['body']?.toString();
      if (reqBody != null && reqBody.isNotEmpty) {
        final encoded = HttpBodyDecoder.encodeRequestBody(reqBody, charset);
        if (encoded is List<int>) {
          req.add(encoded);
        } else {
          req.write(encoded);
        }
      }
      final res = await req.close();
      final bytes = await res.fold<List<int>>(<int>[], (p, chunk) {
        p.addAll(chunk);
        return p;
      });
      final headerMap = <String, String>{};
      res.headers.forEach((name, values) {
        headerMap[name] = values.join(', ');
      });
      final contentType =
          headerMap['content-type'] ?? headerMap['Content-Type'];
      final text = HttpBodyDecoder.decode(
        bytes,
        charset: charset,
        contentType: contentType,
      );
      var finalUrl = url;
      if (res.redirects.isNotEmpty) {
        final loc = res.redirects.last.location;
        finalUrl = loc.hasScheme
            ? loc.toString()
            : Uri.parse(url).resolveUri(loc).toString();
      }
      return {
        'url': finalUrl,
        'code': res.statusCode,
        'headers': headerMap,
        'body': text,
      };
    }

    return await once().timeout(timeout);
  } catch (e) {
    return {'error': e.toString(), 'code': 502};
  }
}

Future<Map<String, dynamic>> proxyBytes(Map<String, dynamic> body) async {
  final url = body['url']?.toString() ?? '';
  if (url.isEmpty) return {'error': 'missing url'};
  final headers = <String, String>{};
  final rawH = body['headers'];
  if (rawH is Map) {
    rawH.forEach((k, v) => headers[k.toString()] = v.toString());
  }
  final client = _proxyClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    headers.forEach((k, v) => req.headers.set(k, v));
    final res = await req.close().timeout(const Duration(seconds: 25));
    final bytes = await res.fold<List<int>>(<int>[], (p, chunk) {
      p.addAll(chunk);
      return p;
    });
    return {'b64': base64Encode(bytes), 'code': res.statusCode};
  } catch (e) {
    return {'error': e.toString()};
  }
}

Future<({List<int> bytes, String contentType, int code})?> proxyImage(
  String url,
) async {
  if (url.isEmpty) return null;
  final client = _proxyClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    req.followRedirects = true;
    final res = await req.close().timeout(const Duration(seconds: 12));
    final bytes = await res.fold<List<int>>(<int>[], (p, chunk) {
      p.addAll(chunk);
      return p;
    });
    var ct = res.headers.contentType?.toString() ?? 'image/jpeg';
    if (!ct.startsWith('image/')) ct = 'image/jpeg';
    return (bytes: bytes, contentType: ct, code: res.statusCode);
  } catch (_) {
    return null;
  }
}

Future<ChlorisServer> startServer({
  required List<BookSource> bookSources,
  required List<ReplaceRule> replaceRules,
  int httpPort = 1234,
  int wsPort = 1235,
  String? token,
  bool allowPrivateProxyTargets = false,
  List<Map<String, dynamic>> rssSources = const [],
  ServerBackend? backend,
  String appVersion = '0.1.0',
}) async {
  final server = ChlorisServer(
    bookSources: bookSources,
    replaceRules: replaceRules,
    rssSources: rssSources,
    backend: backend,
    appVersion: appVersion,
    token: token,
    allowPrivateProxyTargets: allowPrivateProxyTargets,
  );
  await server.start(httpPort: httpPort, wsPort: wsPort);
  return server;
}
