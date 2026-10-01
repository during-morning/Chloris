import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chloris/services/web/media_proxy_io.dart';
import 'package:chloris/services/web/proxy_target_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

Request mediaRequest(
  Uri target, {
  String method = 'GET',
  Map<String, String> sourceHeaders = const {},
  Map<String, String> requestHeaders = const {},
}) => Request(
  method,
  Uri.http('localhost:2328', '/proxy/media', {
    'url': target.toString(),
    if (sourceHeaders.isNotEmpty) 'headers': jsonEncode(sourceHeaders),
  }),
  headers: requestHeaders,
);

void main() {
  late HttpServer upstream;
  late Uri base;
  late Future<void> Function(HttpRequest request) serve;

  setUp(() async {
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${upstream.port}/');
    serve = (request) async {
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.write('audio');
      await request.response.close();
    };
    upstream.listen((request) async {
      try {
        await serve(request);
      } on HttpException {
        // A cancelled media stream intentionally closes its upstream socket.
      } on SocketException {
        // An oversized playlist is also aborted before the source finishes.
      }
    });
  });

  tearDown(() async {
    await upstream.close(force: true);
  });

  test(
    'rejects local targets by default before contacting the upstream',
    () async {
      var contacted = false;
      serve = (request) async {
        contacted = true;
        await request.response.close();
      };
      final response = await proxyMedia(mediaRequest(base));
      expect(response.statusCode, 400);
      expect(contacted, isFalse);
      expect(await response.readAsString(), contains('not routable'));
    },
  );

  test('checks mapped IPv6 and special IPv4 address ranges', () {
    for (final host in [
      '::',
      '::ffff:127.0.0.1',
      '::ffff:192.168.0.1',
      '100.64.0.1',
      '198.18.0.1',
      '2001:db8::1',
    ]) {
      expect(isBlockedProxyHost(host), isTrue, reason: host);
    }
    expect(isBlockedProxyHost('2606:4700::1111'), isFalse);
    expect(proxyTargetError('http://user:secret@example.com/a'), isNotNull);
    expect(proxyTargetError('https:///audio'), isNotNull);
  });

  test(
    'forwards seek ranges and source credentials while streaming a 206',
    () async {
      late HttpHeaders received;
      serve = (request) async {
        received = request.headers;
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers
          ..contentType = ContentType('audio', 'mpeg')
          ..set('content-range', 'bytes 2-5/10')
          ..set('accept-ranges', 'bytes')
          ..set('etag', 'source-v1');
        request.response.contentLength = 4;
        request.response.write('2345');
        await request.response.close();
      };
      final response = await proxyMedia(
        mediaRequest(
          base.resolve('song.mp3'),
          sourceHeaders: {
            'Referer': 'https://source.example/player',
            'Cookie': 'music=session',
            'Range': 'bytes=0-',
            'Host': 'must-not-be-forwarded.example',
          },
          requestHeaders: {'range': 'bytes=2-5', 'if-range': 'source-v1'},
        ),
        allowPrivate: true,
      );
      expect(response.statusCode, 206);
      expect(response.headers['content-type'], startsWith('audio/mpeg'));
      expect(response.headers['content-length'], '4');
      expect(response.headers['content-range'], 'bytes 2-5/10');
      expect(response.headers['accept-ranges'], 'bytes');
      expect(response.headers['cache-control'], 'no-store');
      expect(await response.readAsString(), '2345');
      expect(received.value('range'), 'bytes=2-5');
      expect(received.value('if-range'), 'source-v1');
      expect(received.value('referer'), 'https://source.example/player');
      expect(received.value('cookie'), 'music=session');
      expect(received.value('host'), '127.0.0.1:${upstream.port}');
    },
  );

  test('returns response headers before the entire audio finishes', () async {
    final finish = Completer<void>();
    serve = (request) async {
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.write('first');
      await request.response.flush();
      await finish.future;
      request.response.write('last');
      await request.response.close();
    };
    try {
      final response = await proxyMedia(
        mediaRequest(base.resolve('large.mp3')),
        allowPrivate: true,
      ).timeout(const Duration(seconds: 2));
      expect(finish.isCompleted, isFalse);
      finish.complete();
      expect(await response.readAsString(), 'firstlast');
    } finally {
      if (!finish.isCompleted) finish.complete();
    }
  });

  test('HEAD retains media metadata without a response body', () async {
    late String method;
    serve = (request) async {
      method = request.method;
      request.response.headers
        ..contentType = ContentType('audio', 'flac')
        ..set('accept-ranges', 'bytes');
      request.response.contentLength = 500;
      await request.response.close();
    };
    final response = await proxyMedia(
      mediaRequest(base.resolve('song.flac'), method: 'HEAD'),
      allowPrivate: true,
    );
    expect(method, 'HEAD');
    expect(response.statusCode, 200);
    expect(response.headers['content-length'], '500');
    expect(await response.readAsString(), isEmpty);
  });

  test('cancelling the body closes the upstream connection', () async {
    final disconnected = Completer<void>();
    serve = (request) async {
      request.response.headers.contentLength=1000000000;
      final socket=await request.response.detachSocket();
      socket.add(utf8.encode('first'*2048));await socket.flush();
      socket.listen((_) {},onDone:(){if(!disconnected.isCompleted)disconnected.complete();socket.destroy();},onError:(Object _){if(!disconnected.isCompleted)disconnected.complete();socket.destroy();});
    };
    final response = await proxyMedia(
      mediaRequest(base.resolve('live.mp3')),
      allowPrivate: true,
    );
    final firstChunk = Completer<void>();
    final subscription = response.read().listen((_) {
      if (!firstChunk.isCompleted) firstChunk.complete();
    });
    await firstChunk.future.timeout(const Duration(seconds: 2),onTimeout:()=>throw StateError('未收到上游数据'));
    await subscription.cancel();
    await disconnected.future.timeout(const Duration(seconds: 2),onTimeout:()=>throw StateError('取消后上游未关闭'));
  });

  test('same-origin redirects retain source authorization', () async {
    final credentials = <String?>[];
    serve = (request) async {
      credentials.add(request.headers.value('authorization'));
      if (request.uri.path == '/start') {
        request.response.statusCode = HttpStatus.temporaryRedirect;
        request.response.headers.set('location', '/song.mp3');
      } else {
        request.response.write('same-origin');
      }
      await request.response.close();
    };
    final response = await proxyMedia(
      mediaRequest(
        base.resolve('start'),
        sourceHeaders: {'Authorization': 'Bearer song-token'},
      ),
      allowPrivate: true,
    );
    expect(await response.readAsString(), 'same-origin');
    expect(credentials, ['Bearer song-token', 'Bearer song-token']);
  });

  test('cross-origin redirects remove authorization and cookie', () async {
    final other = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    late HttpHeaders received;
    other.listen((request) async {
      received = request.headers;
      request.response.write('redirected');
      await request.response.close();
    });
    serve = (request) async {
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(
        'location',
        'http://127.0.0.1:${other.port}/song',
      );
      await request.response.close();
    };
    try {
      final response = await proxyMedia(
        mediaRequest(
          base.resolve('start'),
          sourceHeaders: {
            'Authorization': 'Bearer private-token',
            'Cookie': 'session=secret',
            'Referer': 'https://source.example/player',
          },
        ),
        allowPrivate: true,
      );
      expect(await response.readAsString(), 'redirected');
      expect(received.value('authorization'), isNull);
      expect(received.value('cookie'), isNull);
      expect(received.value('referer'), 'https://source.example/player');
    } finally {
      await other.close(force: true);
    }
  });

  test('redirect loops stop after five hops', () async {
    var hits = 0;
    serve = (request) async {
      hits++;
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set('location', '/loop');
      await request.response.close();
    };
    final response = await proxyMedia(
      mediaRequest(base.resolve('loop')),
      allowPrivate: true,
    );
    expect(response.statusCode, 502);
    expect(hits, 6);
  });

  test(
    'redirect targets are validated even with private access enabled',
    () async {
      serve = (request) async {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set('location', 'file:///tmp/not-a-song');
        await request.response.close();
      };
      final response = await proxyMedia(
        mediaRequest(base.resolve('redirect')),
        allowPrivate: true,
      );
      expect(response.statusCode, 400);
    },
  );

  test(
    'rewrites HLS variants, segments, keys and maps with source headers',
    () async {
      serve = (request) async {
        request.response.headers.contentType = ContentType(
          'application',
          'vnd.apple.mpegurl',
        );
        request.response.write('''#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=128000
variants/audio.m3u8
#EXT-X-KEY:METHOD=AES-128,URI="../keys/key.bin"
#EXT-X-MAP:URI="init.mp4"
#EXTINF:3,
segment-1.ts
#EXTINF:3,
https://cdn.example/segment-2.ts
''');
        await request.response.close();
      };
      final response = await proxyMedia(
        mediaRequest(
          base.resolve('albums/master.m3u8'),
          sourceHeaders: {
            'Cookie': 'music=secret',
            'Referer': 'https://source.example',
          },
        ),
        allowPrivate: true,
      );
      final playlist = await response.readAsString();
      final references = <String>[
        ...playlist.split('\n').where((line) => line.startsWith('/proxy/')),
        ...RegExp(r'URI="([^"]*)"').allMatches(playlist).map((m) => m[1]!),
      ];
      expect(references, hasLength(5));
      final targets = <String>[];
      for (final reference in references) {
        final uri = Uri.parse(reference);
        expect(uri.path, '/proxy/media');
        expect(uri.queryParameters.containsKey('headers'), false);
        expect(uri.queryParameters.containsKey('url'), false);
        final session = MediaPlaybackSessions.instance.take(
          uri.queryParameters['sid'],
        )!;
        targets.add(session['url'] as String);
        final headers = session['headers'] as Map;
        expect(
          headers['cookie'],
          session['url'].toString().contains('cdn.example')
              ? isNull
              : 'music=secret',
        );
        expect(headers['referer'], 'https://source.example');
      }
      expect(
        targets,
        containsAll([
          base.resolve('albums/variants/audio.m3u8').toString(),
          base.resolve('albums/segment-1.ts').toString(),
          'https://cdn.example/segment-2.ts',
          base.resolve('keys/key.bin').toString(),
          base.resolve('albums/init.mp4').toString(),
        ]),
      );
      expect(
        response.headers['content-length'],
        '${utf8.encode(playlist).length}',
      );
    },
  );

  test(
    'limits HLS playlist size while allowing audio to stream unbounded',
    () async {
      serve = (request) async {
        request.response.headers.contentType = ContentType(
          'audio',
          'x-mpegurl',
        );
        request.response.write('x' * (2 * 1024 * 1024 + 1));
        await request.response.close();
      };
      final response = await proxyMedia(
        mediaRequest(base.resolve('huge.m3u8')),
        allowPrivate: true,
      );
      expect(response.statusCode, 502);
      expect(await response.readAsString(), contains('unavailable'));
    },
  );

  test(
    'rejects methods and malformed headers without echoing credentials',
    () async {
      final denied = await proxyMedia(mediaRequest(base, method: 'POST'));
      expect(denied.statusCode, 405);
      expect(denied.headers['allow'], 'GET, HEAD');
      final malformed = await proxyMedia(
        mediaRequest(
          base,
          sourceHeaders: {'Cookie': 'secret\r\nInjected: value'},
        ),
        allowPrivate: true,
      );
      expect(malformed.statusCode, 400);
      expect(await malformed.readAsString(), isNot(contains('secret')));
    },
  );
}
