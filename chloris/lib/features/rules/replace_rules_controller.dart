import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import '../../core/persist/app_db.dart';
import '../../core/persist/kv_settings.dart';
import '../../core/persist/persist_queue.dart';
import '../../data/database/app_database.dart' hide ReplaceRule;

import 'rules_provider.dart';

final replaceRulesProvider =
    NotifierProvider<ReplaceRulesNotifier, List<ReplaceRule>>(
  ReplaceRulesNotifier.new,
);

class ReplaceRulesNotifier extends Notifier<List<ReplaceRule>> {
  bool _loaded = false;

  @override
  List<ReplaceRule> build() => const [];

  /// 当前规则列表快照（供订阅服务在不触碰 protected [state] 的前提下读取）。
  List<ReplaceRule> snapshot() => state;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await KvSettings.ready();
    final raw = prefs.getString('replaceRules');
    if (raw != null && raw.isNotEmpty) {
      try {
        state = ReplaceRule.listFromJson(jsonDecode(raw));
        _loaded = true;
        return;
      } catch (_) {}
    }
    final defaults = await ref.read(defaultReplaceRulesProvider.future);
    state = [...defaults];
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await KvSettings.ready();
    await prefs.setString(
      'replaceRules',
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
    // KV stays authoritative during the migration window and the table is its
    // mirror. Before this the `ReplaceRules` table was never written at all,
    // so it was dead and no scope query could be answered from SQL.
    PersistQueue.instance.schedule('replaceRules.drift', _persistDrift);
  }

  Future<void> _persistDrift() async {
    final d = await AppDb.open();
    if (d == null) return;
    final snapshot = [...state];
    try {
      await d.transaction(() async {
        await d.delete(d.replaceRules).go();
        for (final r in snapshot) {
          await d.into(d.replaceRules).insert(
                ReplaceRulesCompanion.insert(
                  name: r.name,
                  pattern: r.pattern,
                  replacement: r.replacement,
                  groupName: Value(r.group),
                  scope: Value(r.scope),
                  scopeTitle: Value(r.scopeTitle),
                  scopeContent: Value(r.scopeContent),
                  excludeScope: Value(r.excludeScope),
                  enabled: Value(r.isEnabled),
                  isRegex: Value(r.isRegex),
                  timeoutMillisecond: Value(r.timeoutMillisecond),
                  orderValue: Value(r.order ?? 0),
                ),
              );
        }
      });
    } catch (_) {}
  }

  void update(int index, ReplaceRule rule) {
    final next = [...state];
    next[index] = rule;
    state = next;
    _persist();
  }

  void add(ReplaceRule rule) {
    state = [...state, rule];
    _persist();
  }

  /// 整体替换规则列表。订阅合并时用于把「用户规则 + 各订阅规则」一次性落库。
  void replaceAll(List<ReplaceRule> rules) {
    state = [...rules];
    _persist();
  }

  void addAll(Iterable<ReplaceRule> rules) {
    state = [...state, ...rules];
    _persist();
  }

  void remove(int index) {
    state = [...state]..removeAt(index);
    _persist();
  }
}
