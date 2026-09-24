// 自动排版（段首缩进 / 段间间隔）的回归测试。
//
// 背景：缩进逻辑原本藏在 `ContentProcessor.process` 里，而那个方法只在
// 「配了替换规则」时才会被 ChapterPipeline 调用 —— 于是没配规则的书整段顶格。
// 修好后 `resegment` 变成公开静态方法，由应用层在任何路径上调用；
// 应用层那条路径的段间必须是**空行**（`\n\n`），压成单个 `\n` 会让整章挤成一坨。
import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  group('ContentProcessor.resegment', () {
    test('段首补两个全角空格', () {
      expect(ContentProcessor.resegment('正文第一句。'), '　　正文第一句。');
    });

    test('已有全角缩进的不重复补', () {
      expect(ContentProcessor.resegment('　　已经缩进。'), '　　已经缩进。');
    });

    test('去掉空行，行首尾空白清掉', () {
      expect(
        ContentProcessor.resegment('第一段。\n\n  第二段。  \n'),
        '　　第一段。\n　　第二段。',
      );
    });

    test('图片与外链行不缩进', () {
      const img = '<img src="x.png"/>';
      const link = 'https://example.com/a.png';
      final out = ContentProcessor.resegment('$img\n$link\n说明文字');
      expect(out, '$img\n$link\n　　说明文字');
    });

    test('replace 路径默认单换行（对齐 Legado）', () {
      final out = ContentProcessor.resegment('一。\n二。');
      expect(out, '　　一。\n　　二。');
      expect(out.contains('\n\n'), isFalse);
    });

    test('阅读器路径用空行分段（paragraphGap）', () {
      // resegment 只负责分段与缩进；HTML → 纯文本是上游 htmlToPlain 的事。
      final out = ContentProcessor.resegment(
        '第一段。\n\n第二段。',
        paragraphGap: '\n\n',
      );
      expect(out, '　　第一段。\n\n　　第二段。');
    });

    test('空输入返回空', () {
      expect(ContentProcessor.resegment(''), '');
      expect(ContentProcessor.resegment('\n\n  \n'), '');
    });
  });
}
