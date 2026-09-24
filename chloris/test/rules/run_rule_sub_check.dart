// 纯 Dart 验收脚本：不依赖 Flutter，直接 `dart run` 实跑订阅核心逻辑。
//
// 运行：
//   cd /Volumes/Software/Chloris/chloris
//   ../../reference/flutter-sdk/flutter/bin/cache/dart-sdk/bin/dart run test/rules/run_rule_sub_check.dart
//
// 用假 fetch 注入 2 条规则 JSON，验证：拉取→合并→重复拉取幂等→删除订阅清规则。

import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';

import 'package:chloris/features/rules/rule_sub_sync.dart';

/// 假 fetch：第一次返回原始 2 条；第二次（幂等）返回内容相同但顺序打乱的 2 条；
/// 第三次返回一个被「远端删除」其中 1 条后的集合，验证增量删除。
String _fakeBody(int call) {
  if (call == 1) {
    return jsonEncode([
      {
        'id': 11,
        'name': '去广告A',
        'pattern': r'\s*广告\s*',
        'replacement': '',
        'isRegex': true,
      },
      {
        'id': 12,
        'name': '繁转简B',
        'pattern': '臺',
        'replacement': '台',
        'isRegex': false,
      },
    ]);
  }
  if (call == 2) {
    // 顺序打乱、内容一致 → 应幂等（条数不变、id 不变）。
    return jsonEncode([
      {
        'id': 12,
        'name': '繁转简B',
        'pattern': '臺',
        'replacement': '台',
        'isRegex': false,
      },
      {
        'id': 11,
        'name': '去广告A',
        'pattern': r'\s*广告\s*',
        'replacement': '',
        'isRegex': true,
      },
    ]);
  }
  // call == 3：远端删掉了 id=12，新增一条 id=13。
  return jsonEncode([
    {
      'id': 11,
      'name': '去广告A',
      'pattern': r'\s*广告\s*',
      'replacement': 'X', // 内容也变了，验证原地更新
      'isRegex': true,
    },
    {
      'id': 13,
      'name': '新规则C',
      'pattern': 'foo',
      'replacement': 'bar',
    },
  ]);
}

Future<void> main() async {
  final store = InMemoryReplaceRuleStore();
  final persistence = InMemoryRuleSubPersistence();

  // 预置 1 条用户自有规则（id 为 null，不应被订阅覆盖/删除）。
  store.replaceAll([
    ReplaceRule(name: '用户规则', pattern: 'u', replacement: 'v'),
  ]);

  int fetchCall = 0;
  Future<String> fakeFetch(String url) async {
    fetchCall++;
    return _fakeBody(fetchCall);
  }

  final sync = RuleSubSync(
    fetcher: fakeFetch,
    store: store,
    persistence: persistence,
  );

  void assertCond(bool cond, String label) {
    print('  [${cond ? 'PASS' : 'FAIL'}] $label');
    if (!cond) throw StateError('断言失败：$label');
  }

  print('=== 替换规则订阅核心逻辑验收 ===');

  // 1) 拉取 + 合并
  print('1) 添加订阅并首次拉取');
  final sub = await sync.addSubscription('https://example.com/sub.json',
      name: '测试订阅');
  // 刷新后 lastUpdate 只写回持久化副本，需重新读取订阅列表来验证。
  final savedSub = (await sync.listSubscriptions()).firstWhere((s) => s.id == sub.id);
  var rules = store.current();
  assertCond(rules.length == 3, '合并后共 3 条（1 用户 + 2 订阅），实际 ${rules.length}');
  final subRules = rules.where((r) => r.id != null).toList();
  assertCond(subRules.length == 2, '订阅写入 2 条，实际 ${subRules.length}');
  assertCond(savedSub.lastUpdate > 0, '订阅 lastUpdate 已更新');
  assertCond(persistence.indexes[sub.id]!.length == 2, '索引记录了 2 条内容键');
  final firstIds = subRules.map((r) => r.id!).toSet();
  assertCond(firstIds.every((id) => id < 0), '订阅规则使用负 id 区间：$firstIds');

  // 2) 重复拉取幂等
  print('2) 再次拉取（顺序打乱、内容一致）→ 应幂等');
  final n2 = await sync.refresh(sub.id);
  assertCond(n2 == 2, '再次写入 2 条，实际 $n2');
  rules = store.current();
  assertCond(rules.length == 3, '总数仍为 3，实际 ${rules.length}');
  final secondIds = rules.where((r) => r.id != null).map((r) => r.id!).toSet();
  assertCond(
      secondIds.difference(firstIds).isEmpty &&
          firstIds.difference(secondIds).isEmpty,
      '规则 id 保持稳定（原地更新）：$firstIds vs $secondIds');

  // 3) 远端删 1 条 + 改 1 条 + 增 1 条
  print('3) 第三次拉取（删 1 改 1 增 1）');
  final n3 = await sync.refresh(sub.id);
  rules = store.current();
  assertCond(n3 == 2, '本次写入 2 条（删1增1），实际 $n3');
  assertCond(rules.length == 3, '总数仍为 3（1 用户 + 2 订阅），实际 ${rules.length}');
  final ad = rules.firstWhere((r) => r.pattern == r'\s*广告\s*');
  assertCond(ad.replacement == 'X', '原规则被原地更新为 replacement=X，实际 ${ad.replacement}');
  assertCond(rules.any((r) => r.pattern == 'foo'), '新增规则 foo→bar 已出现');
  assertCond(!rules.any((r) => r.pattern == '臺'), '被远端删除的 臺→台 已清除');

  // 4) 删除订阅 → 清除其全部规则，用户规则保留
  print('4) 删除订阅 → 移除其规则、保留用户规则');
  await sync.removeSubscription(sub.id);
  rules = store.current();
  assertCond(rules.length == 1, '仅剩 1 条用户规则，实际 ${rules.length}');
  assertCond(rules.single.pattern == 'u', '用户规则未被误删');
  assertCond(persistence.indexes[sub.id] == null, '订阅索引已删除');
  final remainingSubs = await sync.listSubscriptions();
  assertCond(remainingSubs.isEmpty, '订阅列表已空');

  print('');
  print('全部断言通过 ✅');
}
