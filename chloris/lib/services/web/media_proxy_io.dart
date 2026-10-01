import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:chloris_engine/chloris_engine.dart' show CookieStore;

import 'proxy_target_guard.dart';

class MediaPlaybackSessions {
  static final instance = MediaPlaybackSessions();
  final _parents = <String, String>{};
  final _children = <String, String>{};
  final _random = Random.secure();
  final _sessions =
      <String, ({Map<String, dynamic> request, DateTime expires})>{};
  String create(Map<String, dynamic> request, {String? parent}) {
    final resourceKey = parent == null
        ? null
        : '$parent\u0000${request['url']}';
    final existing = _children[resourceKey];
    if (existing != null && take(existing) != null) return existing;
    final expired = _sessions.entries
        .where((e) => e.value.expires.isBefore(DateTime.now()))
        .map((e) => e.key)
        .toList();
    for (final expiredId in expired) {
      release(expiredId);
    }
    if (_sessions.length >= 4096) throw StateError('播放会话容量已满');
    final id = base64Url
        .encode(List.generate(24, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    _sessions[id] = (
      request: Map.unmodifiable(request),
      expires: DateTime.now().add(const Duration(minutes: 30)),
    );
    if (parent != null) {
      _parents[id] = parent;
      _children[resourceKey!] = id;
    }
    return id;
  }

  Map<String, dynamic>? take(String? id) {
    final item = _sessions[id];
    if (item == null) return null;
    if (item.expires.isBefore(DateTime.now())) {
      release(id!);
      return null;
    }
    _sessions[id!] = (
      request: item.request,
      expires: DateTime.now().add(const Duration(minutes: 30)),
    );
    return item.request;
  }

  void release(String id) {
    final removed = <String>{id};
    bool changed = true;
    while (changed) {
      changed = false;
      for (final e in _parents.entries) {
        if (removed.contains(e.value) && removed.add(e.key)) changed = true;
      }
    }
    _sessions.removeWhere((key, _) => removed.contains(key));
    _parents.removeWhere((key, _) => removed.contains(key));
    _children.removeWhere((_, value) => removed.contains(value));
  }
}

const _connectTimeout = Duration(seconds: 15);
const _responseTimeout = Duration(seconds: 30);
const _streamTimeout = Duration(seconds: 45);
const _maxPlaylistBytes = 2 * 1024 * 1024;

/// Streams an audio resource on the browser's origin, including seek ranges.
///
/// Source credentials are kept in opaque playback sessions. Legacy request
/// parameters remain supported. Each redirect is checked and DNS results are pinned to the
/// actual socket so a second lookup cannot bypass the destination guard.
Future<Response> proxyMedia(Request req, {bool allowPrivate = false}) async {
  if (req.method != 'GET' && req.method != 'HEAD') {
    return Response(405, headers: const {'allow': 'GET, HEAD'});
  }
  final query = req.url.queryParameters;
  final session = MediaPlaybackSessions.instance.take(query['sid']);
  if (query.containsKey('sid') && session == null)
    return _error(410, '播放地址已过期，请重新解析');
  final rawUrl = session?['url'] as String? ?? query['url'] ?? query['u'] ?? '';
  final invalid = proxyTargetError(rawUrl, allowPrivate: allowPrivate);
  if (invalid != null) return _error(400, invalid);
  Map<String, String> headers;
  try {
    headers = _sourceHeaders(
      session == null ? query['headers'] : jsonEncode(session['headers'] ?? {}),
    );
  } on FormatException {
    return _error(400, 'invalid media headers');
  }
  for (final name in ['range', 'if-range']) {
    final value = req.headers[name];
    if (value != null) headers[name] = value;
  }
  var target = Uri.parse(rawUrl);
  HttpClient? client;
  try {
    for (var redirects = 0; ; redirects++) {
      final addresses = await _resolveTarget(
        target,
        allowPrivate: allowPrivate,
      );
      final address = addresses.firstWhere(
        (address) => address.type == InternetAddressType.IPv4,
        orElse: () => addresses.first,
      );
      client = HttpClient()
        ..autoUncompress = false
        ..connectionTimeout = _connectTimeout
        ..idleTimeout = _streamTimeout;
      final current = client;
      current.findProxy = (_) => 'DIRECT';
      // HttpClient performs TLS using the original URI host after connecting.
      // Connecting to the checked IP avoids DNS-rebinding between validation
      // and the HTTP client's own DNS lookup.
      current.connectionFactory = (uri, proxyHost, proxyPort) {
        return Socket.startConnect(address, uri.port);
      };
      final outgoing = await current
          .openUrl(
            req.method == 'HEAD'
                ? 'HEAD'
                : session?['method'] as String? ?? req.method,
            target,
          )
          .timeout(_connectTimeout);
      outgoing.followRedirects = false;
      headers.forEach(outgoing.headers.set);
      outgoing.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (req.method != 'HEAD' && session?['body'] != null)
        outgoing.write(session!['body']);
      final upstream = await outgoing.close().timeout(_responseTimeout);
      final location = upstream.headers.value(HttpHeaders.locationHeader);
      if (_redirectStatuses.contains(upstream.statusCode) && location != null) {
        current.close(force: true);
        client = null;
        if (redirects >= 5) return _error(502, 'too many media redirects');
        final next = target.resolve(location);
        final blocked = proxyTargetError(
          next.toString(),
          allowPrivate: allowPrivate,
        );
        if (blocked != null) return _error(400, blocked);
        if (next.origin != target.origin) {
          headers = Map.of(headers)
            ..remove(HttpHeaders.authorizationHeader)
            ..remove(HttpHeaders.cookieHeader);
        }
        target = next;
        continue;
      }
      final responseHeaders = _responseHeaders(upstream);
      if (req.method == 'HEAD' ||
          upstream.statusCode == HttpStatus.noContent ||
          upstream.statusCode == HttpStatus.notModified ||
          upstream.contentLength == 0) {
        current.close(force: true);
        client = null;
        return Response(upstream.statusCode, headers: responseHeaders);
      }
      if (upstream.statusCode == HttpStatus.ok &&
          _isPlaylist(target, upstream)) {
        final playlist = await _readPlaylist(
          upstream,
        ).timeout(_responseTimeout);
        current.close(force: true);
        client = null;
        final playlistHeaders = Map<String, String>.of(headers)
          ..remove('range')
          ..remove('if-range');
        final rewritten = utf8.encode(
          _rewritePlaylist(
            playlist,
            target,
            playlistHeaders,
            query['sid'],
            session?['cookieJar'],
          ),
        );
        responseHeaders
          ..remove('content-encoding')
          ..remove('content-range')
          ..remove('accept-ranges')
          ..remove('etag')
          ..remove('last-modified')
          ..['content-type'] = 'application/vnd.apple.mpegurl; charset=utf-8'
          ..['content-length'] = '${rewritten.length}';
        return Response.ok(rewritten, headers: responseHeaders);
      }
      // Ownership of the HTTP client moves to the body stream here.
      client = null;
      return Response(
        upstream.statusCode,
        body: _streamBody(upstream, current),
        headers: responseHeaders,
      );
    }
  } on _BlockedTarget catch (error) {
    return _error(400, error.message);
  } on TimeoutException {
    return _error(504, 'media upstream timed out');
  } catch (_) {
    // URLs and source headers can contain credentials; do not echo exceptions.
    return _error(502, 'media upstream unavailable');
  } finally {
    client?.close(force: true);
  }
}

const _redirectStatuses = {301, 302, 303, 307, 308};
const _transportHeaders = {
  'host',
  'connection',
  'proxy-connection',
  'proxy-authorization',
  'content-length',
  'transfer-encoding',
  'expect',
  'upgrade',
  'trailer',
  'te',
};

Map<String, String> _sourceHeaders(String? value) {
  if (value == null || value.isEmpty) return {};
  if (value.length > 32768) throw const FormatException();
  final decoded = jsonDecode(value);
  if (decoded is! Map || decoded.length > 64) throw const FormatException();
  final result = <String, String>{};
  final token = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");
  for (final entry in decoded.entries) {
    if (entry.key is! String || entry.value is! String) {
      throw const FormatException();
    }
    final name = (entry.key as String).toLowerCase();
    final content = entry.value as String;
    if (!token.hasMatch(name) || content.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException();
    }
    if (!_transportHeaders.contains(name)) result[name] = content;
  }
  return result;
}

Future<List<InternetAddress>> _resolveTarget(
  Uri target, {
  required bool allowPrivate,
}) async {
  final error = proxyTargetError(target.toString(), allowPrivate: allowPrivate);
  if (error != null) throw _BlockedTarget(error);
  final host = target.host.replaceAll(RegExp(r'^\[|\]$'), '');
  final literal = InternetAddress.tryParse(host);
  final addresses = literal != null
      ? [literal]
      : await InternetAddress.lookup(host).timeout(_connectTimeout);
  if (addresses.isEmpty) throw const SocketException('no media address');
  if (addresses.any(
    (address) =>
        isBlockedProxyHost(address.address, allowPrivate: allowPrivate),
  )) {
    throw const _BlockedTarget('target resolved to a non-routable address');
  }
  return addresses;
}

Map<String, String> _responseHeaders(HttpClientResponse response) {
  final headers = <String, String>{
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
    // The endpoint serves media, never a same-origin executable document.
    'content-security-policy': 'sandbox',
  };
  for (final name in const [
    'content-type',
    'content-length',
    'content-range',
    'accept-ranges',
    'content-encoding',
    'etag',
    'last-modified',
  ]) {
    final value = response.headers.value(name);
    if (value != null) headers[name] = value;
  }
  return headers;
}

Stream<List<int>> _streamBody(HttpClientResponse response, HttpClient client) {
  StreamSubscription<List<int>>? subscription;
  var closed = false;
  Future<void> release() async {
    if (closed) return;
    closed = true;
    client.close(force: true);
    await subscription?.cancel();
  }

  late final StreamController<List<int>> body;
  body = StreamController<List<int>>(
    onListen: () {
      subscription = response
          .timeout(_streamTimeout)
          .listen(
            (chunk) {
              if (!closed) body.add(chunk);
            },
            onError: (Object error, StackTrace stack) {
              if (closed) return;
              body.addError(
                error is TimeoutException
                    ? TimeoutException('media stream timed out')
                    : StateError('media upstream stream failed'),
                stack,
              );
              unawaited(body.close());
              unawaited(release());
            },
            onDone: () {
              unawaited(body.close());
              unawaited(release());
            },
            cancelOnError: true,
          );
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: release,
  );
  return body.stream;
}

bool _isPlaylist(Uri target, HttpClientResponse response) =>
    target.path.toLowerCase().endsWith('.m3u8') ||
    (response.headers.contentType?.mimeType.toLowerCase().contains('mpegurl') ??
        false);

Future<String> _readPlaylist(HttpClientResponse response) async {
  Stream<List<int>> stream = response;
  switch (response.headers.value('content-encoding')?.toLowerCase()) {
    case 'gzip':
      stream = stream.transform(gzip.decoder);
      break;
    case 'deflate':
      stream = stream.transform(zlib.decoder);
      break;
    case null:
    case 'identity':
      break;
    default:
      throw const FormatException('unsupported playlist encoding');
  }
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream.timeout(_streamTimeout)) {
    if (bytes.length + chunk.length > _maxPlaylistBytes) {
      throw const FormatException('media playlist too large');
    }
    bytes.add(chunk);
  }
  return utf8.decode(bytes.takeBytes());
}

String _rewritePlaylist(
  String playlist,
  Uri source,
  Map<String, String> headers,
  String? parent,
  Object? jar,
) {
  String resource(String value) {
    final resolved = source.resolve(value);
    if (resolved.scheme != 'http' && resolved.scheme != 'https') return value;
    final scoped = Map<String, String>.from(headers);
    if (resolved.origin != source.origin) {
      scoped.remove('cookie');
      scoped.remove('authorization');
    }
    final cookie = jar is Map
        ? jar[CookieStore.domainOf(resolved.toString())]
        : null;
    if (cookie is String && cookie.isNotEmpty) scoped['cookie'] = cookie;
    final sid = MediaPlaybackSessions.instance.create({
      'url': resolved.toString(),
      'headers': scoped,
      'cookieJar': jar,
    }, parent: parent);
    return Uri(path: '/proxy/media', queryParameters: {'sid': sid}).toString();
  }

  final uriAttribute = RegExp(r'URI="([^"]*)"', caseSensitive: false);
  return playlist
      .split('\n')
      .map((line) {
        final clean = line.trim();
        if (clean.isEmpty) return line;
        if (clean.startsWith('#')) {
          return line.replaceAllMapped(
            uriAttribute,
            (match) => 'URI="${resource(match[1]!)}"',
          );
        }
        return '${resource(clean)}${line.endsWith('\r') ? '\r' : ''}';
      })
      .join('\n');
}

Response _error(int code, String message) => Response(
  code,
  body: jsonEncode({'error': message}),
  headers: const {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  },
);

class _BlockedTarget implements Exception {
  const _BlockedTarget(this.message);
  final String message;
}
