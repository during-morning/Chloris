import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

BookChapter _ch(String title, String url) =>
    BookChapter(title: title, url: url);

void main() {
  test('short TOCs still drop unambiguous chrome titles', () {
    final cleaned = ChapterListHygiene.sanitize([
      _ch('首页', 'https://ex.com/'),
      _ch('目录', 'https://ex.com/toc'),
      _ch('第一章', 'https://ex.com/c/1'),
      _ch('第二章', 'https://ex.com/c/2'),
    ]);
    expect(cleaned.map((e) => e.title), ['第一章', '第二章']);
    expect(
      ChapterListHygiene.isUnusable(cleaned, 'https://ex.com/toc'),
      isFalse,
    );
  });

  test('chrome-only leftover is unusable so callers retry fallback', () {
    final cleaned = ChapterListHygiene.sanitize([
      _ch('首页', 'https://ex.com/'),
      _ch('第一章', 'https://ex.com/c/1'),
    ]);
    expect(cleaned.map((e) => e.title), ['第一章']);
    expect(
      ChapterListHygiene.isUnusable(cleaned, 'https://ex.com/toc'),
      isTrue,
    );
  });

  test('two real short chapters stay usable', () {
    final chapters = [
      _ch('第一章', 'https://ex.com/c/1'),
      _ch('第二章', 'https://ex.com/c/2'),
    ];
    expect(ChapterListHygiene.sanitize(chapters).length, 2);
    expect(
      ChapterListHygiene.isUnusable(chapters, 'https://ex.com/toc'),
      isFalse,
    );
  });

  test('pager leftovers are chrome chapter names', () {
    expect(isChromeChapterName('上一章'), isTrue);
    expect(isChromeChapterName('下一章'), isTrue);
    expect(isChromeChapterName('返回目录'), isTrue);
    expect(isChromeChapterName('第一章 仙从何处来'), isFalse);
  });

  test('merge keeps first url and drops later duplicates', () {
    final merged = ChapterListHygiene.merge(
      [_ch('一', '/1'), _ch('二', '/2')],
      [_ch('二-重复', '/2'), _ch('三', '/3')],
    );
    expect(merged.map((e) => e.title), ['一', '二', '三']);
  });
}
