// oracle 双侧判题暴露的真实分歧收口回归测试（见 tool/legado_oracle/fixtures/NOTES.md §3.2）。
// 每条用例对齐 legado 行为并附出处：
//  - css-008/009：`:contains` 谓词绑定所在段（AnalyzeByJSoup.kt:144 select(ruleStr)）
//  - css-027/029：`:has(>a)` / `:not(:has(p))`（jsoup StructuralEvaluator）
//  - css-007：多命中 `\n` 连接（AnalyzeByJSoup.kt:59 joinToString）+ 块级元素间空格
//  - json-030：`$..*` 递归通配（AnalyzeByJsonPath.kt:18 Jayway）
import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  group('CSS 谓词作用域（绑定所在段）', () {
    test('css-008: dd:contains(最新章节：) > a@text', () {
      final css = AnalyzeByCss('<dl><dd>最新章节：<a>第1章 开端</a></dd></dl>');
      expect(css.getString('dd:contains(最新章节：) > a@text'), '第1章 开端');
    });

    test('css-009: dt:contains(作者)+dd a@text', () {
      final css = AnalyzeByCss('<dl><dt>作者</dt><dd><a>猫腻</a></dd></dl>');
      expect(css.getString('dt:contains(作者)+dd a@text'), '猫腻');
    });

    test('末段谓词行为不变：a:contains(x)@text 仍作用于 a', () {
      final css = AnalyzeByCss(
        '<div><a>前三名</a><a>其它</a></div>',
      );
      expect(css.getString('a:contains(前)@text'), '前三名');
    });
  });

  group(':has / :not(:has(...))', () {
    test('css-027: ul:has(>a) —— a 非直接子代，legado 判空', () {
      final css = AnalyzeByCss(
        '<ul><li><a>有链接</a></li></ul><ul><li>无链接</li></ul>',
      );
      // legado（oracle 实测）：`ul:has(>a)` 要求 a 是 ul 的直接子代，此处返回空。
      expect(css.getString('ul:has(>a)@text'), '');
    });

    test('css-027b: ul:has(a) 后代语义', () {
      final css = AnalyzeByCss(
        '<ul><li><a>有链接</a></li></ul><ul><li>无链接</li></ul>',
      );
      expect(css.getString('ul:has(a)@text'), '有链接');
    });

    test('css-029: div:not(:has(p))@text', () {
      final css = AnalyzeByCss('<div>无p</div><div><p>有p</p></div>');
      expect(css.getString('div:not(:has(p))@text'), '无p');
    });
  });

  group('多命中连接与文本空白（对齐 AnalyzeByJSoup.kt:59/:233）', () {
    test('css-007: :contains(作者)@text 以 \\n 连接全部命中', () {
      final css = AnalyzeByCss(
        '<div><p>作者：爱潜水的乌贼</p><p>简介：一段文字</p></div>',
      );
      final got = css.getString(':contains(作者)@text');
      // 命中 div、第二个 p（"作者" 出现在 div 全文与 p 无关——此处 div 全文含"作者"）。
      // 关键断言：多命中以 \n 分隔，而不是包含式折叠成单串。
      expect(got.contains('\n'), isTrue, reason: 'got=$got');
      expect(got.split('\n').every((l) => l.contains('作者')), isTrue);
    });

    test('块级子元素之间补空格（jsoup Element.text 语义）', () {
      final css = AnalyzeByCss(
        '<div><p>作者：爱潜水的乌贼</p><p>简介：一段文字</p></div>',
      );
      final got = css.getString('div@text');
      expect(got, '作者：爱潜水的乌贼 简介：一段文字');
    });
  });

  group('JSONPath 递归通配', () {
    test('json-030: 递归通配 收集全部值（容器+叶子）', () {
      final jp = AnalyzeByJsonPath('{"a":1,"b":{"c":2}}');
      // Jayway toString：Map 走 Java AbstractMap 的 {k=v}（判题进程实测
      // `1\n{c=2}\n2`），不是 jsonEncode 的 {"c":2}。
      expect(jp.getString(r'$..*'), '1\n{c=2}\n2');
    });

    test(r'$..title 具名递归行为不变', () {
      final jp = AnalyzeByJsonPath(
        '{"data":{"list":[{"title":"甲"},{"title":"乙"}]}}',
      );
      expect(jp.getString(r'$..title'), '甲\n乙');
    });
  });
}
