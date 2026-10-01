import 'package:chloris/features/media/lyrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LRC 支持多时间标签、精度、乱序、偏移和翻译合并', () {
    final lyrics = LyricDocument.parse(
      '[ti:测试歌曲]\n[offset:-100]\n'
      '[00:12.50][00:32.500]原文\n'
      '[00:12.500]译文\n'
      '[00:01.5]第一行\n'
      '[00:10.05]第二行',
    );
    expect(lyrics.lines.map((e) => e.time?.inMilliseconds), [
      1400,
      9950,
      12400,
      32400,
    ]);
    expect(lyrics.lines[2].text, '原文\n译文');
    expect(lyrics.indexAt(Duration.zero), -1);
    expect(lyrics.indexAt(const Duration(milliseconds: 12400)), 2);
    expect(lyrics.indexAt(const Duration(seconds: 60)), 3);
    // Seeking back must move the active cue back too.
    expect(lyrics.indexAt(const Duration(seconds: 2)), 0);
  });

  test('普通歌词保留文字，空歌词和纯元数据不产生错误高亮', () {
    final plain = LyricDocument.parse('[ar:歌手]\n歌词一\r\n歌词二');
    expect(plain.lines.map((e) => e.text), ['歌词一', '歌词二']);
    expect(plain.timed, false);
    expect(plain.indexAt(const Duration(seconds: 30)), -1);
    expect(LyricDocument.parse('[ti:歌名]\n').lines, isEmpty);
  });

  test('空时间cue清除上一行，非法秒数不成为cue', () {
    final lyrics = LyricDocument.parse('[00:01]开始\n[00:02]\n[00:75]错误');
    expect(lyrics.lines.length, 2);
    expect(lyrics.lines[lyrics.indexAt(const Duration(seconds: 3))].text, '');
  });
}
