import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

/// 验证 Chloris 的正则后端已对齐 Legado-E `AnalyzeByRegex.kt:11`
/// `Pattern.compile(regs[index])`（无任何标志）的默认语义。
///
/// Java 默认：`.` 不匹配换行符、`^`/`$` 只匹配整串首尾（无 MULTILINE / 无 DOTALL）。
/// 旧实现 `multiLine: true, dotAll: true` 会让同一条正则在多行正文上给出不同长度的结果。
void main() {
  test('含 . 的正则在多行输入上不跨行（对齐 Legado-E 无 DOTALL）', () {
    // 对齐前（dotAll:true）：`.` 跨行，`line1(.*)line2` 会匹配并捕获 `\n`。
    // 对齐后：`.` 不匹配 `\n`，line1 与 line2 之间有换行，故不匹配。
    const input = 'line1\nline2\nline3';
    final matches = AnalyzeByRegex.getElements(input, [r'line1(.*)line2']);
    expect(matches, isEmpty);
  });

  test('锚点 ^ 与 \$ 只匹配整串首尾而非每行（对齐 Legado-E 无 MULTILINE）', () {
    // 对齐前（multiLine:true）：`^\w+$` 逐行匹配，得到 abc/def/ghi 三组。
    // 对齐后：整串含换行符，不是纯单词字符，故不匹配。
    const input = 'abc\ndef\nghi';
    final matches = AnalyzeByRegex.getElements(input, [r'^\w+$']);
    expect(matches, isEmpty);
  });

  test('需要跨行时 Legado 书源用 [\\s\\S] 而非 .', () {
    // 这是 Legado 书源在 Chloris 去掉标志后仍能正常工作的写法。
    const input = 'line1\nline2\nline3';
    final matches = AnalyzeByRegex.getElements(input, [r'line1([\s\S]*?)line3']);
    expect(matches, hasLength(1));
    expect(matches.first[1], '\nline2\n');
  });

  test('单行无跨行需求的正则行为不变', () {
    const input = 'Chapter 42';
    final matches = AnalyzeByRegex.getElements(input, [r'Chapter\s+(\d+)']);
    expect(matches, hasLength(1));
    expect(matches.first[1], '42');
  });
}
