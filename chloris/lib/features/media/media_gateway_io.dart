import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import '../../services/web/media_proxy_io.dart';
import 'audio_types.dart';
import 'audio_file_store_io.dart';

class MediaGateway {
  static final instance = MediaGateway();
  Future<HttpServer>? _starting;
  final _sessions = <String>{};
  final _offline = <String, String>{};
  Future<HttpServer> _ensure() => _starting ??= shelf_io
      .serve(_handle, InternetAddress.loopbackIPv4, 0)
      .catchError((Object e) {
        _starting = null;
        throw e;
      });
  Future<Response> _handle(Request request) async {
    if (request.url.path == 'proxy/media') {
      return proxyMedia(request, allowPrivate: true);
    }
    final parts = request.url.pathSegments;
    if (parts.length == 3 &&
        parts[0] == 'offline' &&
        _offline[parts[1]] == parts[2]) {
      final f = await AudioFileStore().file(parts[2]);
      if (!await f.exists()) return Response.notFound('音频文件不存在');
      final size = await f.length();
      var start = 0, end = size - 1;
      final range = RegExp(
        r'^bytes=(\d+)-(\d*)$',
      ).firstMatch(request.headers['range'] ?? '');
      if (range != null) {
        start = int.parse(range[1]!);
        end = range[2]!.isEmpty ? end : int.parse(range[2]!).clamp(0, end);
      }
      if (start > end || start >= size) {
        return Response(416, headers: {'content-range': 'bytes */$size'});
      }
      return Response(
        range == null ? 200 : 206,
        body: request.method == 'HEAD' ? null : f.openRead(start, end + 1),
        headers: {
          'content-type': _mime(parts[2]),
          'accept-ranges': 'bytes',
          'content-length': '${end - start + 1}',
          if (range != null) 'content-range': 'bytes $start-$end/$size',
        },
      );
    }
    return Response.notFound('Not found');
  }

  String _mime(String key) => key.endsWith('.m3u8')
      ? 'application/vnd.apple.mpegurl'
      : key.endsWith('.mp3')
      ? 'audio/mpeg'
      : key.endsWith('.m4a')
      ? 'audio/mp4'
      : key.endsWith('.aac')
      ? 'audio/aac'
      : 'application/octet-stream';
  Future<String> prepare(MediaRequestSpec request) async {
    final server = await _ensure();
    final sid = MediaPlaybackSessions.instance.create(request.toJson());
    _sessions.add(sid);
    return 'http://127.0.0.1:${server.port}/proxy/media?sid=$sid';
  }

  Future<void> release(String url) async {
    final sid = Uri.tryParse(url)?.queryParameters['sid'];
    if (sid != null && _sessions.remove(sid)) {
      MediaPlaybackSessions.instance.release(sid);
    }
  }

  Future<void> dispose() async {
    for (final sid in _sessions) {
      MediaPlaybackSessions.instance.release(sid);
    }
    _sessions.clear();
    _offline.clear();
    final active = _starting;
    _starting = null;
    if (active != null) await (await active).close(force: true);
  }
}
