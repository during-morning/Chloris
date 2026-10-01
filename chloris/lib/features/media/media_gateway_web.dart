import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/web/server_connection.dart';
import 'audio_types.dart';

class MediaGateway {
  static final instance = MediaGateway();
  final _sessions = <String>{};
  Future<String> prepare(MediaRequestSpec request) async {
    final connection = await ServerConnection.load();
    final base = connection.isConfigured
        ? Uri.parse(connection.normalizedBaseUrl)
        : Uri.base;
    final response = await http.post(
      base.resolve('/api/music/v1/playback'),
      headers: {
        'content-type': 'application/json',
        if (connection.token.isNotEmpty)
          'authorization': 'Bearer ${connection.token}',
      },
      body: jsonEncode(request.toJson()),
    );
    if (response.statusCode != 200) throw StateError('媒体代理不可用，请连接 Chloris 服务');
    final json = jsonDecode(response.body);
    final id = json['data']?['id'] ?? json['id'];
    if (id is! String) throw const FormatException('播放会话响应无效');
    _sessions.add(id);
    return base
        .resolve('/proxy/media')
        .replace(queryParameters: {'sid': id})
        .toString();
  }

  Future<void> release(String url) async {
    final uri = Uri.tryParse(url), id = uri?.queryParameters['sid'];
    if (id == null || !_sessions.remove(id)) return;
    final connection = await ServerConnection.load();
    await http
        .delete(
          uri!.resolve('/api/music/v1/playback/$id'),
          headers: {
            if (connection.token.isNotEmpty)
              'authorization': 'Bearer ${connection.token}',
          },
        )
        .timeout(const Duration(seconds: 2))
        .catchError((Object _) => http.Response('', 503));
  }

  Future<void> dispose() async {
    _sessions.clear();
  }
}
