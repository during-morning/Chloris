import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chloris/services/web/server_io.dart';
import 'package:chloris/services/web/api_contract.dart';
import 'package:chloris/services/web/server_backend.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend implements ServerBackend {
  final saved = <String, Map<String, dynamic>>{};
  final deleted = <String>[];
  final progressed = <Map<String, dynamic>>[];
  bool refreshRequested = false;

  @override
  Future<List<Map<String, dynamic>>> bookshelf() async =>
      [for (final b in saved.values) b];

  @override
  Future<void> saveBook(Map<String, dynamic> book) async {
    saved[book['bookUrl']?.toString() ?? ''] = book;
  }

  @override
  Future<void> deleteBook(String bookUrl) async {
    deleted.add(bookUrl);
    saved.remove(bookUrl);
  }

  @override
  Future<void> saveProgress(Map<String, dynamic> progress) async {
    progressed.add(progress);
  }

  @override
  Future<List<Map<String, dynamic>>> chapterList(
    String bookUrl, {
    bool refresh = false,
  }) async {
    if (refresh) refreshRequested = true;
    return [
      {'url': '$bookUrl/c1', 'title': '第一章', 'index': 0},
      {'url': '$bookUrl/c2', 'title': '第二章', 'index': 1},
    ];
  }

  @override
  Future<Map<String, dynamic>> bookContent(
    String bookUrl,
    int chapterIndex,
  ) async => {
    'bookUrl': bookUrl,
    'index': chapterIndex,
    'content': '正文$chapterIndex',
  };

  @override
  Future<Uint8List?> cover(String bookUrl) async =>
      Uint8List.fromList([0xff, 0xd8, 0xff]);

  @override
  Future<Uint8List?> image(String url) async =>
      Uint8List.fromList([1, 2, 3]);
}

