import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:http/http.dart' as http;

import '../core/http/http_session.dart';

/// Web 端把书源 HTTP 转发到同源 `/proxy/http`，由服务端出网，避开浏览器 CORS。
class ProxyHttpPort implements HttpPort, SessionAwareHttp {
  ProxyHttpPort({
    String? origin,
    http.Client? client,
    http.Client? backgroundClient,
    this.connection,
  }) : origin = origin ?? Uri.base.origin,
       _interactive = client ?? http.Client(),
       _background = backgroundClient ?? client ?? http.Client();

  final String origin;
  final Future<({String origin, String token})> Function()? connection;
  Future<({String origin, String token})> _connection() async =>
      connection == null ? (origin: origin, token: '') : await connection!();
  Uri _uri(String base, String path) => Uri.parse(base).resolve(path);
  Map<String, String> _auth(String token) => {
    if (token.isNotEmpty) 'authorization': 'Bearer $token',
  };
  final http.Client _interactive;
  final http.Client _background;
  int _epoch = 0;
  final Map<String, int> _sessionEpoch = {};
  final Map<String, Future<StrResponse>> _inflight = {};
  final Map<String, Set<Completer<void>>> _aborts = {};

  http.Client _clientFor(String? session) =>
      isBackgroundHttpSession(session) ? _background : _interactive;

  bool _available = true;
  bool get isAvailable => _available;

