import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';
import '../../core/persist/kv_settings.dart';

import 'rules_provider.dart';

final tocRulesController =
    NotifierProvider<TocRulesNotifier, List<TxtTocRule>>(
  TocRulesNotifier.new,
);

class TocRulesNotifier extends Notifier<List<TxtTocRule>> {
  bool _loaded = false;

  @override
  List<TxtTocRule> build() => const [];

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await KvSettings.ready();
    final raw = prefs.getString('tocRules');
    if (raw != null && raw.isNotEmpty) {
      try {
        state = TxtTocRule.listFromJson(jsonDecode(raw));
        _loaded = true;
        return;
      } catch (_) {}
    }
    final defaults = await ref.read(defaultTxtTocRulesProvider.future);
    state = [...defaults];
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await KvSettings.ready();
    await prefs.setString(
      'tocRules',
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  void update(int index, TxtTocRule rule) {
    final next = [...state];
    next[index] = rule;
    state = next;
    _persist();
  }

  void addAll(Iterable<TxtTocRule> rules) {
    state = [...state, ...rules];
    _persist();
  }
}
