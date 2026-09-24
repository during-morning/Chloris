// CSS 索引区间 / 属性算子 与 Legado-E AnalyzeByJSoup.kt 的逐条对齐测试。
//
// 语义以 reference/legado-E-main .../AnalyzeByJSoup.kt 的 getElementsSingle
// (range 展开, 行 339-370) 与 getResultLast (属性算子, 行 270-277) 为准。
import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

// 5 个 <li>：索引 0..4，文本为 '0'..'4'。
const _five =
    '<ul><li>0</li><li>1</li><li>2</li><li>3</li><li>4</li></ul>';

void main() {
  // ── 行 1：区间右端是否包含 ──────────────────────────────────────────────
  // 文档主张 Legado `start..end` 不含 end；但 Kotlin `..` / `downTo` 是闭区间，
  // 行 370 `start..end step step` 含 end。故 `[1:4]` 真实为 {1,2,3,4}。
  test('range end is inclusive (Kotlin closed range)', () {
    final css = AnalyzeByCss(_five);
    expect(css.getStringList('tag.li[1:4]'), ['1', '2', '3', '4']);
    expect(css.getStringList('tag.li[2:4]'), ['2', '3', '4']);
    // 带 step 时端点同样包含
    expect(css.getStringList('tag.li[0:4:2]'), ['0', '2', '4']);
  });

  // ── 行 2：越界区间（同侧越界跳过 + 混合边界 clamp）──────────────────────
  // 两端同侧越界 → 整段跳过，结果为空。
  test('same-side out-of-bounds range is skipped (empty result)', () {
    final css = AnalyzeByCss(_five);
    expect(css.getStringList('tag.li[10:20]'), isEmpty); // start,end 均 >= len
    expect(css.getStringList('tag.li[-10:-6]'), isEmpty); // 均为负越界
  });

  test('mixed-bounds range clamps out-of-bounds endpoint (legado :353-357)', () {
    final css = AnalyzeByCss(_five);
    // start 越界(高) → clamp 到 len-1=4；end 在界内 → 反向展开
    expect(css.getStringList('tag.li[10:2]'), ['4', '3', '2']);
    // end 越界(高) → clamp 到 len-1=4
    expect(css.getStringList('tag.li[1:10]'), ['1', '2', '3', '4']);
  });

  // ── 行 3：step >= len → 区间仅含 start ──────────────────────────────────
  test('step >= len yields only the start index (legado :359-364)', () {
    final css = AnalyzeByCss(_five);
    expect(css.getStringList('tag.li[0:4:10]'), ['0']); // 10 >= len(5)
    expect(css.getStringList('tag.li[1:4:5]'), ['1']); // 5 >= len(5)
  });

  // ── 行 4：负 step 归一（legado :366-370）────────────────────────────────
  // stepX < 0 且 -stepX < len → step = stepX + len。
  test('negative step normalization (legado :366-367)', () {
    final css = AnalyzeByCss(_five);
    // stepX=-1, -stepX=1<5 → step = -1+5 = 4 → 4 downTo 0 step 4 = {4,0}
    expect(css.getStringList('tag.li[4:0:-1]'), ['4', '0']);
    // stepX=-2, -stepX=2<5 → step = -2+5 = 3 → 4 downTo 0 step 3 = {4,1}
    expect(css.getStringList('tag.li[4:0:-2]'), ['4', '1']);
  });

  // ── 行 4b：降序区间必须能终止 ───────────────────────────────────────────
  // 回归守卫：`end < start` 走的是 Kotlin `start downTo end step step` 分支，
  // 归一后的 step 恒为正，实现里必须递减。写成递增会变成死循环（历史上真实
  // 发生过：整轮 dart test 挂死）。
  test('descending range terminates and walks backwards', () {
    final css = AnalyzeByCss(_five);
    // stepX=-3, -stepX=3<5 → step = -3+5 = 2 → 4 downTo 0 step 2 = {4,2,0}
    expect(css.getStringList('tag.li[4:0:-3]'), ['4', '2', '0']);
    // 反向整个列表（Legado 注释里的 `tag.div[-1:0]` 特殊用法）
    expect(css.getStringList('tag.li[-1:0]'), ['4', '3', '2', '1', '0']);
    // 显式带 step 的反向
    expect(css.getStringList('tag.li[-1:0:2]'), ['4', '2', '0']);
  });

  // ── 行 5：空区间 / 空集合结果 ────────────────────────────────────────────
  // 1) 索引产生空集 → 返回空（不回退为全部元素）。
  test('empty index set returns empty, not all elements', () {
    final css = AnalyzeByCss(_five);
    expect(css.getStringList('tag.li[10:20]'), isEmpty); // 同侧越界 → 空
  });
  // 2) 完全无索引 → 返回全部元素（与 Legado 一致：无索引即全选）。
  test('no index operator returns all elements', () {
    final css = AnalyzeByCss(_five);
    expect(css.getStringList('tag.li'), ['0', '1', '2', '3', '4']);
  });

  // ── 行 6：属性算子去重 ──────────────────────────────────────────────────
  // 文档主张 Legado 保留重复值；但 getResultLast 行 274
  // `if (url.isBlank() || textS.contains(url)) continue` 实际会去重。
  // 三个 <a> href 为 /a,/a,/b → 真实 Legado 与 Chloris 均为 [/a, /b]。
  test('attribute operator dedups (legado getResultLast :274)', () {
    final css = AnalyzeByCss(
      '<a href="/a">A</a><a href="/a">B</a><a href="/b">C</a>',
    );
    expect(css.getStringList('a@href'), ['/a', '/b']);
  });
}
