import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris/core/read/chapter_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTML 转纯文本并去掉章名重复标题', () {
    final out = ChapterPipeline.run(
      content: '<p>第一章</p><p>正文开始</p>',
      bookTitle: '仙逆',
      bookAuthor: '耳根',
      chapterTitle: '第一章',
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );
    expect(out.contains('正文开始'), isTrue);
    expect(out.startsWith('第一章'), isFalse);
  });

  test('无 HTML 时也会自动排版：段首缩进两个全角空格', () {
    final out = ChapterPipeline.run(
      content: '只是一段话',
      bookTitle: '书',
      bookAuthor: '作者',
      chapterTitle: '序',
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );
    // 以前缩进只在「配了替换规则」时才生效，没配规则的书整段顶格。
    expect(out, '　　只是一段话');
  });

  test('多段内容：段间保留空行，且每段都缩进', () {
    final out = ChapterPipeline.run(
      content: '<p>第一段。</p><p>第二段。</p>',
      bookTitle: '书',
      bookAuthor: '作者',
      chapterTitle: '序',
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );
    // 段间必须保留空行（\n\n）：压成单个 \n 会让整章挤成一坨。
    expect(out, '　　第一段。\n\n　　第二段。');
  });

  test('runOffMain 短章与 run 一致', () async {
    final args = (
      content: '<p>序</p><p>正文</p>',
      bookTitle: '书',
      bookAuthor: '作者',
      chapterTitle: '序',
    );
    final sync = ChapterPipeline.run(
      content: args.content,
      bookTitle: args.bookTitle,
      bookAuthor: args.bookAuthor,
      chapterTitle: args.chapterTitle,
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );
    final off = await ChapterPipeline.runOffMain(
      content: args.content,
      bookTitle: args.bookTitle,
      bookAuthor: args.bookAuthor,
      chapterTitle: args.chapterTitle,
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );
    expect(off, sync);
  });
}