void main() {
  late ChlorisServer server;
  late String base;
  late HttpClient client;

  Future<void> start({ServerBackend? backend}) async {
    server = ChlorisServer(
      bookSources: [
        BookSource(bookSourceUrl: 'https://src.test', bookSourceName: '源'),
      ],
      replaceRules: [ReplaceRule(id: 1, name: 'r', pattern: 'a')],
      rssSources: [
        {'sourceUrl': 'https://feed.test', 'sourceName': '订阅'},
      ],
      backend: backend,
      token: 'test-token',
    );
    await server.start(httpPort: 0, wsPort: 0);
    base = 'http://127.0.0.1:${server.port}';
    client = HttpClient();
  }

  tearDown(() async {
    client.close(force: true);
    await server.stop();
  });

  Future<(int, String)> get(String path, {bool auth = true}) async {
    final req = await client.getUrl(Uri.parse('$base$path'));
    if (auth) req.headers.set('authorization', 'Bearer test-token');
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    return (res.statusCode, body);
  }

  Future<(int, String)> post(
    String path,
    Object body, {
    bool auth = true,
  }) async {
    final req = await client.postUrl(Uri.parse('$base$path'));
    if (auth) req.headers.set('authorization', 'Bearer test-token');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(body));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    return (res.statusCode, text);
  }

  group('auth still guards every new route', () {
    setUp(() => start(backend: _FakeBackend()));

    test('an unauthenticated request is rejected', () async {
      for (final path in const [
        '/version',
        '/getBookshelf',
        '/getChapterList?url=x',
        '/getBookContent?url=x&index=0',
        '/getRssSources',
      ]) {
        final (code, _) = await get(path, auth: false);
        expect(code, 401, reason: path);
      }
    });
  });

  group('/version', () {
    setUp(() => start(backend: _FakeBackend()));

    test('reports the contract version and capabilities', () async {
      final (code, body) = await get('/version');
      expect(code, 200);
      final envelope = jsonDecode(body) as Map<String, dynamic>;
      expect(envelope['isSuccess'], isTrue);
      final info = envelope['data'] as Map<String, dynamic>;
      expect(info['apiVersion'], chlorisApiVersion);
      expect(
        (info['capabilities'] as Map)['bookshelf'],
        isTrue,
      );
    });

    test('capabilities report what is actually wired', () async {
      await server.stop();
      await start();

      final (_, body) = await get('/version');
      final info =
          (jsonDecode(body) as Map<String, dynamic>)['data'] as Map;
      final caps = info['capabilities'] as Map;
      expect(caps['bookshelf'], isFalse);
      // Proxy and book sources exist regardless of the backend.
      expect(caps['proxy'], isTrue);
    });
  });

  group('without a backend', () {
    setUp(() => start());

    test('state routes answer 501 rather than an empty success', () async {
      for (final path in const [
        '/getBookshelf',
        '/getChapterList?url=x',
        '/getBookContent?url=x&index=0',
        '/cover?url=x',
        '/image?url=https://a.test/i.png',
      ]) {
        final (code, body) = await get(path);
        expect(code, 501, reason: path);
        final envelope = jsonDecode(body) as Map<String, dynamic>;
        expect(envelope['isSuccess'], isFalse);
        expect(envelope['errorMsg'], contains('未装配'));
      }
    });

    test('source routes still work, since they need no backend', () async {
      final (code, body) = await get('/getBookSources');
      expect(code, 200);
      expect(jsonDecode(body), hasLength(1));
    });
  });

  group('with a backend', () {
    late _FakeBackend backend;

    setUp(() {
      backend = _FakeBackend();
      return start(backend: backend);
    });

    test('bookshelf round-trips through save and list', () async {
      final (saveCode, _) = await post('/saveBook', {
        'bookUrl': 'https://b.test/1',
        'name': '书名',
      });
      expect(saveCode, 200);

      final (code, body) = await get('/getBookshelf');
      expect(code, 200);
      final data = (jsonDecode(body) as Map)['data'] as List;
      expect(data, hasLength(1));
      expect(data.single['name'], '书名');
    });

    test('deleteBook reaches the backend', () async {
      await post('/saveBook', {'bookUrl': 'u1', 'name': 'n'});
      await post('/deleteBook', {'bookUrl': 'u1'});
      expect(backend.deleted, ['u1']);
      final (_, body) = await get('/getBookshelf');
      expect((jsonDecode(body) as Map)['data'], isEmpty);
    });

    test('progress is forwarded verbatim', () async {
      await post('/saveBookProgress', {
        'bookUrl': 'u1',
        'chapterIndex': 7,
        'chapterPos': 120,
      });
      expect(backend.progressed.single['chapterIndex'], 7);
    });

    test('getChapterList parses its query from the contract', () async {
      final (code, body) = await get('/getChapterList?url=https://b.test/1');
      expect(code, 200);
      final data = (jsonDecode(body) as Map)['data'] as List;
      expect(data, hasLength(2));
      expect(data.first['title'], '第一章');
      expect(backend.refreshRequested, isFalse);
    });

    test('refreshToc asks for a refresh', () async {
      await get('/refreshToc?url=https://b.test/1');
      expect(backend.refreshRequested, isTrue);
    });

    test('refresh flag travels through the query object', () async {
      await get('/getChapterList?url=u&refresh=true');
      expect(backend.refreshRequested, isTrue);
    });

    test('getBookContent parses book and index', () async {
      final (code, body) =
          await get('/getBookContent?url=https://b.test/1&index=3');
      expect(code, 200);
      final data = (jsonDecode(body) as Map)['data'] as Map;
      expect(data['index'], 3);
      expect(data['content'], '正文3');
    });

    test('cover returns bytes, not JSON', () async {
      final req = await client.getUrl(Uri.parse('$base/cover?url=u'));
      req.headers.set('authorization', 'Bearer test-token');
      final res = await req.close();
      expect(res.statusCode, 200);
      expect(res.headers.contentType?.mimeType, 'image/jpeg');
    });

    test('a backend failure becomes an error envelope, not a 200', () async {
      await server.stop();
      await start(backend: _ThrowingBackend());
      final (code, body) = await get('/getBookshelf');
      expect(code, 500);
      expect((jsonDecode(body) as Map)['isSuccess'], isFalse);
    });
  });

  group('RSS sources', () {
    setUp(() => start());

    test('list, save and delete', () async {
      final (_, list) = await get('/getRssSources');
      expect(jsonDecode(list), hasLength(1));

      await post('/saveRssSources', {
        'sourceUrl': 'https://new.test',
        'sourceName': '新订阅',
      });
      final (_, after) = await get('/getRssSources');
      expect(jsonDecode(after), hasLength(2));

      await post('/deleteRssSources', ['https://new.test']);
      final (_, final_) = await get('/getRssSources');
      expect(jsonDecode(final_), hasLength(1));
    });

    test('getRssSource looks one up by url', () async {
      final (_, body) = await get('/getRssSource?url=https://feed.test');
      expect((jsonDecode(body) as Map)['sourceName'], '订阅');
    });

    test('saving without a sourceUrl is ignored rather than stored empty',
        () async {
      await post('/saveRssSources', {'sourceName': 'no url'});
      final (_, list) = await get('/getRssSources');
      expect(jsonDecode(list), hasLength(1));
    });
  });

  group('replace rule writes', () {
    setUp(() => start());

    test('save and delete', () async {
      await post('/saveReplaceRule', {
        'id': 2,
        'name': 'rule2',
        'pattern': 'b',
        'replacement': '',
      });
      final (_, body) = await get('/getReplaceRules');
      expect(jsonDecode(body), hasLength(2));

      await post('/deleteReplaceRule', [2]);
      final (_, after) = await get('/getReplaceRules');
      expect(jsonDecode(after), hasLength(1));
    });
  });
}

class _ThrowingBackend implements ServerBackend {
  @override
  Future<List<Map<String, dynamic>>> bookshelf() async =>
      throw const DomainError(
        code: 'backend_down',
        stage: DomainErrorStage.persist,
        message: '后端不可用',
      );

  @override
  Future<void> saveBook(Map<String, dynamic> book) async {}
  @override
  Future<void> deleteBook(String bookUrl) async {}
  @override
  Future<void> saveProgress(Map<String, dynamic> progress) async {}
  @override
  Future<List<Map<String, dynamic>>> chapterList(
    String bookUrl, {
    bool refresh = false,
  }) async => const [];
  @override
  Future<Map<String, dynamic>> bookContent(String bookUrl, int i) async => {};
  @override
  Future<Uint8List?> cover(String bookUrl) async => null;
  @override
  Future<Uint8List?> image(String url) async => null;
}
