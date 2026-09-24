// XPath 轴选择补全测试（任务：补齐 text()/@attr 轴末端与文本节点语义）。
//
// 对照 reference/legado-E-main/.../AnalyzeByXPath.kt —— Legado 完全委托给
// jsoup-xpath（org.seimicrawler.xpath）。本文件的期望值均由 tool/legado_oracle
// 判题进程（直接编译 Legado 原始 .kt）逐条实测得到，命令形如：
//   echo '{"kind":"xpath","content":"<a>pre<b>mid</b>post</a>","rule":"//a/text()"}' \
//     | tool/legado_oracle/build/install/legado-oracle/bin/legado-oracle
//
// 实测结论（决定期望值）：
//   //a/text()   on <a>pre<b>mid</b>post</a>        -> ["pre","post"]   (子轴=直接文本子节点)
//   //a//text()  on <div><p>one</p><p>two</p></div>-> ["one","two"]     (后代轴=所有文本节点)
//   //a/@href    on 多 <a>                          -> 各 href 属性值
// 关键对齐点：Chloris 旧实现用 e.text（元素全文）兜底 text()，会把
// <a>pre<b>mid</b>post</a> 的 //a/text() 错误拼成 "premidpost"，与 Legado 分叉。
import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

// 混合内容：直接文本子节点 pre / post，中间 <b> 不是直接子文本。
const _mixed = '<div><a href="/x">pre<b>mid</b>post</a>'
    '<a href="/y">hello</a><a href="/z">world</a></div>';

// 后代文本：div 下两个 p 的文本。
const _descendant = '<div><p>one</p><p>two</p></div>';

void main() {
  group('text() 末端轴（子轴 = 直接文本子节点）', () {
    test('//a/text() 返回每个 <a> 的直接文本子节点，而非元素全文', () {
      final xp = AnalyzeByXPath(_mixed);
      // 第一个 <a> 的直接文本子节点是 "pre" 与 "post"（中间的 <b> 不算）。
      // 旧实现 e.text 会得到 "premidpost"，与 Legado 实测 ["pre","post"] 分叉。
      expect(
        xp.getStringList('//a/text()'),
        ['pre', 'post', 'hello', 'world'],
      );
    });

    test('//a/text() 经 getString 以 \\n 连接', () {
      final xp = AnalyzeByXPath(_mixed);
      expect(xp.getString('//a/text()'), 'pre\npost\nhello\nworld');
    });

    test('简单纯文本 <a> 仍按单一文本子节点返回', () {
      final xp = AnalyzeByXPath('<a href="/x">hi</a><b>bye</b>');
      expect(xp.getStringList('//a/text()'), ['hi']);
    });

    test('//t[1]/text() 位置谓词 + 文本轴', () {
      final xp = AnalyzeByXPath('<book><t>abc</t><t>de</t></book>');
      expect(xp.getStringList('//t[1]/text()'), ['abc']);
    });
  });

  group('text() 末端轴（后代轴 //text() = 所有后代文本节点）', () {
    test('//div//text() 收集 div 下全部文本节点（按文档序）', () {
      final xp = AnalyzeByXPath(_descendant);
      // 旧实现用 e.text 会得到单条 "one\ntwo"，与 Legado 实测 ["one","two"] 分叉。
      expect(xp.getStringList('//div//text()'), ['one', 'two']);
    });
  });

  group('@attr 末端轴（属性节点 -> 属性值）', () {
    test('//a/@href 返回每个 <a> 的 href 属性值', () {
      final xp = AnalyzeByXPath(_mixed);
      expect(xp.getStringList('//a/@href'), ['/x', '/y', '/z']);
    });

    test('//a[@href]/@href 谓词筛选 + 属性轴', () {
      final xp = AnalyzeByXPath(_mixed);
      expect(xp.getStringList('//a[@href]/@href'), ['/x', '/y', '/z']);
    });

    test('命名空间属性 foo:bar 也应可取', () {
      final xp = AnalyzeByXPath('<a foo:bar="v1" href="v2">x</a>');
      expect(xp.getStringList('//a/@foo:bar'), ['v1']);
    });

    test('//a[contains(@href,"x")]/text() 谓词属性 + 文本轴组合', () {
      final xp = AnalyzeByXPath(_mixed);
      expect(xp.getStringList('//a[contains(@href,"x")]/text()'), ['pre', 'post']);
    });
  });

  group('回归保护：既有 text()/@attr 行为不被破坏', () {
    test('//t/text() 纯文本元素', () {
      final xp = AnalyzeByXPath('<book><t>abc</t><t>de</t></book>');
      expect(xp.getStringList('//t/text()'), ['abc', 'de']);
    });

    test('//li[1]/text() 位置谓词', () {
      final xp = AnalyzeByXPath('<ul><li>one</li><li>two</li></ul>');
      expect(xp.getStringList('//li[1]/text()'), ['one']);
    });
  });
}
