import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:http/http.dart' as http;

import '../core/http/http_session.dart';

/// Web 端把书源 HTTP 转发到同源 `/proxy/http`，由服务端出网，避开浏览器 CORS。
class ProxyHttpPort implements HttpPort, SessionAwareHttp {
  ProxyHttpPort({String? origin, http.Client? client, http.Client? backgroundClient})
    : origin = origin ?? Uri.base.origin,
      _ownsBackground = backgroundClient == null && client == null,
      _interactive = client ?? http.Client(),
      _background = backgroundClient ?? client ?? http.Client();

  final String origin;
  final bool _ownsBackground;
  http.Client _interactive;
  http.Client _background;
  int _epoch = 0;
  final Map<String, int> _sessionEpoch = {};
  final Map<String, Future<StrResponse>> _inflight = {};

  http.Client _clientFor(String? session) =>
      isBackgroundHttpSession(session) ? _background : _interactive;

  void _recycleBackground() {
    if (identical(_background, _interactive)) return;
    try {
      _background.close();
    } catch (_) {}
    if (_ownsBackground) {
      _background = http.Client();
    }
  }

  Uri get _httpUri => Uri.parse(origin).replace(path: '/proxy/http');
  bool _available = true;
  bool get isAvailable => _available;

  /// Probes the same-origin proxy before routing CORS-sensitive requests.
  Future<bool> probe() async {
    try {
      final res = await _interactive
          .send(http.Request('OPTIONS', _httpUri))
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 2));
      return _available = res.statusCode < 500;
    } catch (_) {
      return _available = false;
    }
  }

  Uri get _bytesUri => Uri.parse(origin).replace(path: '/proxy/bytes');

  int _mark(String? session) {
    if (session == null || session.isEmpty) return _epoch;
    return _epoch + (_sessionEpoch[session] ?? 0);
  }

  @override
  void cancelInFlight() {
    _epoch++;
  }

  @override
  void cancelSession(String session) {
    _sessionEpoch[session] = (_sessionEpoch[session] ?? 0) + 1;
    if (isBackgroundHttpSession(session)) {
      _recycleBackground();
    }
  }

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    final session = HttpSession.current;
    final lane = isBackgroundHttpSession(session) ? 'bg' : 'fg';
    final coalesceKey = '$lane\u0001${_coalesceKey(spec)}';
    final existing = _inflight[coalesceKey];
    if (existing != null) return existing;
    final future = _sendUncoalesced(spec, session);
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
  ) async {
    final epoch = _mark(session);
    final timeoutMs = spec.effectiveTimeout.inMilliseconds;
    final payload = jsonEncode({
      'url': spec.url,
      'method': spec.method,
      'headers': spec.headers,
      'body': spec.body,
      'charset': spec.charset,
      'timeoutMs': timeoutMs,
      if (spec.origin != null) 'origin': spec.origin,
      if (spec.dnsIp != null) 'dnsIp': spec.dnsIp,
      if (spec.serverID != null) 'serverID': spec.serverID,
      if (spec.proxy != null) 'proxy': spec.proxy,
    });
    Object? lastError;
    for (var attempt = 0; attempt <= spec.retry; attempt++) {
      if (epoch != _mark(session)) throw const HttpCancelledException();
      try {
        final res = await _clientFor(session)
            .post(
              _httpUri,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
              body: payload,
            )
            .timeout(spec.effectiveTimeout);
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
    Object? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await _interactive
            .post(
              _bytesUri,
              headers: const {
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
