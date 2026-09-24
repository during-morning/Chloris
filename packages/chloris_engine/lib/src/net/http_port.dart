import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_convert/enough_convert.dart';
import 'package:http/http.dart' as http;

import '../local/encoding_detect.dart';
import 'client_factory.dart' if (dart.library.io) 'client_factory_io.dart';
import 'engine_limits.dart';
import 'str_response.dart';

class HttpCancelledException implements Exception {
  const HttpCancelledException();

  @override
  String toString() => 'HttpCancelledException';
}

class HttpRequestSpec {
  const HttpRequestSpec({
    required this.url,
    this.method = 'GET',
    this.headers = const {},
    this.body,
    this.charset,
    this.retry = 0,
    this.timeout,
    this.origin,
    this.dnsIp,
    this.serverID,
    this.proxy,
  });

  final String url;
  final String method;
  final Map<String, String> headers;
  final String? body;
  final String? charset;
  final int retry;
  final Duration? timeout;

  /// Optional Legado routing metadata. Native ports may ignore these while
  /// proxy ports forward them to the server-side transport.
  final String? origin;
  final String? dnsIp;
  final String? serverID;
  final String? proxy;

  Duration get effectiveTimeout => timeout ?? EngineLimits.httpTimeout;
}

abstract class HttpPort {
  Future<StrResponse> send(HttpRequestSpec spec);

  Future<Uint8List> getBytes(String url, {Map<String, String>? headers});

  /// Drop in-flight requests (dispose). Must not close the shared client
  /// in a way that kills unrelated sessions; bump an epoch instead.
  void cancelInFlight() {}
}

/// Optional capability: cancel one logical session without killing others.
abstract class SessionAwareHttp {
  void cancelSession(String session);
}

/// Search/explore may run dozens of requests at once. Interactive sessions
/// (detail, TOC, content) must not share that connection pool, and cancelling
/// search must abort those sockets immediately.
bool isBackgroundHttpSession(String? session) =>
    session == 'search' || session == 'explore';

class PackageHttpPort implements HttpPort, SessionAwareHttp {
  PackageHttpPort({http.Client? client, http.Client? backgroundClient})
    : _ownsBackground = backgroundClient == null && client == null,
      _interactive = client ?? createHttpClient(),
      _background = backgroundClient ?? client ?? createHttpClient();

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
      _background = createHttpClient();
    }
  }

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
    final session = Zone.current[#chlorisHttpSession] as String?;
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
    Object? lastError;
    http.Response? response;
    final epoch = _mark(session);
    bool cancelled() => epoch != _mark(session);
    for (var i = 0; i <= spec.retry; i++) {
      if (cancelled()) throw const HttpCancelledException();
      try {
        final uri = Uri.parse(spec.url);
        final headers = Map<String, String>.from(spec.headers);
        final method = spec.method.toUpperCase();
        final timeout = spec.effectiveTimeout;
        final client = _clientFor(session);
        if (method == 'POST') {
          response = await client
              .post(
                uri,
                headers: headers,
                body: HttpBodyDecoder.encodeRequestBody(spec.body, spec.charset),
              )
              .timeout(timeout);
        } else if (method == 'HEAD') {
          response = await client.head(uri, headers: headers).timeout(timeout);
        } else {
          response = await client.get(uri, headers: headers).timeout(timeout);
        }
        if (cancelled()) throw const HttpCancelledException();
        lastError = null;
        if (response.statusCode >= 200 && response.statusCode < 500) {
          break;
        }
        if (i < spec.retry) {
          await Future<void>.delayed(
            Duration(milliseconds: 120 * (1 << i.clamp(0, 4))),
          );
        }
      } on HttpCancelledException {
        rethrow;
      } catch (e) {
        if (cancelled()) throw const HttpCancelledException();
        lastError = e;
        if (i == spec.retry) rethrow;
      }
    }
    if (response == null) {
      throw lastError ?? StateError('empty http response');
    }
    // A terminal 5xx is a transport failure even when the server returned an
    // HTML error page.  Returning it as a successful StrResponse lets the
    // content selector cache an error document as a chapter and is the most
    // common cause of apparently empty/phantom chapters.  Keep 4xx bodies
    // available so AnalyzeUrl can classify login/captcha walls.
    if (response.statusCode >= 500) {
      throw lastError ?? StateError('HTTP ${response.statusCode} ${spec.url}');
    }
    final headerMap = <String, String>{};
    response.headers.forEach((k, v) => headerMap[k] = v);
    String? body;
    try {
      body = _decodeBody(response, spec.charset);
    } catch (_) {
      body = latin1.decode(response.bodyBytes, allowInvalid: true);
    }
    return StrResponse(
      url: response.request?.url.toString() ?? spec.url,
      body: body,
      code: response.statusCode,
      headers: headerMap,
      error: lastError,
    );
  }

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async {
    Object? last;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _interactive
            .get(Uri.parse(url), headers: headers)
            .timeout(EngineLimits.httpTimeout);
        if (response.statusCode >= 500 && attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 120 * (1 << attempt)),
          );
          continue;
        }
        if (response.statusCode >= 400) {
          throw StateError('HTTP ${response.statusCode} $url');
        }
        return response.bodyBytes;
      } catch (error) {
        last = error;
        if (attempt < 2) {
          await Future<void>.delayed(
            Duration(milliseconds: 120 * (1 << attempt)),
          );
        }
      }
    }
    throw last ?? StateError('empty http response');
  }

  static String _decodeBody(http.Response response, String? charset) {
    return HttpBodyDecoder.decode(
      response.bodyBytes,
      charset: charset,
      contentType: response.headers['content-type'],
    );
  }
}

