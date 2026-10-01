import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/features/media/media_player_screen.dart';

void main() {
  test('playableUrlFromContent 从 video 标签提取可播 URL', () {
    const content = '<video src="https://example.com/a.mp4"></video>正文';
    expect(playableUrlFromContent(content), 'https://example.com/a.mp4');
  });

  test('playableUrlFromContent 从 source 标签提取', () {
    const content = '<source src="https://example.com/a.m3u8" type="application/x-mpegURL"/>';
    expect(playableUrlFromContent(content), 'https://example.com/a.m3u8');
  });

  test('优先解析音频节点并解码 HTML query 参数', () {
    const content =
        '<a href="https://example.com/ad">广告</a>'
        '<audio><source src="/audio/track.mp3?token=a&amp;part=2"></audio>';
    expect(
      playableUrlFromContent(content, baseUrl: 'https://reader.example/ch/1'),
      'https://reader.example/audio/track.mp3?token=a&part=2',
    );
  });

  test('解析脚本里的 JSON 转义音频地址和纯相对地址', () {
    expect(
      playableUrlFromContent(r'{"audioUrl":"https:\/\/cdn.example/a.mp3"}'),
      'https://cdn.example/a.mp3',
    );
    expect(
      playableUrlFromContent(
        'audio/episode.m4a',
        baseUrl: 'https://reader.example/book/chapter',
      ),
      'https://reader.example/book/audio/episode.m4a',
    );
  });

  test('不把没有基础地址的相对文字误认成播放地址', () {
    expect(playableUrlFromContent('audio/episode.mp3'), isNull);
  });

  test('目录资源地址可作为媒体提取的可靠回退', () {
    expect(
      playableUrlFromContent(
        '章节音频',
        baseUrl: 'https://reader.example/book/chapter',
        resourceUrl: '../media/track.mp3',
      ),
      'https://reader.example/media/track.mp3',
    );
  });
}
