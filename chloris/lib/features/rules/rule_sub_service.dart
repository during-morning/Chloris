import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/persist/kv_settings.dart';
import 'replace_rules_controller.dart';
import 'rule_sub_sync.dart';

/// 真实拉取实现：用 chloris_engine 的 [PackageHttpPort] 完成 GET，返回响应体字符串。
///
/// legado 语义为「GET url → 响应体即 JSON 数组」（RuleUpdate.kt 的
/// `okHttpClient.newCallResponseBody{...}.decompressed()`）。这里用引擎内置的
/// HTTP 端口，自动处理编码（含 GBK/Big5）。
Future<String> _httpFetch(String url) async {
  final port = PackageHttpPort();
  final Uint8List bytes = await port.getBytes(url);
  return utf8.decode(bytes, allowMalformed: true);
}

/// 把 [ReplaceRulesNotifier] 适配为 [ReplaceRuleStore]。
class KvReplaceRuleStore implements ReplaceRuleStore {
  KvReplaceRuleStore(this._notifier);

  final ReplaceRulesNotifier _notifier;

  @override
  List<ReplaceRule> current() => _notifier.snapshot();

  @override
  Future<void> replaceAll(List<ReplaceRule> rules) async {
    _notifier.replaceAll(rules);
  }
}

/// 基于 [KvSettings] 的订阅持久化（与 replaceRules 同模式：单 JSON 串存键）。
///
/// - 订阅列表：`ruleSubs`
/// - 每个订阅的 contentKey→id 索引：`ruleSubIndex:<subId>`
///
/// 不进数据库（DB 的 ReplaceRules 表只是 KV 的镜像，订阅属于「来源标记」元数据）。
class KvRuleSubPersistence implements RuleSubPersistence {
  static const _subsKey = 'ruleSubs';

  String _indexKey(int subId) => 'ruleSubIndex:$subId';

  @override
  Future<List<RuleSub>> loadSubs() async {
    final p = await KvSettings.ready();
    final raw = p.getString(_subsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => RuleSub.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveSubs(List<RuleSub> subs) async {
    final p = await KvSettings.ready();
    await p.setString(
      _subsKey,
      jsonEncode(subs.map((s) => s.toJson()).toList()),
    );
  }

  @override
  Future<Map<String, int>> loadIndex(int subId) async {
    final p = await KvSettings.ready();
    final raw = p.getString(_indexKey(subId));
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map;
      return m.map((k, v) => MapEntry(k as String, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveIndex(int subId, Map<String, int> index) async {
    final p = await KvSettings.ready();
    await p.setString(_indexKey(subId), jsonEncode(index));
  }

  @override
  Future<void> deleteIndex(int subId) async {
    final p = await KvSettings.ready();
    await p.remove(_indexKey(subId));
  }
}

/// 订阅同步服务。真实环境下使用 KvSettings 持久化与引擎 HTTP 拉取。
final ruleSubSyncProvider = Provider<RuleSubSync>((ref) {
  final notifier = ref.watch(replaceRulesProvider.notifier);
  return RuleSubSync(
    fetcher: _httpFetch,
    store: KvReplaceRuleStore(notifier),
    persistence: KvRuleSubPersistence(),
  );
});
