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

  test('HTML 中无标点的短换行并回合并为正文句子', () {
    final out = ChapterPipeline.run(
      content: '<div>石阶尽头，李凡站在<br>地<br>上的高台，俯视群山。</div>',
      bookTitle: '书',
      bookAuthor: '作者',
      chapterTitle: '序',
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );
    expect(out, contains('李凡站在地上的高台'));
  });

  test('HTML 将句尾拆成多个短段时也会合并，避免一字一行', () {
    final out = ChapterPipeline.run(
      content: '<p>奈何困顿</p><p>于</p><p>筑</p><p>基</p>',
      bookTitle: '书',
      bookAuthor: '作者',
      chapterTitle: '序',
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );
    expect(out, contains('奈何困顿于筑基'));
  });

  test('截图中的筑基短段连续分段仍合并为完整段落', () {
    final out = ChapterPipeline.run(
      content:
          '<p>“是了！”道玄子长叹一声，“金丹大道，有我无他。这世间结丹法门虽多，奈何困顿</p>'
          '<p>于</p><p>筑</p><p>基</p><p>期的修士更多！”</p>',
      bookTitle: '书',
      bookAuthor: '作者',
      chapterTitle: '序',
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );

    expect(out, contains('奈何困顿于筑基期的修士更多！'));
    expect(out, isNot(contains('奈何困顿\n\n　　于')));
  });

  test('真实章节短段在多轮排版后仍合并成正常句子', () {
    final out = ChapterPipeline.run(
      content:
          '<p>“笑话，就是因为欠缺结丹法门，我才被困筑基期近百载，眼看大限将至，就要化为枯骨。却得此结丹功法，怎么可能交予他人！”寇洪冷哼一声，语气</p>'
          '<p>中</p><p>满是</p><p>不屑。</p>'
          '<p>“是了！”道玄子长叹一声，“金丹大道，有我无他。这世间结丹法门虽多</p>'
          '<p>，</p><p>奈</p><p>何</p><p>困顿</p>',
      bookTitle: '书',
      bookAuthor: '作者',
      chapterTitle: '序',
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );
    final compact = out.replaceAll(RegExp(r'\s'), '');
    expect(compact, contains('语气中满是不屑。'));
    expect(compact, contains('法门虽多，奈何困顿'));
    // The reader treats a remaining newline as a hard visual break. Check the
    // actual rendered text boundaries too; a whitespace-stripping assertion
    // alone would let the original one-word-per-line regression pass.
    expect(out, contains('语气中满是不屑。'));
    expect(out, contains('法门虽多，奈何困顿'));
  });

  test('跨 HTML 段落的截断长句会续接，修复截图中的碎片行', () {
    final out = ChapterPipeline.run(
      content:
          '<p>“那是我的工作吗？我至于为了你的几张单子亲自坐在这里等你到这个时候吗？”经理没好气地说，随</p>'
          '<p>后</p><p>经理</p>'
          '<p>从办公室的柜子里拿出一个信封丢在方志强面前，说道：“这是你上个月的工资以及这个月的佣金，都</p>'
          '<p>在</p><p>里面，</p><p>你点一下。”</p>',
      bookTitle: '书',
      bookAuthor: '作者',
      chapterTitle: '序',
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );

    expect(out, contains('随后经理从办公室'));
    expect(out, contains('这个月的佣金，都在里面，你点一下。'));
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

  test('纯文本采集的短换行碎片合并回同一段', () {
    final out = ChapterPipeline.run(
      content: '月色下的远山。\n蹚在\n地\n上的\n访仙使回忆着当时的情景。',
      bookTitle: '书',
      bookAuthor: '作者',
      chapterTitle: '序',
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );
    expect(out, contains('蹚在地上的访仙使'));
  });

  test('Unicode 行分隔符也会合并回正常句子', () {
    final out = ChapterPipeline.run(
      content: '语气\u2028中\u2028满是\u2028不屑。',
      bookTitle: '书',
      bookAuthor: '作者',
      chapterTitle: '序',
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );
    expect(out, contains('语气中满是不屑。'));
  });

  test('竖向控制分隔符也会合并回正文句子', () {
    final out = ChapterPipeline.run(
      content: '奈何困顿\u000b于\u000c筑\u001c基\u001d期的修士更多！',
      bookTitle: '书',
      bookAuthor: '作者',
      chapterTitle: '序',
      enableReplace: false,
      replaceRules: const [],
      chineseConvert: false,
    );
    expect(out, contains('奈何困顿于筑基期的修士更多！'));
    expect(out, isNot(matches(RegExp(r'[\u000b\u000c\u001c-\u001e]'))));
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
