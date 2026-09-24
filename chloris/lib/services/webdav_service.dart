import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// 简易 WebDAV 客户端（PUT/GET/DELETE/MKCOL/PROPFIND + Basic 认证）。
class WebDavClient {
  WebDavClient({required this.baseUrl, this.username = '', this.password = ''})
      : _client = http.Client();

  final String baseUrl;
  final String username;
  final String password;
  final http.Client _client;

  Map<String, String> get _headers {
    final h = <String, String>{'Accept': '*/*'};
    if (username.isNotEmpty) {
      h['Authorization'] =
          'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    }
    return h;
  }

  Uri _uri(String path) =>
      Uri.parse(baseUrl + (path.startsWith('/') ? path : '/$path'));

  Future<http.Response> _send(String method, String path,
      {Map<String, String>? headers, Object? body}) async {
    final req = http.Request(method, _uri(path));
    req.headers.addAll(_headers);
    req.headers.addAll(headers ?? const {});
    if (body != null) req.bodyBytes = body is Uint8List ? body : utf8.encode(body.toString());
    final streamed = await _client.send(req);
    return http.Response.fromStream(streamed);
  }

  Future<bool> mkdir(String path) async =>
      (await _send('MKCOL', path)).statusCode < 400;

  Future<bool> putFile(String path, Uint8List bytes) async =>
      (await _send('PUT', path, body: bytes)).statusCode < 400;

  Future<Uint8List?> getFile(String path) async {
    final res = await _send('GET', path);
    return res.statusCode < 400 ? res.bodyBytes : null;
  }

  Future<bool> delete(String path) async =>
      (await _send('DELETE', path)).statusCode < 400;

  Future<List<String>> list(String path) async {
    final res = await _send('PROPFIND', path, headers: {'Depth': '1'});
    if (res.statusCode >= 400) return const [];
    return parseWebDavList(res.body);
  }
}

/// 解析 WebDAV PROPFIND 多状态响应，返回 href 列表（目录以 / 结尾）。
List<String> parseWebDavList(String body) {
  try {
    final doc = XmlDocument.parse(body);
    final out = <String>[];
    for (final response in doc.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'response')) {
      final href = response.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'href')
          .map((e) => e.innerText.trim())
          .firstWhere((e) => e.isNotEmpty, orElse: () => '');
      final isColl = response.descendants
          .whereType<XmlElement>()
          .any((e) => e.name.local == 'collection');
      if (href.isNotEmpty) out.add('$href${isColl ? '/' : ''}');
    }
    return out;
  } catch (_) {
    return const [];
  }
}