  /// Probes the same-origin proxy before routing CORS-sensitive requests.
  Future<bool> probe() async {
    try {
      final endpoint = await _connection();
      final request = http.Request(
        'OPTIONS',
        _uri(endpoint.origin, '/proxy/http'),
      )..headers.addAll(_auth(endpoint.token));
      final res = await _interactive
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 2));
      return _available = res.statusCode < 500;
    } catch (_) {
      return _available = false;
    }
  }

  int _mark(String? session) {
    if (session == null || session.isEmpty) return _epoch;
    return _epoch + (_sessionEpoch[session] ?? 0);
  }

  @override
  void cancelInFlight() {
    _epoch++;
    for (final group in _aborts.values) {
      for (final abort in group) {
        if (!abort.isCompleted) abort.complete();
      }
    }
  }

  @override
  void cancelSession(String session) {
    for (final entry in _aborts.entries) {
      if (entry.key == session || entry.key.startsWith('$session.')) {
        for (final abort in entry.value) {
          if (!abort.isCompleted) abort.complete();
        }
      }
    }
    _sessionEpoch[session] = (_sessionEpoch[session] ?? 0) + 1;
    final affected = _sessionEpoch.keys
        .where((id) => id.startsWith('$session.'))
        .toList(growable: false);
    for (final id in affected) {
      _sessionEpoch[id] = (_sessionEpoch[id] ?? 0) + 1;
    }
  }

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    final endpoint = await _connection();
    final session = HttpSession.current;
    final lane = isBackgroundHttpSession(session) ? 'bg' : 'fg';
    final operationScope =
        session?.startsWith('search.') == true ||
            session?.startsWith('explore.') == true ||
            session?.startsWith('music-') == true
        ? session
        : '';
    final coalesceKey =
        '${endpoint.origin}\u0001${endpoint.token}\u0001$lane\u0001$operationScope\u0001${_coalesceKey(spec)}';
    final existing = _inflight[coalesceKey];
    if (existing != null) return existing;
    final future = _sendUncoalesced(spec, session, endpoint);
    _inflight[coalesceKey] = future;
    try {
      return await future;
    } finally {
      if (identical(_inflight[coalesceKey], future)) {
        _inflight.remove(coalesceKey);
      }
    }
  }

  String _coalesceKey(HttpRequestSpec spec) {
    final headers = spec.headers.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return [
      spec.method.toUpperCase(),
      '${spec.maxResponseBytes}',
      '${spec.allowTruncated}',
      spec.url,
      spec.body ?? '',
      spec.charset ?? '',
      spec.origin ?? '',
      spec.dnsIp ?? '',
      spec.serverID ?? '',
      spec.proxy ?? '',
      for (final entry in headers) '${entry.key.toLowerCase()}=${entry.value}',
    ].join('\u0001');
  }

  Future<StrResponse> _sendUncoalesced(
    HttpRequestSpec spec,
    String? session,
    ({String origin, String token}) endpoint,
  ) async {
    final epoch = _mark(session);
    if (session != null && session.isNotEmpty) {
      _sessionEpoch.putIfAbsent(session, () => 0);
    }
    final timeoutMs = spec.effectiveTimeout.inMilliseconds;
    final payload = jsonEncode({
      'url': spec.url,
      'method': spec.method,
      'headers': spec.headers,
      'body': spec.body,
      'charset': spec.charset,
      'timeoutMs': timeoutMs,
      'maxResponseBytes': spec.maxResponseBytes,
      'allowTruncated': spec.allowTruncated,
      if (spec.origin != null) 'origin': spec.origin,
      if (spec.dnsIp != null) 'dnsIp': spec.dnsIp,
      if (spec.serverID != null) 'serverID': spec.serverID,
      if (spec.proxy != null) 'proxy': spec.proxy,
    });
    Object? lastError;
    for (var attempt = 0; attempt <= spec.retry; attempt++) {
      if (epoch != _mark(session)) throw const HttpCancelledException();
      try {
        final abort = Completer<void>();
        final group = _aborts.putIfAbsent(session ?? '', () => {});
        group.add(abort);
        late http.Response res;
        try {
          final request =
              http.AbortableRequest(
                  'POST',
                  _uri(endpoint.origin, '/proxy/http'),
                  abortTrigger: abort.future,
                )
                ..headers.addAll(_auth(endpoint.token))
                ..headers['content-type'] = 'application/json; charset=utf-8'
                ..body = payload;
          res = await _clientFor(session)
              .send(request)
              .then(http.Response.fromStream)
              .timeout(
                spec.effectiveTimeout,
                onTimeout: () {
                  if (!abort.isCompleted) abort.complete();
                  throw TimeoutException('请求超时');
                },
              );
        } on http.RequestAbortedException {
          throw const HttpCancelledException();
        } finally {
          group.remove(abort);
          if (group.isEmpty) _aborts.remove(session ?? '');
        }
        if (epoch != _mark(session)) throw const HttpCancelledException();
        if (res.statusCode == 404 || res.statusCode == 405) {
          _available = false;
          throw StateError('搜索代理未启动（缺少 /proxy/http）');
        }
        Map<String, dynamic> map;
        try {
          map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        } catch (_) {
          throw StateError('搜索代理返回格式无效');
        }
        if (map['error'] != null && map['body'] == null) {
          throw StateError(map['error'].toString());
        }
        final code = (map['code'] as num?)?.toInt() ?? res.statusCode;
        if (code >= 500 && attempt < spec.retry) {
          lastError = StateError('proxy http $code');
          await _retryDelay(attempt, epoch, session);
          continue;
        }
        if (code >= 500) {
          throw StateError('proxy http $code ${spec.url}');
        }
        final headers = <String, String>{};
        final rawH = map['headers'];
        if (rawH is Map) {
          rawH.forEach((k, v) => headers[k.toString()] = v.toString());
        }
        _available = true;
        return StrResponse(
          url: map['url']?.toString() ?? spec.url,
          body: map['body']?.toString(),
          code: code,
          headers: headers,
        );
      } on HttpCancelledException {
        rethrow;
      } catch (error) {
        lastError = error;
        if (attempt >= spec.retry) rethrow;
        await _retryDelay(attempt, epoch, session);
      }
    }
    throw lastError ?? StateError('搜索代理请求失败');
  }

  Future<void> _retryDelay(int attempt, int epoch, String? session) async {
    final delay = Duration(milliseconds: 120 * (1 << attempt.clamp(0, 4)));
    await Future<void>.delayed(delay);
    if (epoch != _mark(session)) throw const HttpCancelledException();
  }

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async {
    final endpoint = await _connection();
    Object? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await _interactive
            .post(
              _uri(endpoint.origin, '/proxy/bytes'),
              headers: {
                ..._auth(endpoint.token),
                'content-type': 'application/json; charset=utf-8',
              },
              body: jsonEncode({'url': url, 'headers': headers ?? {}}),
            )
            .timeout(EngineLimits.httpTimeout);
        final map =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        if (map['error'] != null) throw StateError(map['error'].toString());
        final encoded = map['b64']?.toString() ?? '';
        if (encoded.isEmpty) throw StateError('代理返回空二进制内容');
        return base64Decode(encoded);
      } catch (error) {
        last = error;
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 120 * (1 << attempt)),
          );
        }
      }
    }
    throw last ?? StateError('二进制代理请求失败');
  }
}
