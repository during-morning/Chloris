// XPath 谓词函数子集与嵌套表达式解析测试。
//
// 覆盖 §任务「补齐 XPath 子集的谓词函数与嵌套表达式解析」要求的所有场景：
//   contains(text()/@attr) / starts-with / ends-with / translate / not
//   以及函数套函数的嵌套参数求值、与位置/比较谓词的组合。
//
// 对齐说明（对照 reference/legado-E-main/.../AnalyzeByXPath.kt）：
//   legado 的 AnalyzeByXPath 完全委托给 jsoup-xpath（org.seimicrawler.xpath），
//   所有函数语义以 jsoup-xpath 为准。其中：
//   - contains / starts-with / ends-with / translate / not 均为 jsoup-xpath
//     支持的标准 XPath 函数（ends-with 属 XPath 2.0，jsoup-xpath 提供 own 实现）。
//   - 全部大小写敏感，与标准 XPath 一致。
//   - Chloris 的 _evalFunction 对这些函数做通用（参数可递归求值）实现，
//     而原有的字面量 @attr/text()+"字面串" 形态仍由硬编码正则快路径处理，
//     二者行为一致（区分大小写、@attr 缺失回退 ''、text() 取元素文本）。
import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

// ---- 场景 A：contains / starts-with / ends-with ----
const _htmlA = '''
<html><body>
  <a href="https://a.html">关键词首页</a>
  <a href="http://b.html">其它</a>
  <div class="item-card">卡片</div>
  <div class="card">普通</div>
</body></html>''';

// ---- 场景 B：not(@class) / not(contains(...)) ----
const _htmlB = '''
<html><body>
  <span class="x">有类</span>
  <span>无类</span>
  <a href="https://a">保留</a>
  <a>无href</a>
</body></html>''';

// ---- 场景 C：translate ----
const _htmlC = '''
<html><body>
  <div date="2024-01-01">一条</div>
  <div date="2024/02-02">二条</div>
</body></html>''';

// ---- 场景 D：嵌套函数（函数套函数作为参数）----
const _htmlD = '''
<html><body>
  <a>这是关键词内容</a>
  <a>无关</a>
  <li class="a-item">甲</li>
  <li class="b-item">乙</li>
</body></html>''';

// ---- 场景 E：位置谓词与函数谓词组合 ----
const _htmlE = '''
<html><body>
  <li class="a">1</li>
  <li class="b">2</li>
  <li class="a">3</li>
</body></html>''';

void main() {
  group('contains / starts-with / ends-with', () {
    test('//a[contains(text(),"关键词")] 命中', () {
      final xp = AnalyzeByXPath(_htmlA);
      expect(xp.getStringList('//a[contains(text(),"关键词")]'), ['关键词首页']);
    });

    test('//div[contains(@class,"item")] 命中', () {
      final xp = AnalyzeByXPath(_htmlA);
      expect(xp.getStringList('//div[contains(@class,"item")]'), ['卡片']);
    });

    test('//a[starts-with(@href,"https")] 命中', () {
      final xp = AnalyzeByXPath(_htmlA);
      expect(xp.getStringList('//a[starts-with(@href,"https")]'), ['关键词首页']);
    });

    // ends-with 是 XPath 2.0 / jsoup-xpath 提供的 own 实现；Chloris 此前完全缺失。
    test('//a[ends-with(@href,".html")] 命中两条', () {
      final xp = AnalyzeByXPath(_htmlA);
      expect(
        xp.getStringList('//a[ends-with(@href,".html")]'),
        ['关键词首页', '其它'],
      );
    });
  });

  group('not()', () {
    test('//span[not(@class)] 命中无 class 的 span', () {
      final xp = AnalyzeByXPath(_htmlB);
      expect(xp.getStringList('//span[not(@class)]'), ['无类']);
    });

    test('//a[not(contains(@href,"https"))] 命中 href 不含 https 的 a', () {
      final xp = AnalyzeByXPath(_htmlB);
      expect(xp.getStringList('//a[not(contains(@href,"https"))]'), ['无href']);
    });
  });

  group('translate()', () {
    // 对齐 jsoup-xpath：translate 按字符映射，from 中超出 to 长度的字符被删除。
    test('//div[translate(@date,"-","/")=...] 命中', () {
      final xp = AnalyzeByXPath(_htmlC);
      expect(
        xp.getStringList('//div[translate(@date,"-","/")="2024/01/01"]'),
        ['一条'],
      );
    });
  });

  group('嵌套表达式：函数作为另一函数的参数', () {
    // substring('x关键词y',2,3) → 1-based 取第2位起3字符 → "关键词"。
    test('//a[contains(text(),substring("x关键词y",2,3))] 命中', () {
      final xp = AnalyzeByXPath(_htmlD);
      expect(
        xp.getStringList('//a[contains(text(),substring("x关键词y",2,3))]'),
        ['这是关键词内容'],
      );
    });

    // substring('zz-item',4) → 1-based 第4位起 → "item"。
    test('//li[contains(@class,substring("zz-item",4))] 命中两条', () {
      final xp = AnalyzeByXPath(_htmlD);
      expect(
        xp.getStringList('//li[contains(@class,substring("zz-item",4))]'),
        ['甲', '乙'],
      );
    });

    // concat 作为 contains 的参数。
    test('//a[contains(text(),concat("关键","词"))] 命中', () {
      final xp = AnalyzeByXPath(_htmlD);
      expect(
        xp.getStringList('//a[contains(text(),concat("关键","词"))]'),
        ['这是关键词内容'],
      );
    });
  });

  group('与位置/比较谓词组合', () {
    test('//li[position()<3 and contains(@class,"a")] 命中前两条中 class 含 a 的', () {
      final xp = AnalyzeByXPath(_htmlE);
      expect(
        xp.getStringList('//li[position()<3 and contains(@class,"a")]'),
        ['1'],
      );
    });
  });
}
