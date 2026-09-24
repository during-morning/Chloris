import 'package:test/test.dart';
import 'package:chloris_engine/chloris_engine.dart';

/// 输出格式对齐 Legado-E 的判题进程实测值
/// （artifacts/verification/20260912-rule-engine-parity 双侧判题记录）。
/// 三组断言对应曾经的三类「格式差而非语义差」失配：
///   - JsonPath 对象的 Jayway toString（`{k=v}` 而非 `{"k":v}`）
///   - CSS `@html`/`@all` 的 jsoup prettyPrint 缩进
///   - `getString` 遇 `%%` 组合符返回空（`%%` 只在 list/elements 有意义）
void main() {
  group('JsonPath Jayway toString', () {
    test('对象命中 -> Java AbstractMap 风格 {k=v}（json-015/016/027/031/032）', () {
      final vip = AnalyzeByJsonPath(
        '{"data":{"chapters":[{"vip":true,"t":"v1"},{"vip":false,"t":"v2"}]}}',
      );
      expect(
        vip.getString(r'$.data.chapters[?(@.vip==true)]'),
        '{vip=true, t=v1}',
      );
      final price = AnalyzeByJsonPath(
        '{"books":[{"price":8,"n":"a"},{"price":20,"n":"b"}]}',
      );
      expect(price.getString(r'$.books[?(@.price < 10)]'), '{price=8, n=a}');
    });

    test('对象内的数组值仍是 JSON 格式（json-011）', () {
      final a = AnalyzeByJsonPath('{"data":{"data":["d1","d2"]}}');
      expect(a.getString(r'$.data'), '{data=["d1","d2"]}');
    });

    test('嵌套对象递归用 AbstractMap 格式（json-030）', () {
      final a = AnalyzeByJsonPath('{"a":1,"b":{"c":2}}');
      expect(a.getString(r'$..*'), '1\n{c=2}\n2');
    });

    test('getString 遇 %% 组合符返回空（json-012/028，Legado 实测 ""）', () {
      final a = AnalyzeByJsonPath('{"a":["a1","a2"],"b":["b1","b2"],"c":["c1"]}');
      expect(a.getString(r'$.a[*]%%$.b[*]'), '');
      expect(a.getString(r'$.a[*]%%$.b[*]%%$.c[*]'), '');
      // getStringList 的逐位交错不受影响
      expect(a.getStringList(r'$.a[*]%%$.b[*]'), ['a1', 'b1', 'a2', 'b2']);
    });
  });

  group('CSS jsoup prettyPrint', () {
    test('@html 按缩进序列化（css-024）', () {
      final a = AnalyzeByCss('<div><span>内容</span></div>');
      expect(a.getString('div@html'), '<div>\n <span>内容</span>\n</div>');
    });

    test('@all 同样缩进，inline 非首子不换行（css-025）', () {
      final a = AnalyzeByCss('<div><span>一</span><span>二</span></div>');
      expect(
        a.getString('div@all'),
        '<div>\n <span>一</span><span>二</span>\n</div>',
      );
    });

    test('empty 标签不带尾标签，属性值转义对齐 WHATWG', () {
      final a = AnalyzeByCss('<div><img src="a.png"><br><p>x &amp; y</p></div>');
      expect(
        a.getString('div@all'),
        '<div>\n <img src="a.png">\n <br>\n <p>x &amp; y</p>\n</div>',
      );
    });

    test('preserveWhitespace 标签内文本不归一', () {
      final a = AnalyzeByCss('<pre><code>a  b\n  c</code></pre>');
      final s = a.getString('pre@all');
      expect(s, contains('a  b\n  c'));
    });
  });

  group('XPath node()', () {
    test('子轴 node() 返回文本与元素节点（文档序）', () {
      final a = AnalyzeByXPath('<div>t1<b>b1</b>t2</div>');
      // //div/node() -> div 的直接子节点：text t1、元素 b（字面值 b1）、text t2
      expect(a.getStringList('//div/node()'), ['t1', 'b1', 't2']);
    });

    test('后代轴 //node() 递归收集', () {
      final a = AnalyzeByXPath('<div><p>a<u>x</u>b</p></div>');
      // div 的后代节点：p（字面值 axb）、a、u（x）、x、b —— XPath 节点集
      // 语义下元素字面值含其后代文本，重复是正常的。
      expect(a.getStringList('//div//node()'), ['axb', 'a', 'x', 'x', 'b']);
    });
  });
}