/// Shared by native HTTP and the Web same-origin proxy so GBK/Big5 pages
/// do not become mojibake and then get dropped by search matching.
class HttpBodyDecoder {
  static String decode(
    List<int> bytes, {
    String? charset,
    String? contentType,
  }) {
    if (bytes.isEmpty) return '';
    if (charset != null && charset.trim().isNotEmpty) {
      return CharsetDecoder.decode(bytes, charset);
    }
    final ct = contentType ?? '';
    final headerCs = RegExp(
      r'charset\s*=\s*([^\s;]+)',
      caseSensitive: false,
    ).firstMatch(ct);
    if (headerCs != null) {
      return CharsetDecoder.decode(bytes, headerCs.group(1)!);
    }
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final sniff = EncodingDetect.getEncode(data);
    return EncodingDetect.decode(data, sniff);
  }

  /// Form bodies that are already percent-encoded stay ASCII. Unencoded
  /// Chinese text is encoded with the source charset so GBK sites receive
  /// the bytes they expect.
  static Object encodeRequestBody(String? body, String? charset) {
    if (body == null || body.isEmpty) return '';
    if (charset == null || charset.trim().isEmpty) return body;
    final name = charset.toLowerCase().replaceAll('-', '');
    if (name.contains('utf8') || name.contains('utf-8')) return body;
    if (RegExp(r'^[\x00-\x7F]*$').hasMatch(body)) return body;
    return CharsetEncoder.encode(body, charset);
  }
}

class CharsetEncoder {
  static List<int> encode(String text, String charset) {
    if (text.isEmpty) return const [];
    final name = charset.toLowerCase().replaceAll('-', '');
    if (name.contains('gb')) {
      return const GbkCodec(allowInvalid: true).encode(text);
    }
    if (name.contains('big5') || name == 'cp950' || name == '950') {
      return const Big5Codec(allowInvalid: true).encode(text);
    }
    return utf8.encode(text);
  }
}

class CharsetDecoder {
  static String decode(List<int> bytes, String charset) {
    if (bytes.isEmpty) return '';
    // A BOM is authoritative and avoids treating UTF-16 payloads as a
    // sequence of unrelated Latin-1 control characters.
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe) {
      return _utf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
      return _utf16(bytes.sublist(2), littleEndian: false);
    }
    final name = charset.toLowerCase().replaceAll('-', '');
    if (name.contains('gb18030')) {
      return const GbkCodec(allowInvalid: true).decode(bytes);
    }
    if (name.contains('gbk') || name.contains('gb2312')) {
      return const GbkCodec(allowInvalid: true).decode(bytes);
    }
    if (name.contains('big5') || name == 'cp950' || name == '950') {
      return const Big5Codec(allowInvalid: true).decode(bytes);
    }
    if (name.contains('utf16le') || name == 'utf16' || name == 'utf16le') {
      return _utf16(bytes, littleEndian: true);
    }
    if (name.contains('utf16be')) {
      return _utf16(bytes, littleEndian: false);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Text → bytes under [charset]. Symmetric with [decode]; unknown charsets
  /// fall back to UTF-8.
  static Uint8List encode(String text, String charset) {
    final name = charset.toLowerCase().replaceAll('-', '');
    if (name.contains('gb18030') ||
        name.contains('gbk') ||
        name.contains('gb2312')) {
      return Uint8List.fromList(const GbkCodec(allowInvalid: false).encode(text));
    }
    if (name.contains('big5') || name == 'cp950' || name == '950') {
      return Uint8List.fromList(
        const Big5Codec(allowInvalid: false).encode(text),
      );
    }
    if (name.contains('utf16le') || name == 'utf16') {
      return _utf16Encode(text, littleEndian: true);
    }
    if (name.contains('utf16be')) {
      return _utf16Encode(text, littleEndian: false);
    }
    return Uint8List.fromList(utf8.encode(text));
  }

  static Uint8List _utf16Encode(String text, {required bool littleEndian}) {
    final b = BytesBuilder();
    for (final unit in text.codeUnits) {
      if (littleEndian) {
        b.addByte(unit & 0xff);
        b.addByte((unit >> 8) & 0xff);
      } else {
        b.addByte((unit >> 8) & 0xff);
        b.addByte(unit & 0xff);
      }
    }
    return b.toBytes();
  }

  static String _utf16(List<int> bytes, {required bool littleEndian}) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(
        littleEndian
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1],
      );
    }
    return String.fromCharCodes(units);
  }
}
