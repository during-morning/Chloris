import 'dart:convert';

import 'package:chloris/application/online/http_online_book_port.dart';
import 'package:chloris/services/web/api_client.dart';
import 'package:chloris/services/web/api_contract.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what was sent and replays a canned envelope.
class _FakeTransport {
  _FakeTransport(this.responder);

  final Future<({int status, String body})> Function(
    String method,
    String path,
    Map<String, String>? query,
    Object? body,
  )
  responder;

  final calls = <({String method, String path, Map<String, String>? query})>[];

  ApiTransport get transport => (method, path, {query, body}) async {
    calls.add((method: method, path: path, query: query));
    return responder(method, path, query, body);
  };
}

String envelope(Object? data, {bool success = true, String? errorMsg}) {
  final payload = <String, Object?>{'isSuccess': success, 'errorMsg': errorMsg};
  if (data != null) payload['data'] = data;
  return jsonEncode(payload);
}

final _source = BookSource(
  bookSourceUrl: 'https://src.test',
  bookSourceName: '源',
);
final _book = Book(bookUrl: 'https://b.test/1', name: '书');
BookChapter _chapter(int i) =>
    BookChapter(url: 'https://b.test/1/c$i', title: '第$i章', index: i);

void main() {
  group('ChlorisApiClient', () {
    test('unwraps the envelope', () async {
      final t = _FakeTransport(
        (m, p, q, b) async => (
          status: 200,
          body: envelope([
            {'url': 'u', 'title': 't', 'index': 0},
          ]),
        ),
      );
      final client = ChlorisApiClient(transport: t.transport);
      final list = await client.bookshelf();
      expect(list, hasLength(1));
    });

    test(
      'a failure envelope becomes a DomainError with its metadata',
      () async {
        final t = _FakeTransport(
          (m, p, q, b) async => (
            status: 500,
            body: jsonEncode({
              'isSuccess': false,
              'errorMsg': '目录抓取失败',
              'stage': 'toc',
              'retryable': true,
              'suggestedAction': '重试',
            }),
          ),
        );
        final client = ChlorisApiClient(transport: t.transport);
        try {
          await client.chapterList('u');
          fail('should have thrown');
        } on DomainError catch (e) {
          expect(e.message, '目录抓取失败');
          expect(e.stage, DomainErrorStage.toc);
          expect(e.retryable, isTrue);
          expect(e.suggestedAction, '重试');
        }
      },
    );

    test('non-JSON output is reported as a protocol mismatch', () async {
      final t = _FakeTransport(
        (m, p, q, b) async => (status: 200, body: '<html>'),
      );
      final client = ChlorisApiClient(transport: t.transport);
      await expectLater(
        client.bookshelf(),
        throwsA(
          isA<DomainError>().having(
            (e) => e.code,
            'code',
            'api_malformed_response',
          ),
        ),
      );
    });

    test('a JSON body that is not an envelope is rejected', () async {
      final t = _FakeTransport(
        (m, p, q, b) async => (status: 200, body: '[1,2]'),
      );
      final client = ChlorisApiClient(transport: t.transport);
      await expectLater(
        client.bookshelf(),
        throwsA(
          isA<DomainError>().having(
            (e) => e.code,
            'code',
            'api_malformed_envelope',
          ),
        ),
      );
    });

    test('an unknown stage string degrades to unknown, not a crash', () async {
      final t = _FakeTransport(
        (m, p, q, b) async => (
          status: 500,
          body: jsonEncode({
            'isSuccess': false,
            'errorMsg': 'x',
            'stage': 'nope',
          }),
        ),
      );
      final client = ChlorisApiClient(transport: t.transport);
      try {
        await client.chapterList('u');
        fail('should have thrown');
      } on DomainError catch (e) {
        expect(e.stage, DomainErrorStage.unknown);
      }
    });

    test('chapterList parses chapters and sends the query', () async {
      final t = _FakeTransport(
        (m, p, q, b) async => (
          status: 200,
          body: envelope([
            {'url': 'c1', 'title': '第一章', 'index': 0, 'isVolume': true},
            {'url': 'c2', 'title': '第二章', 'index': 1},
          ]),
        ),
      );
      final client = ChlorisApiClient(transport: t.transport);
      final chapters = await client.chapterList('https://b.test/1');

      expect(t.calls.single.path, '/getChapterList');
      expect(t.calls.single.method, 'GET');
      expect(t.calls.single.query?['url'], 'https://b.test/1');
      expect(chapters, hasLength(2));
      expect(chapters.first.title, '第一章');
      expect(chapters.first.isVolume, isTrue);
      expect(chapters.first.bookUrl, 'https://b.test/1');
    });

    test('refresh goes to the refresh route', () async {
      final t = _FakeTransport(
        (m, p, q, b) async => (status: 200, body: envelope([])),
      );
      final client = ChlorisApiClient(transport: t.transport);
      await client.chapterList('u', refresh: true);
      expect(t.calls.single.path, '/refreshToc');
    });

    test('bookContent returns title and body', () async {
      final t = _FakeTransport(
        (m, p, q, b) async =>
            (status: 200, body: envelope({'title': '第一章', 'content': '正文'})),
      );
      final client = ChlorisApiClient(transport: t.transport);
      final r = await client.bookContent('https://b.test/1', 3);
      expect(r.title, '第一章');
      expect(r.content, '正文');
      expect(r.resourceUrl, isNull);
      expect(r.variable, isNull);
      expect(r.mediaHeaders, isEmpty);
      expect(t.calls.single.query?['index'], '3');
    });

    test('bookContent 保留媒体资源和歌词变量', () async {
      final t = _FakeTransport(
        (m, p, q, b) async => (
          status: 200,
          body: envelope({
            'title': '歌曲',
            'content': 'https://cdn.test/track.mp3',
            'resourceUrl': 'https://cdn.test/track.mp3',
            'variable': '{"lyric":"[00:01]歌词"}',
          }),
        ),
      );
      final result = await ChlorisApiClient(
        transport: t.transport,
      ).bookContent('https://b.test/music', 0);
      expect(result.resourceUrl, 'https://cdn.test/track.mp3');
      expect(result.variable, '{"lyric":"[00:01]歌词"}');
    });

    test('version parses ServerInfo and is usable without a token', () async {
      final t = _FakeTransport(
        (m, p, q, b) async => (
          status: 200,
          body: envelope({
            'apiVersion': chlorisApiVersion,
            'appVersion': '1.2.3',
            'capabilities': {'bookshelf': true},
          }),
        ),
      );
      final client = ChlorisApiClient(transport: t.transport);
      final info = await client.version();
      expect(info.apiVersion, chlorisApiVersion);
      expect(info.appVersion, '1.2.3');
      expect(info.isCompatible, isTrue);
      expect(info.capabilities['bookshelf'], isTrue);
    });

    test('a version mismatch is visible to the caller', () async {
      final t = _FakeTransport(
        (m, p, q, b) async => (
          status: 200,
          body: envelope({'apiVersion': 999, 'appVersion': 'x'}),
        ),
      );
      final info = await ChlorisApiClient(transport: t.transport).version();
      expect(info.isCompatible, isFalse);
    });

    test('saveProgress posts the contract body', () async {
      Object? sent;
      final t = _FakeTransport((m, p, q, b) async {
        sent = b;
        return (status: 200, body: envelope({'ok': true}));
      });
      await ChlorisApiClient(transport: t.transport).saveProgress(
        const BookProgressBody(bookUrl: 'u', chapterIndex: 4, chapterPos: 9),
      );
      expect((sent! as Map)['chapterIndex'], 4);
      expect(t.calls.single.path, '/saveBookProgress');
    });
  });

  group('HttpOnlineBookPort', () {
    test(
      'loadChapterList returns server chapters and reports them once',
      () async {
        final t = _FakeTransport(
          (m, p, q, b) async => (
            status: 200,
            body: envelope([
              {'url': 'c1', 'title': '一', 'index': 0},
              {'url': 'c2', 'title': '二', 'index': 1},
            ]),
          ),
        );
        final port = HttpOnlineBookPort(
          ChlorisApiClient(transport: t.transport),
        );
        var partialCalls = 0;
        final chapters = await port.loadChapterList(
          _source,
          _book,
          onPartial: (_) => partialCalls++,
        );
        expect(chapters, hasLength(2));
        expect(partialCalls, 1);
      },
    );

    test('an empty catalogue is an error, not an empty list', () async {
      final t = _FakeTransport(
        (m, p, q, b) async => (status: 200, body: envelope([])),
      );
      final port = HttpOnlineBookPort(ChlorisApiClient(transport: t.transport));
      await expectLater(
        port.loadChapterList(_source, _book),
        throwsA(isA<DomainError>().having((e) => e.code, 'code', 'toc_empty')),
      );
    });

    test('blank content is an error, not an empty chapter', () async {
      final t = _FakeTransport(
        (m, p, q, b) async =>
            (status: 200, body: envelope({'title': 't', 'content': '   '})),
      );
      final port = HttpOnlineBookPort(ChlorisApiClient(transport: t.transport));
      await expectLater(
        port.loadChapterContent(_source, _book, _chapter(0)),
        throwsA(
          isA<DomainError>().having((e) => e.code, 'code', 'content_empty'),
        ),
      );
    });

    test('content is returned when present', () async {
      final t = _FakeTransport(
        (m, p, q, b) async =>
            (status: 200, body: envelope({'title': 't', 'content': '正文'})),
      );
      final port = HttpOnlineBookPort(ChlorisApiClient(transport: t.transport));
      expect(await port.loadChapterContent(_source, _book, _chapter(2)), '正文');
    });

    test('HTTP章节加载回写歌词与资源地址供播放器读取', () async {
      final transport = _FakeTransport(
        (m, p, q, b) async => (
          status: 200,
          body: envelope({
            'title': '歌名',
            'content': 'https://cdn.test/music.mp3',
            'resourceUrl': 'https://cdn.test/music.mp3',
            'variable': '{"lyric":"[00:01]歌词"}',
          }),
        ),
      );
      final chapter = _chapter(2);
      await HttpOnlineBookPort(
        ChlorisApiClient(transport: transport.transport),
      ).loadChapterContent(_source, _book, chapter);
      expect(chapter.resourceUrl, 'https://cdn.test/music.mp3');
      expect(chapter.getVariable('lyric'), '[00:01]歌词');
    });

    test('routes the contract does not cover fail loudly', () async {
      final t = _FakeTransport(
        (m, p, q, b) async => (status: 200, body: envelope({})),
      );
      final port = HttpOnlineBookPort(ChlorisApiClient(transport: t.transport));
      for (final call in <Future<Object?> Function()>[
        () => port.search(_source, 'key'),
        () => port.explore(_source, 'url'),
        () => port.loadBookInfo(_source, _book),
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<DomainError>().having(
              (e) => e.code,
              'code',
              'capability_missing',
            ),
          ),
        );
      }
    });
  });

  group('client-side stores are memory only', () {
    test('catalog store caches and honours skipNext', () async {
      final store = HttpChapterCatalogStore();
      await store.put('u', [_chapter(0)]);
      expect(store.peek('u'), hasLength(1));
      expect(store.take('u'), hasLength(1));

      store.skipNext('u');
      expect(store.take('u'), isNull);
      // skipNext is one-shot.
      expect(store.take('u'), hasLength(1));

      await store.remove('u');
      expect(store.peek('u'), isNull);
    });

    test('content store keys by source and chapter', () async {
      final store = HttpChapterContentStore();
      await store.put('s1', 'c1', 'a');
      await store.put('s2', 'c1', 'b');
      expect(store.get('s1', 'c1'), 'a');
      expect(store.get('s2', 'c1'), 'b');
      await store.remove('s1', 'c1');
      expect(store.get('s1', 'c1'), isNull);
      expect(store.get('s2', 'c1'), 'b');
    });
  });
}
