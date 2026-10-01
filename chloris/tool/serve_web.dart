// Serves Flutter web build + server-side HTTP proxy on one origin.
//
//   dart run tool/serve_web.dart [port] [--host=0.0.0.0]
//
// Loopback by default: binding every interface would expose the proxy — and
// with it the developer's own network — to the whole LAN.
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import 'package:chloris/services/web/server_io.dart';
import 'package:chloris/services/web/media_proxy_io.dart';
import 'package:chloris/services/web/browser_worker_io.dart';

/// CORS for a local development server.
///
/// A wildcard here would let any site the developer happens to visit drive the
/// proxy and read its responses, so only this machine's own pages are allowed —
/// the same rule the in-app server follows.
Map<String, String> _corsFor(Request req) {
  final origin = req.headers['origin'];
  if (origin == null || !isLoopbackOrigin(origin)) return const {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, HEAD, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Vary': 'Origin',
  };
}

Future<void> main(List<String> args) async {
  final flags = args.where((a) => a.startsWith('--')).toList();
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final port = positional.isNotEmpty ? int.parse(positional.first) : 2328;
  final bindAll = flags.contains('--host=0.0.0.0');
  final address = bindAll
      ? InternetAddress.anyIPv4
      : InternetAddress.loopbackIPv4;

  final webDir = Directory('build/web');
  if (!webDir.existsSync()) {
    stderr.writeln('missing build/web — run flutter build web first');
    exit(1);
  }
  final staticHandler = createStaticHandler(
    webDir.path,
    defaultDocument: 'index.html',
    serveFilesOutsidePath: false,
  );
  final router = Router();

  /// Rejects targets this machine must not reach, exactly as the in-app server
  /// does. Without it this tool is an open proxy onto the local network.
  Response? blockedTarget(Object? rawUrl) {
    final blocked = proxyTargetError(rawUrl?.toString() ?? '');
    if (blocked == null) return null;
    return Response.badRequest(
      body: jsonEncode({'error': blocked}),
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  router.post('/proxy/http', (Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final blocked = blockedTarget(body['url']);
    if (blocked != null) return blocked;
    return Response.ok(
      jsonEncode(await proxyHttp(body)),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  router.post('/proxy/bytes', (Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final blocked = blockedTarget(body['url']);
    if (blocked != null) return blocked;
    return Response.ok(
      jsonEncode(await proxyBytes(body)),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  final browser = BrowserWorker();
  router.post('/api/music/v1/browser', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final blocked = blockedTarget(body['url']);
      if (blocked != null) return blocked;
      return Response.ok(
        jsonEncode(await browser.run(body)),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.ok(
        jsonEncode({'error': '$e'}),
        headers: {'content-type': 'application/json'},
      );
    }
  });
  router.delete('/api/music/v1/browser/<id>', (Request req, String id) {
    browser.cancel(id);
    return Response.ok('{}');
  });
  router.post('/api/music/v1/playback', (Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final blocked = blockedTarget(body['url']);
    if (blocked != null) return blocked;
    return Response.ok(
      jsonEncode({'id': MediaPlaybackSessions.instance.create(body)}),
      headers: {'content-type': 'application/json'},
    );
  });
  router.delete('/api/music/v1/playback/<id>', (Request req, String id) {
    MediaPlaybackSessions.instance.release(id);
    return Response.ok('{}');
  });
  router.get('/proxy/media', (Request req) => proxyMedia(req));
  router.head('/proxy/media', (Request req) => proxyMedia(req));
  router.get('/proxy/img', (Request req) async {
    final url = req.url.queryParameters['u'] ?? '';
    final blocked = blockedTarget(url);
    if (blocked != null) return blocked;
    final hit = await proxyImage(url);
    if (hit == null || hit.code >= 400) {
      return Response.notFound('img');
    }
    return Response.ok(
      hit.bytes,
      headers: {
        'content-type': hit.contentType,
        'cache-control': 'public, max-age=86400',
      },
    );
  });

  Handler cascade = (Request req) async {
    if (req.method == 'OPTIONS') {
      return Response.ok('', headers: _corsFor(req));
    }
    if (req.url.path.startsWith('proxy/') ||
        req.url.path.startsWith('api/music/')) {
      return router.call(req);
    }
    return staticHandler(req);
  };
  // 应用壳必须每次回源协商，否则重编后浏览器端出的还是旧包（见下）。
  //
  // shelf 的静态处理器只回 `Last-Modified`、没有 `Cache-Control`，浏览器会退回
  // **启发式缓存**：按文件年龄的约 10% 直接用本地副本、不回源确认。后果是
  // `flutter build web` 之后浏览器仍然端出几小时前的 `main.dart.js`，而且毫无提示。
  // 只有 `canvaskit/` 例外 —— Flutter 按版本存放它，可以长缓存。
  cascade = const Pipeline()
      .addMiddleware((inner) {
        return (req) async {
          final res = await inner(req);
          // 顺序无关的两件事一起补：CORS（只放行本机页面）+ 禁止陈旧缓存。
          final immutable = req.url.path.startsWith('canvaskit/');
          return res.change(
            headers: {
              ..._corsFor(req),
              'cache-control': immutable
                  ? 'public, max-age=31536000, immutable'
                  : 'no-cache, must-revalidate',
            },
          );
        };
      })
      .addHandler(cascade);

  final server = await shelf_io.serve(cascade, address, port);
  final shown = bindAll ? '0.0.0.0' : '127.0.0.1';
  stdout.writeln('Cholris web+proxy http://$shown:${server.port}/');
}
