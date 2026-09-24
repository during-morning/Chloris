import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chloris_engine/chloris_engine.dart';

Future<List<T>> _load<T>(String path, List<T> Function(dynamic) parse) async {
  final raw = await rootBundle.loadString(path);
  return parse(jsonDecode(raw));
}

/// 默认净化替换规则。
final defaultReplaceRulesProvider =
    FutureProvider<List<ReplaceRule>>((ref) async {
  return _load('assets/sources/default_replace_rules.json', ReplaceRule.listFromJson);
});

/// 默认字典规则（原始 JSON 项）。
final defaultDictRulesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return _load<Map<String, dynamic>>(
    'assets/sources/default_dict_rules.json',
    (raw) => (raw as List).cast<Map<String, dynamic>>(),
  );
});

/// 默认 TXT 目录规则。
final defaultTxtTocRulesProvider =
    FutureProvider<List<TxtTocRule>>((ref) async {
  return _load('assets/sources/default_txt_toc_rules.json', TxtTocRule.listFromJson);
});
