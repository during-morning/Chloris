import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/persist/kv_settings.dart';

import 'rules_provider.dart';

final dictRulesController =
    NotifierProvider<DictRulesNotifier, List<Map<String, dynamic>>>(
  DictRulesNotifier.new,
);

class DictRulesNotifier extends Notifier<List<Map<String, dynamic>>> {
  bool _loaded = false;

  @override
  List<Map<String, dynamic>> build() => const [];

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await KvSettings.ready();
    final raw = prefs.getString('dictRules');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        state = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loaded = true;
        return;
      } catch (_) {}
    }
    final defaults = await ref.read(defaultDictRulesProvider.future);
    state = [...defaults];
    _loaded = true;
  }

  Future<void> _persist() async {
    final prefs = await KvSettings.ready();
    await prefs.setString('dictRules', jsonEncode(state));
  }

  void update(int index, Map<String, dynamic> rule) {
    final next = [...state];
    next[index] = rule;
    state = next;
    _persist();
  }

  void addAll(Iterable<Map<String, dynamic>> rules) {
    state = [...state, ...rules];
    _persist();
  }
}
