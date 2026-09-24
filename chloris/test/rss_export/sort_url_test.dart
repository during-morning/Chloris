// 纯 Dart 实跑：验证 sortUrl 分类解析（对应 legado RssSourceExtensions.sortUrls）。
// 运行：dart run test/rss_export/sort_url_test.dart
import '../../lib/application/rss/rss_sort_url.dart';

int _failures = 0;

void check(String name, bool ok, [String detail = '']) {
  if (ok) {
    print('  ✓ $name');
  } else {
    _failures++;
    print('  ✗ $name ${detail.isNotEmpty ? '-> $detail' : ''}');
  }
}

void main() {
  print('sortUrl 解析测试');

  // 1. 空 / null 回退空列表
  check('null -> 空', parseSortUrls(null).isEmpty);
  check('空串 -> 空', parseSortUrls('   ').isEmpty);

  // 2. && 与换行 混合分隔，每条 名称::url 拆名
  final mixed = parseSortUrls(
    '综合::https://a.com/all && 科技::https://a.com/tech\n财经::https://a.com/fin',
  );
  check('混合分隔得到 3 条', mixed.length == 3, '实际 ${mixed.length}');
  check(
    '第1条 综合',
    mixed[0].name == '综合' && mixed[0].url == 'https://a.com/all',
    mixed[0].toString(),
  );
  check(
    '第2条 科技',
    mixed[1].name == '科技' && mixed[1].url == 'https://a.com/tech',
    mixed[1].toString(),
  );
  check(
    '第3条 财经',
    mixed[2].name == '财经' && mixed[2].url == 'https://a.com/fin',
    mixed[2].toString(),
  );

  // 3. 仅 && 分隔
  final onlyAnd = parseSortUrls('推荐::https://x/rec && 热点::https://x/hot');
  check('仅 && 得到 2 条', onlyAnd.length == 2);
  check('推荐 url', onlyAnd[0].url == 'https://x/rec');

  // 4. 连续分隔符折叠（&&& 或 多换行）
  final multi = parseSortUrls('A::https://a &&&& B::https://b\n\nC::https://c');
  check('连续分隔符折叠为 3 条', multi.length == 3, '实际 ${multi.length}');

  // 5. 无 :: 的分条被跳过（url 为空）
  final noSep = parseSortUrls('综合 && 科技::https://a.com/tech');
  check('无 :: 的条目被跳过', noSep.length == 1, '实际 ${noSep.length}');
  check('保留含 :: 的条目', noSep.single.url == 'https://a.com/tech');

  // 6. 名称为空（::url）仍保留
  final emptyName = parseSortUrls('::https://a.com/x');
  check('空名称但 url 非空 -> 保留', emptyName.length == 1);
  check(
    '空名称值',
    emptyName.single.name == '' && emptyName.single.url == 'https://a.com/x',
  );

  // 7. <js>/@js: 前缀动态脚本 -> 当前不支持，回退空
  check('<js> 前缀 -> 空', parseSortUrls('<js>xxx</js>').isEmpty);
  check('@js: 前缀 -> 空', parseSortUrls('@js:xxx').isEmpty);

  print(_failures == 0 ? '\n全部通过 ✅' : '\n失败 $_failures 项 ❌');
  if (_failures > 0) throw StateError('sortUrl 测试未通过');
}
