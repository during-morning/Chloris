import 'dart:typed_data';

import 'package:chloris/engine/engine_facade.dart';
import 'package:chloris/features/media/media_resource.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON 嵌套音频优先于网站链接，保留元数据和请求头', () {
    final media = parseMediaResource(
      r'{"url":"https://example.com/ad","name":"歌曲","headers":{"referer":"https://example.com/"},'
      r'"data":{"audioUrl":"https:\/\/cdn.example/music.mp3?a=1\u0026b=2","lrc":{"lyric":"[00:01]歌词"}}}',
      headers: const {
        'Referer': 'https://old.example',
        'Authorization': 'token',
      },
    )!;
    expect(media.url, 'https://cdn.example/music.mp3?a=1&b=2');
    expect(media.title, '歌曲');
    expect(media.lyric, '[00:01]歌词');
    expect(media.headers, {
      'referer': 'https://example.com/',
      'Authorization': 'token',
    });
  });

  test('HTML 媒体地址优先广告，Legado URL选项不混入真实URL', () {
    expect(
      parseMediaResource(
        '<a href="https://ad.example/">广告</a><audio data-src="../track.m4a"></audio>',
        baseUrl: 'https://example.com/book/chapter',
      )!.url,
      'https://example.com/track.m4a',
    );
    final media = parseMediaResource(
      'https://cdn.example/play,{"headers":{"Cookie":"auth=1"}}',
    )!;
    expect(media.url, 'https://cdn.example/play');
    expect(media.headers['Cookie'], 'auth=1');
    expect(
      parseMediaResource('没有音频 <a href="https://ad.example/">链接</a>'),
      isNull,
    );
  });

  test('解析网页通过HTTP端口加载JSON和歌词，不下载媒体文件', () async {
    final http = _FakeHttp(
      (spec) => switch (spec.url) {
        'https://example.com/song' when spec.method == 'HEAD' =>
          const StrResponse(
            url: 'https://example.com/song',
            body: '',
            headers: {'content-type': 'application/json'},
          ),
        'https://example.com/song' => const StrResponse(
          url: 'https://example.com/song',
          body: '{"url":"/track.mp3","lyricUrl":"/song.lrc"}',
        ),
        'https://example.com/song.lrc' => const StrResponse(
          url: 'https://example.com/song.lrc',
          body: '[00:01]歌词',
        ),
        _ => throw StateError('不应下载音频：${spec.url}'),
      },
    );
    final media = await MediaResourceResolver(
      http: http,
    ).resolve('https://example.com/song');
    expect(media.url, 'https://example.com/track.mp3');
    expect(media.lyric, '[00:01]歌词');
    expect(http.requests.map((e) => e.method), ['HEAD', 'GET', 'GET']);
  });

  test('歌词加载失败仍返回可播放音频', () async {
    final http = _FakeHttp((_) => throw StateError('歌词服务不可用'));
    final media = await MediaResourceResolver(http: http).resolve(
      '{"url":"https://cdn.example/a.mp3","lyricUrl":"https://cdn.example/a.lrc"}',
    );
    expect(media.url, 'https://cdn.example/a.mp3');
    expect(media.lyric, isNull);
  });

  test('源级headers、URL级headers和Cookie传到流式播放请求', () async {
    final http = _FakeHttp((_) => throw StateError('解析请求头不应下载文件'));
    final cookies = CookieStore()..set('https://source.example', 'login=1');
    final facade = EngineFacade(http: http, cookieStore: cookies);
    final result = await facade.prepareMediaRequest(
      'https://cdn.example/a.mp3,{"headers":{"Referer":"https://source.example/player","Cookie":"token=2"}}',
      source: BookSource(
        bookSourceUrl: 'https://source.example',
        header: '{"User-Agent":"CustomPlayer"}',
      ),
      book: Book(bookUrl: 'https://source.example/book'),
      chapter: BookChapter(url: 'https://source.example/chapter'),
      headers: const {'Cookie': 'token=2'},
    );
    expect(result.url, 'https://cdn.example/a.mp3');
    expect(result.headers['Referer'], 'https://source.example/player');
    expect(result.headers['User-Agent'], 'CustomPlayer');
    expect(result.headers['Cookie'], contains('login=1'));
    expect(result.headers['Cookie'], contains('token=2'));
    expect(http.requests, isEmpty);
  });
}

class _FakeHttp implements HttpPort {
  _FakeHttp(this.respond);
  final StrResponse Function(HttpRequestSpec) respond;
  final List<HttpRequestSpec> requests = [];
  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    requests.add(spec);
    return respond(spec);
  }

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) =>
      throw UnimplementedError();
  @override
  void cancelInFlight() {}
}
