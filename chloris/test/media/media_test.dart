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
}
