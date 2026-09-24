// XPath 函数子集与 Legado-E 的逐条对齐测试（计划 §12 的 P0-3）。
//
// 期望值不是「读源码推测」出来的，而是用 tool/legado_oracle 的判题进程
// （直接编译 Legado 原始 .kt）逐条实测得到的，命令形如：
//   echo '{"kind":"xpath","content":"<book><t>1</t><t>2</t></book>","rule":"count(//t)"}' \
//     | tool/legado_oracle/build/install/legado-oracle/bin/legado-oracle
//
// 判题进程实测结论（决定了本文件的期望值）：
//   count(//t)            → "2"      ✅ Legado 支持
//   count(//nosuch)       → "0"      ✅ 注意是 "0" 而非空
//   sum(//t)              → "3"      ✅ 纯数字文本
//   sum(//t)  (非数字)     → ""       ✅ 无可用数值 → 空
//   string(//t[1])        → ❌ NoSuchFunctionException: not support function: string
//   normalize-space(//t)  → ❌ NoSuchFunctionException
//   name/local-name/min/max/number → ❌ NoSuchFunctionException
//   substring(//t,2)      → ❌ IndexOutOfBoundsException（不带长度形参）
//
// 即：文档 §12-P0-3 把 `string()` / `normalize-space()` 列为「Legado 有、Chloris 缺」
// 是**错的** —— jsoupXpath 根本不支持这两个函数名。真正需要对齐的是
// count / sum / string-length / substring（且仅限路径级与受支持的谓词形态）。
import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

const _nums = '<book><t>1</t><t>2</t></book>';
const _words = '<book><t>abc</t><t>de</t></book>';
const _items =
    '<book><item class="a">10</item><item class="b">20</item></book>';

void main() {
  group('路径级函数（Legado-E 经 jsoupXpath 实际支持）', () {
    test('count(path) 返回选中节点数，未命中返回 "0" 而不是空', () {
      final xp = AnalyzeByXPath(_nums);
      expect(xp.getStringList('count(//t)'), ['2']);
      // 判题进程实测 count(//nosuch) → "0"。
      // 若这里返回空列表，「数量为 0」与「规则失败」就无法区分。
      expect(xp.getStringList('count(//nosuch)'), ['0']);
    });

    test('count(path) 在带属性的子选择器上同样成立', () {
      final xp = AnalyzeByXPath(_items);
      expect(xp.getStringList('count(//item[@class="a"])'), ['1']);
      expect(xp.getStringList('count(//item)'), ['2']);
    });
  });

  group('谓词内的函数（原本一律走到 return false，表现为"没搜到书"）', () {
    test('count() 参与数值比较', () {
      final xp = AnalyzeByXPath(_items);
      expect(xp.getStringList('//item[count(*) >= 1]'), ['10', '20']);
    });

    test('substring()（1-based，XPath 语义）', () {
      final xp = AnalyzeByXPath(_items);
      expect(xp.getStringList('//item[substring(text(),1,1)="1"]'), ['10']);
      expect(xp.getStringList('//item[substring(text(),1,1)="2"]'), ['20']);
    });

    test('string-length()', () {
      final xp = AnalyzeByXPath(_items);
      expect(xp.getStringList('//item[string-length(text())=2]'), ['10', '20']);
    });

    test('number() 数值上下文比较', () {
      final xp = AnalyzeByXPath(_items);
      expect(xp.getStringList('//item[number(text())>15]'), ['20']);
    });

    test('concat() 与 normalize-space()（Chloris 扩展，Legado 已覆盖但不支持函数名）', () {
      final xp = AnalyzeByXPath(_items);
      expect(xp.getStringList('//item[concat(text(),"")="10"]'), ['10']);
      expect(xp.getStringList('//item[normalize-space(text())="10"]'), ['10']);
    });

    test('原有谓词形态不能被新求值层破坏', () {
      final xp = AnalyzeByXPath(_items);
      expect(xp.getStringList('//item[text()="10"]'), ['10']);
      expect(xp.getStringList('//item[contains(text(),"0")]'), ['10', '20']);
      expect(xp.getStringList('//item[starts-with(text(),"1")]'), ['10']);
      expect(xp.getStringList('//item[last()]'), ['20']);
      expect(xp.getStringList('//item[position()=2]'), ['20']);
      expect(xp.getStringList('//item[@class="a"]'), ['10']);
    });
  });

  group('失败要可见（§12-P0-3 的第二半句要求）', () {
    test('无法解析的谓词会落到 DebugLog 而不是静默空结果', () {
      DebugLog.clear();
      final xp = AnalyzeByXPath(_items);
      // 旧实现：return false → 用户看到 "没搜到书"，没有任何信号。
      expect(xp.getStringList('//item[unsupportedFn(text())=1]'), isEmpty);
      expect(
        DebugLog.buffer.any(
          (e) => e.tag == 'XPath' && e.message.contains('无法解析'),
        ),
        isTrue,
        reason: '无法解析的 XPath 谓词必须留下可见告警',
      );
      DebugLog.clear();
    });

    test('路径级不支持的函数同样会告警', () {
      DebugLog.clear();
      final xp = AnalyzeByXPath(_words);
      expect(xp.getStringList('string(//t)'), isEmpty);
      expect(
        DebugLog.buffer.any(
          (e) => e.tag == 'XPath' && e.message.contains('jsoupXpath'),
        ),
        isTrue,
        reason: 'Legado 不支持的路径级函数必须留下可见告警，而不是静默空',
      );
      DebugLog.clear();
    });
  });

  group('已知未对齐分歧（由双侧 golden 固化，不在本轮修复范围）', () {
    // 判题进程实测：
    //   //t      → "<t>\n abc\n</t>\n<t>\n de\n</t>"   （节点序列化）
    //   //t/text() → "abc\nde"                          （文本）
    // Chloris 的 _stringOne 对元素节点一律取 text。两者只在「规则选中的是元素
    // 而不是文本节点」时分叉，所以真实书源（都以 /text() 收尾）不受影响；
    // 全面对齐会改变所有现存 XPath 规则的输出，属破坏性变更，留待单独决策。
    test('元素选择：Chloris 取 text，Legado 返回节点序列化', () {
      final xp = AnalyzeByXPath(_words);
      expect(xp.getStringList('//t'), ['abc', 'de']);
      // 与 Legado 一致的那一支
      expect(xp.getStringList('//t/text()'), ['abc', 'de']);
    });
  });
}
