import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';

/// 替换规则订阅实体（内存 + KvSettings 持久化，不进 DB）。
///
/// 对应 legado `RuleSub`（reference/legado-E-main/.../data/entities/RuleSub.kt），
/// 但只保留 Chloris 需要的字段，并固定 `type = 替换规则`。legado 中替换规则的
/// 拉取分支由 `RuleUpdate.cacheSource` 的 `when (type)` 处理（type 2 = ReplaceRule，
/// 见 RuleUpdate.kt:73 附近 `2 -> GSON.fromJsonArray<ReplaceRule>`）。
class RuleSub {
  RuleSub({
    required this.id,
    required this.url,
    this.name = '',
    this.enable = true,
    this.lastUpdate = 0,
  });

  final int id;
  final String name;
  final String url;
  final bool enable;

  /// 上次成功拉取的时间戳（毫秒）。0 表示从未拉取。
  final int lastUpdate;

  factory RuleSub.fromJson(Map<String, dynamic> json) => RuleSub(
        id: JsonKit.intOf(json['id'], 0),
        name: JsonKit.stringOr(json['name']),
        url: JsonKit.stringOr(json['url']),
        enable: JsonKit.boolOf(json['enable'], true),
        lastUpdate: JsonKit.intOf(json['lastUpdate'], 0),
      );

  Map<String, dynamic> toJson() => JsonKit.compact({
        'id': id,
        'name': name,
        'url': url,
        'enable': enable,
        'lastUpdate': lastUpdate,
      });

  RuleSub copyWith({
    String? name,
    String? url,
    bool? enable,
    int? lastUpdate,
  }) =>
      RuleSub(
        id: id,
        url: url ?? this.url,
        name: name ?? this.name,
        enable: enable ?? this.enable,
        lastUpdate: lastUpdate ?? this.lastUpdate,
      );
}

/// 拉取器：给定订阅 URL，返回响应体字符串（JSON 数组）。
///
/// 抽离为可注入函数，便于纯 Dart 测试注入假实现；真实实现在
/// [rule_sub_service.dart] 中用 chloris_engine 的 `PackageHttpPort` 完成 GET。
typedef RuleFetcher = Future<String> Function(String url);

/// 替换规则存储抽象。
///
/// 真实实现包装 `replaceRulesProvider`；纯 Dart 测试使用内存实现。
/// 订阅规则与用户规则存放在同一个规则列表里，靠「负 id 区间」区分归属。
abstract class ReplaceRuleStore {
  List<ReplaceRule> current();

  /// 整体替换规则列表（用于合并后落库）。
  Future<void> replaceAll(List<ReplaceRule> rules);
}

/// 订阅元数据 + 每次拉取「内容键 → chloris 规则 id」索引的持久化抽象。
abstract class RuleSubPersistence {
  Future<List<RuleSub>> loadSubs();

  Future<void> saveSubs(List<RuleSub> subs);

  /// 读取某订阅上一次拉取建立的内容键→id 映射。
  Future<Map<String, int>> loadIndex(int subId);

  Future<void> saveIndex(int subId, Map<String, int> index);

  Future<void> deleteIndex(int subId);
}

/// 替换规则订阅同步核心（纯 Dart，可被 `dart run` 直接驱动）。
///
/// 设计要点（去重与幂等，见下）：
/// 1. 每个订阅分配一段「负 id 区间」`-(subId * 100000 + n)`，与用户规则（id 为
///    null 或正数）天然不冲突，且不同订阅之间也不冲突。
/// 2. 每次拉取，对每条规则算出 `contentKey`（legado 的 id + pattern + replacement，
///    对应 RuleUpdate.kt 中 `oldRule == null || pattern 变更 || replacement 变更`
///    的判定），用索引表把 contentKey 稳定映射到同一负 id。
/// 3. 重新拉取时：先按旧索引 id 把「本订阅曾写入的规则」从列表移除，再用同样的
///    contentKey→id 映射写回。内容未变的规则 id 保持不变（原地更新），新增规则分配
///    新负 id，远端删除的规则因不再出现在映射里而被清掉。因此重复拉取是幂等的。
class RuleSubSync {
  RuleSubSync({
    required this.fetcher,
    required this.store,
    required this.persistence,
  });

  final RuleFetcher fetcher;
  final ReplaceRuleStore store;
  final RuleSubPersistence persistence;

  Future<List<RuleSub>> listSubscriptions() => persistence.loadSubs();

