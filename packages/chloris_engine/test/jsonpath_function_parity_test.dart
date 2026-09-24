// JSONPath 函数扩展与数组结果的逐条对齐测试。
//
// 期望值来自 tool/legado_oracle 判题进程（编译 Legado 原始 AnalyzeByJSonPath.kt
// + Jayway json-path 2.10.0）实测，命令形如：
//   echo '{"kind":"json","content":"{\"a\":[1,2,3]}","rule":"$.a.length()"}' \
//     | tool/legado_oracle/build/install/legado-oracle/bin/legado-oracle
import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  group('数组结果（P0-3 之外、由双侧 golden 抓到的真实分歧）', () {
    // 判题进程实测：`$.chapters` 于 {"chapters":["ch1","ch2","ch3"]}
    //   → Legado  "ch1\nch2\nch3"
    // 修复前 Chloris 会把整个数组 jsonEncode 成 `["ch1","ch2","ch3"]`。
    // 根因：AnalyzeByJSonPath.kt:44-50 是 `ob is List -> joinToString("\n")`，
    // 而 Chloris 的 _read 返回「被选中节点」的列表，单个数组选择会多包一层。
    test('getString 对单个数组选择按元素展开（对齐 AnalyzeByJSonPath.kt:46-47）', () {
      final jp = AnalyzeByJsonPath('{"chapters":["ch1","ch2","ch3"]}');
      expect(jp.getString(r'$.chapters'), 'ch1\nch2\nch3');
    });

    test('getStringList 对单个数组选择逐元素返回', () {
      final jp = AnalyzeByJsonPath('{"chapters":["ch1","ch2","ch3"]}');
      expect(jp.getStringList(r'$.chapters'), ['ch1', 'ch2', 'ch3']);
    });

    test('标量选择不受展开逻辑影响', () {
      final jp = AnalyzeByJsonPath('{"a":"x","b":7}');
      expect(jp.getString(r'$.a'), 'x');
      expect(jp.getString(r'$.b'), '7');
    });
  });

  group('Jayway 函数扩展（计划 §12 的 P2，补高频子集）', () {
    test('length()', () {
      final jp = AnalyzeByJsonPath('{"a":[1,2,3]}');
      expect(jp.getString(r'$.a.length()'), '3');
    });

    test('first() / last()', () {
      final jp = AnalyzeByJsonPath('{"a":[1,2,3]}');
      expect(jp.getString(r'$.a.first()'), '1');
      expect(jp.getString(r'$.a.last()'), '3');
    });

    test('sum() / min() / max() / avg()', () {
      // 判题进程实测：sum → "10.0"、min → "1.0"、max → "4.0"、avg → "2.5"
      // （Jayway 的 sum/min/max 返回 Double，length() 返回 Integer）。
      final jp = AnalyzeByJsonPath('{"a":[1,2,3,4]}');
      expect(jp.getString(r'$.a.sum()'), '10.0');
      expect(jp.getString(r'$.a.min()'), '1.0');
      expect(jp.getString(r'$.a.max()'), '4.0');
      expect(jp.getString(r'$.a.avg()'), '2.5');
    });

    test('已知分歧：keys() 的形态与 Legado 不同（不在本轮修复范围）', () {
      // 判题进程实测 `$.a.keys()` 于 {"a":{"x":1,"y":2}} → "[x, y]"。
      // 原因：Jayway 的 keys() 返回 Set（不是 List），因此
      // AnalyzeByJSonPath.kt:46 的 `ob is List` 为假，走到 `ob.toString()`，
      // 得到 Java 集合的 toString 形态 `[x, y]`。
      // Chloris 返回分离的键值，更利于后续用 && / %% 组合，但因此与 Legado
      // 不是逐字相同。属刻意保留的差异。
      final jp = AnalyzeByJsonPath('{"a":{"x":1,"y":2}}');
      expect(jp.getStringList(r'$.a.keys()'), ['x', 'y']);
    });

    test('未知函数保持空结果，不抛异常', () {
      final jp = AnalyzeByJsonPath('{"a":[1,2,3]}');
      expect(jp.getStringList(r'$.a.noSuchFn()'), isEmpty);
    });
  });

  group('既有 JSONPath 能力不能被破坏', () {
    test('递归、切片、联合、通配、过滤仍可用', () {
      final jp = AnalyzeByJsonPath(
        '{"s":{"a":1,"b":2},"list":[{"n":1},{"n":2}]}',
      );
      expect(jp.getStringList(r'$..a'), ['1']);
      expect(jp.getStringList(r'$.list[0:2].n'), ['1', '2']);
      expect(jp.getStringList(r'$["s"].a'), ['1']);
      expect(jp.getStringList(r'$.list[*].n'), ['1', '2']);
      expect(jp.getStringList(r'$.list[?(@.n>1)].n'), ['2']);
    });
  });
}