  /// 拉取并解析一个订阅 URL 为 ReplaceRule 列表。
  ///
  /// 与 legado 一致：GET → JSON 数组（RuleUpdate.kt 用
  /// `GSON.fromJsonArray<ReplaceRule>`）。额外兼容 `{ "key": [...] }` 包裹格式，
  /// 以便对接不同来源。无效规则（pattern 为空，见 [ReplaceRule.isValid]）会被过滤。
  Future<List<ReplaceRule>> _fetchRules(String url) async {
    final body = await fetcher(url);
    final decoded = jsonDecode(body);
    final List<dynamic> rawList;
    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map) {
      rawList = decoded.values
          .whereType<List>()
          .firstWhere((l) => l.isNotEmpty, orElse: () => const []);
    } else {
      rawList = const [];
    }
    return ReplaceRule.listFromJson(rawList)
        .where((r) => r.isValid)
        .toList();
  }

  /// 内容键：用于判断「同一条规则」是否变化（legado 按 id + pattern + replacement）。
  String _contentKey(ReplaceRule r) =>
      '${r.id ?? ''}::${r.pattern}::${r.replacement}';

  ReplaceRule _withId(ReplaceRule r, int id) => ReplaceRule(
        id: id,
        name: r.name,
        group: r.group,
        pattern: r.pattern,
        replacement: r.replacement,
        scope: r.scope,
        scopeTitle: r.scopeTitle,
        scopeContent: r.scopeContent,
        excludeScope: r.excludeScope,
        isEnabled: r.isEnabled,
        isRegex: r.isRegex,
        timeoutMillisecond: r.timeoutMillisecond,
        order: r.order,
      );

  RuleSub? _find(List<RuleSub> subs, int id) {
    for (final s in subs) {
      if (s.id == id) return s;
    }
    return null;
  }

  int _nextSubId(List<RuleSub> subs) {
    var max = 0;
    for (final s in subs) {
      if (s.id > max) max = s.id;
    }
    return max + 1;
  }

  /// 新增订阅（按 url 去重，不重复创建），并立即拉取一次。
  Future<RuleSub> addSubscription(String url, {String? name}) async {
    final subs = await persistence.loadSubs();
    for (final s in subs) {
      if (s.url == url) {
        await refresh(s.id);
        return s;
      }
    }
    final id = _nextSubId(subs);
    final sub = RuleSub(
      id: id,
      url: url,
      name: name ?? _guessName(url),
      enable: true,
      lastUpdate: 0,
    );
    final next = [...subs, sub];
    await persistence.saveSubs(next);
    await refresh(sub.id);
    return sub;
  }

  String _guessName(String url) {
    try {
      final uri = Uri.parse(url);
      final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      return seg.isNotEmpty ? seg.last : url;
    } catch (_) {
      return url;
    }
  }

  /// 刷新单个订阅：拉取 → 合并（按索引去重、幂等）→ 更新 lastUpdate 与索引。
  ///
  /// 返回本次写入的规则条数。
  Future<int> refresh(int subId) async {
    final subs = await persistence.loadSubs();
    final sub = _find(subs, subId);
    if (sub == null) return 0;

    final fetched = await _fetchRules(sub.url);
    final current = store.current();
    final index = await persistence.loadIndex(subId);
    final oldIds = Set<int>.from(index.values);

    final newIndex = <String, int>{};
    final newRules = <ReplaceRule>[];
    var counter = oldIds.length;
    int nextId() {
      // 在负 id 区间里找一个未占用的值。
      while (true) {
        final candidate = -(subId * 100000 + counter++);
        if (!oldIds.contains(candidate)) return candidate;
      }
    }

    for (final r in fetched) {
      final key = _contentKey(r);
      final id = index[key] ?? newIndex[key] ?? nextId();
      newIndex[key] = id;
      newRules.add(_withId(r, id));
    }

    // 保留「非本订阅」的规则（用户规则 + 其它订阅规则），追加本订阅新规则。
    final kept = current.where((r) => !oldIds.contains(r.id)).toList();
    final next = [...kept, ...newRules];
    await store.replaceAll(next);

    final updatedSub = sub.copyWith(lastUpdate: _now());
    final newSubs = subs.map((s) => s.id == subId ? updatedSub : s).toList();
    await persistence.saveSubs(newSubs);
    await persistence.saveIndex(subId, newIndex);
    return newRules.length;
  }

  /// 刷新全部订阅。默认只刷新 enable 的；[onlyEnabled]=false 时刷新全部。
  Future<int> refreshAll({bool onlyEnabled = true}) async {
    final subs = await persistence.loadSubs();
    var total = 0;
    for (final s in subs) {
      if (onlyEnabled && !s.enable) continue;
      total += await refresh(s.id);
    }
    return total;
  }

  /// 删除订阅：移除其写入的所有规则、删除索引、从订阅列表移除。
  Future<void> removeSubscription(int subId) async {
    final subs = await persistence.loadSubs();
    if (_find(subs, subId) == null) return;
    final index = await persistence.loadIndex(subId);
    final oldIds = Set<int>.from(index.values);
    final current = store.current();
    final kept = current.where((r) => !oldIds.contains(r.id)).toList();
    await store.replaceAll(kept);
    await persistence.deleteIndex(subId);
    await persistence.saveSubs(subs.where((s) => s.id != subId).toList());
  }

  /// 切换订阅启用状态。
  Future<void> setEnabled(int subId, bool enable) async {
    final subs = await persistence.loadSubs();
    final sub = _find(subs, subId);
    if (sub == null) return;
    final newSubs = subs
        .map((s) => s.id == subId ? s.copyWith(enable: enable) : s)
        .toList();
    await persistence.saveSubs(newSubs);
  }

  int _now() => DateTime.now().millisecondsSinceEpoch;
}

/// 纯 Dart 测试用：内存替换规则存储。
class InMemoryReplaceRuleStore implements ReplaceRuleStore {
  List<ReplaceRule> _rules = const [];

  List<ReplaceRule> get rules => _rules;

  @override
  List<ReplaceRule> current() => _rules;

  @override
  Future<void> replaceAll(List<ReplaceRule> rules) async {
    _rules = [...rules];
  }
}

/// 纯 Dart 测试用：内存订阅持久化。
class InMemoryRuleSubPersistence implements RuleSubPersistence {
  List<RuleSub> subs = const [];
  final Map<int, Map<String, int>> indexes = {};

  @override
  Future<List<RuleSub>> loadSubs() async => [...subs];

  @override
  Future<void> saveSubs(List<RuleSub> s) async => subs = [...s];

  @override
  Future<Map<String, int>> loadIndex(int subId) async =>
      Map.from(indexes[subId] ?? {});

  @override
  Future<void> saveIndex(int subId, Map<String, int> index) async =>
      indexes[subId] = Map.from(index);

  @override
  Future<void> deleteIndex(int subId) async => indexes.remove(subId);
}
