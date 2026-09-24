import 'dart:convert';

import 'rule_analyzer.dart';
import 'rule_cache.dart';

class AnalyzeByJsonPath {
  AnalyzeByJsonPath(Object doc) : root = _normalize(doc);

  final dynamic root;

  static dynamic _normalize(Object doc) {
    if (doc is String) {
      final s = doc.trim();
      if (s.isEmpty) return null;
      try {
        return jsonDecode(s);
      } catch (_) {
        return doc;
      }
    }
    return doc;
  }

  List<dynamic> getList(String rule) {
    if (rule.isEmpty) return root == null ? [] : [root];
    final analyzer = RuleAnalyzer(rule);
    final parts = analyzer.splitRule(['&&', '||', '%%']);
    final groups = <List<dynamic>>[];
    for (final part in parts) {
      var found = _read(root, part);
      if (found.length == 1 && found.first is List) {
        found = List<dynamic>.from(found.first as List);
      }
      groups.add(found);
      if (found.isNotEmpty && analyzer.elementsType == '||') break;
    }
    if (groups.isEmpty) return [];
    if (analyzer.elementsType == '||') {
      for (final g in groups) {
        if (g.isNotEmpty) return g;
      }
      return [];
    }
    if (analyzer.elementsType == '&&') {
      return groups.expand((g) => g).toList();
    }
    if (analyzer.elementsType == '%%' && groups.first.isNotEmpty) {
      final out = <dynamic>[];
      // Legado indexes the first result list; extra values from later rules
      // are intentionally ignored for `%%` alignment.
      final max = groups.first.length;
      for (var i = 0; i < max; i++) {
        for (final g in groups) {
          if (i < g.length) out.add(g[i]);
        }
      }
      return out;
    }
    return groups.expand((g) => g).toList();
  }

  dynamic getObject(String rule) {
    final list = _read(root, rule);
    return list.isEmpty ? null : list.first;
  }

  String getString(String rule) {
    if (rule.isEmpty) return '';
    final analyzer = RuleAnalyzer(rule, true);
    final parts = analyzer.splitRule(['&&', '||']);
    if (parts.length <= 1) {
      // Legado accepts `{$.path}` as an embedded JSONPath expression.  It is
      // distinct from the `{{...}}` interpolation handled by AnalyzeRule and
      // must be expanded before attempting to read the literal braces.
      final embedded = _expandEmbedded(rule);
      if (embedded != rule) return embedded;
    }
    final list = getStringList(rule);
    return list.join('\n');
  }

  List<String> getStringList(String rule) {
    if (rule.isEmpty) return [];
    final analyzer = RuleAnalyzer(rule);
    final parts = analyzer.splitRule(['&&', '||', '%%']);
    if (parts.length <= 1) {
      final embedded = _expandEmbedded(rule);
      if (embedded != rule) return [embedded];
      return _stringify(_read(root, rule));
    }
    final groups = <List<String>>[];
    for (final part in parts) {
      final values = getStringList(part);
      groups.add(values);
      if (values.isNotEmpty && analyzer.elementsType == '||') break;
    }
    if (groups.isEmpty) return [];
    if (analyzer.elementsType == '||') {
      for (final g in groups) {
        if (g.isNotEmpty) return g;
      }
      return [];
    }
    if (analyzer.elementsType == '%%' && groups.first.isNotEmpty) {
      final out = <String>[];
      final max = groups.first.length;
      for (var i = 0; i < max; i++) {
        for (final g in groups) {
          if (i < g.length) out.add(g[i]);
        }
      }
      return out;
    }
    return groups.expand((g) => g).toList();
  }

  /// Expand balanced `{$.foo}`/`{$['foo']}` fragments.  The Android parser
  /// uses a code-balanced scanner rather than a non-greedy regex so object
  /// literals and quoted braces do not truncate the embedded rule.
  String _expandEmbedded(String input) {
    if (input.isEmpty) return input;
    final out = StringBuffer();
    var changed = false;
    var i = 0;
    var last = 0;
    while (i + 2 < input.length) {
      if (input[i] != '{' || input[i + 1] != r'$') {
        i++;
        continue;
      }
      final end = RuleAnalyzer.balancedEnd(input, i);
      if (end <= i + 3 || end > input.length || input[end - 1] != '}') {
        i += 2;
        continue;
      }
      final inner = input.substring(i + 1, end - 1).trim();
      if (!(inner.startsWith(r'$.') ||
          inner.startsWith(r'$[') ||
          inner == r'$')) {
        i = end;
        continue;
      }
      final value = getString(inner);
      if (value.isEmpty) {
        i = end;
        continue;
      }
      out.write(input.substring(last, i));
      out.write(value);
      changed = true;
      last = end;
      i = end;
    }
    if (!changed) return input;
    out.write(input.substring(last));
    return out.toString();
  }

  /// Flatten a path result into strings.
  ///
  /// 对齐 Legado-E `AnalyzeByJSonPath.kt:44-50`：`ctx.read(rule)` 直接返回被选
  /// 中的节点，若该节点本身是数组则 `joinToString("\n")` 逐元素展开。Chloris
  /// 的 `_read` 返回的是「被选中节点」的列表，因此单个数组选择会多包一层
  /// （`[[a, b, c]]`），这里解掉这一层，避免把整个数组 `jsonEncode` 成
  /// `["a","b","c"]`。
  List<String> _stringify(List<dynamic> items) {
    final unwrapped =
        items.length == 1 && items.first is List
        ? List<dynamic>.from(items.first as List)
        : items;
    return unwrapped
        .map((e) {
          if (e == null) return '';
          if (e is String) return e;
          if (e is num || e is bool) return e.toString();
          return jsonEncode(e);
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<dynamic> _read(dynamic data, String path) {
    var p = path.trim();
    if (p.toLowerCase().startsWith('@json:')) p = p.substring(6);
    if (p.startsWith(r'$.') || p.startsWith(r'$[')) {
      p = p.substring(1);
    } else if (p == r'$') {
      return data == null ? [] : [data];
    }
    return _walk(data, p);
  }

  List<dynamic> _walk(dynamic data, String path) {
    if (path.isEmpty) return data == null ? [] : [data];
    if (path.startsWith('..')) {
      final rest = path.substring(2);
      final keyEnd = rest.indexOf(RegExp(r'[\.\[\]]'));
      final key = keyEnd < 0 ? rest : rest.substring(0, keyEnd);
      final after = keyEnd < 0 ? '' : rest.substring(keyEnd);
      final found = <dynamic>[];
      _recursive(data, key, found);
      if (after.isEmpty) return found;
      return found.expand((e) => _walk(e, after)).toList();
    }
    if (path.startsWith('.')) {
      return _walk(data, path.substring(1));
    }
    if (path.startsWith('[')) {
      final close = _findClosing(path, 0, '[', ']');
      if (close < 0) return [];
      final inside = path.substring(1, close);
      final rest = path.substring(close + 1);
      final selected = _index(data, inside);
      if (rest.isEmpty) return selected;
      return selected.expand((e) => _walk(e, rest)).toList();
    }
    final next = path.indexOf(RegExp(r'[\.\[\]]'));
    final key = next < 0 ? path : path.substring(0, next);
    final rest = next < 0 ? '' : path.substring(next);
    // Jayway function postfix on the current node, e.g. `$.chapters.length()`
    // or `$.items.first()`. `_walk` has already descended to [data], so the
    // function applies to that node rather than to the selection list.
    final fn = _parseFunctionCall(key);
    if (fn != null) {
      final applied = _applyJsonFunction(fn, data);
      if (rest.isEmpty) return applied;
      return applied.expand((e) => _walk(e, rest)).toList();
    }
    final child = _child(data, key);
    if (rest.isEmpty) return child;
    return child.expand((e) => _walk(e, rest)).toList();
  }

  /// Locate a matching bracket while respecting quoted strings and nested
  /// filter expressions.  `indexOf(']')` truncates rules such as
  /// `[?(@.label=="]")]` and is a common source of cross-engine drift.
  int _findClosing(String value, int open, String opener, String closer) {
    if (open < 0 || open >= value.length || value[open] != opener) return -1;
    var depth = 0;
    String? quote;
    for (var i = open; i < value.length; i++) {
      final c = value[i];
      if (quote != null) {
        if (c == quote && !_isEscaped(value, i)) quote = null;
        continue;
      }
      if (c == '"' || c == "'") {
        quote = c;
      } else if (c == opener) {
        depth++;
      } else if (c == closer) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  bool _isEscaped(String value, int index) {
    var count = 0;
    for (var i = index - 1; i >= 0 && value[i] == r'\'; i--) {
      count++;
    }
    return count.isOdd;
  }

  List<dynamic> _child(dynamic data, String key) {
    if (data is List) {
      return data.expand((e) => _child(e, key)).toList();
    }
    if (data is Map) {
      if (key == '*') return data.values.toList();
      if (data.containsKey(key)) return [data[key]];
    }
    return [];
  }

  List<dynamic> _index(dynamic data, String inside) {
    final token = inside.trim();
    if (token.startsWith('?(') && token.endsWith(')')) {
      return _filter(data, token.substring(2, token.length - 1));
    }
    if (token == '*' || token == '?') {
      if (data is List) return List<dynamic>.from(data);
      if (data is Map) return data.values.toList();
      return [];
    }
    if (token.contains(':')) {
      return _slice(data, token);
    }
    if (token.contains(',')) {
      final keys = _splitUnion(token);
      if (data is List) {
        final out = <dynamic>[];
        for (final key in keys) {
          final index = int.tryParse(key);
          if (index == null) continue;
          var i = index;
          if (i < 0) i += data.length;
          if (i >= 0 && i < data.length) out.add(data[i]);
        }
        return out;
      }
      if (data is Map) {
        return [
          for (final key in keys)
            if (data.containsKey(key)) data[key],
        ];
      }
    }
    if (data is List) {
      final i = int.tryParse(token);
      if (i != null) {
        var idx = i;
        if (idx < 0) idx += data.length;
        if (idx >= 0 && idx < data.length) return [data[idx]];
        return [];
      }
    }
    final key = _unquote(token);
    if (data is Map && data.containsKey(key)) {
      return [data[key]];
    }
    return [];
  }

  List<String> _splitUnion(String token) {
    final out = <String>[];
    var start = 0;
    String? quote;
    for (var i = 0; i < token.length; i++) {
      final c = token[i];
      if (quote != null) {
        if (c == quote && !_isEscaped(token, i)) quote = null;
      } else if (c == "'" || c == '"') {
        quote = c;
      } else if (c == ',') {
        final part = _unquote(token.substring(start, i).trim());
        if (part.isNotEmpty) out.add(part);
        start = i + 1;
      }
    }
    final tail = _unquote(token.substring(start).trim());
    if (tail.isNotEmpty) out.add(tail);
    return out;
  }

  String _unquote(String value) {
    final t = value.trim();
    if (t.length >= 2 &&
        ((t.startsWith("'") && t.endsWith("'")) ||
            (t.startsWith('"') && t.endsWith('"')))) {
      return t.substring(1, t.length - 1);
    }
    return t;
  }

  List<dynamic> _slice(dynamic data, String token) {
    if (data is! List) return [];
    final bits = token.split(':');
    if (bits.length > 3) return [];
    var step = bits.length > 2 && bits[2].trim().isNotEmpty
        ? int.tryParse(bits[2].trim()) ?? 1
        : 1;
    if (step == 0) step = 1;
    int? parse(String value) =>
        value.trim().isEmpty ? null : int.tryParse(value.trim());
    var start = parse(bits[0]);
    var end = bits.length > 1 ? parse(bits[1]) : null;
    if (step > 0) {
      start ??= 0;
      end ??= data.length;
      if (start < 0) start += data.length;
      if (end < 0) end += data.length;
      start = start.clamp(0, data.length);
      end = end.clamp(0, data.length);
      final out = <dynamic>[];
      for (var i = start; i < end; i += step) {
        out.add(data[i]);
      }
      return out;
    }
    start ??= data.length - 1;
    final hasExplicitEnd = bits.length > 1 && bits[1].trim().isNotEmpty;
    end ??= -1;
    if (start < 0) start += data.length;
    if (end < 0 && hasExplicitEnd) end += data.length;
    start = start.clamp(-1, data.length - 1);
    end = end.clamp(-1, data.length - 1);
    final out = <dynamic>[];
    for (var i = start; i > end; i += step) {
      if (i >= 0 && i < data.length) out.add(data[i]);
    }
    return out;
  }

  List<dynamic> _filter(dynamic data, String expr) {
    final items = data is List
        ? List<dynamic>.from(data)
        : data is Map
        ? [data]
        : <dynamic>[];
    return items.where((e) => _matchFilter(e, expr)).toList();
  }

  bool _matchFilter(dynamic item, String expr) {
    var e = expr.trim();
    e = _stripOuterParens(e);
    final orParts = _splitFilterOperator(e, '||');
    if (orParts.length > 1) {
      return orParts.any((part) => _matchFilter(item, part));
    }
    final andParts = _splitFilterOperator(e, '&&');
    if (andParts.length > 1) {
      return andParts.every((part) => _matchFilter(item, part));
    }
    if (e.startsWith('!') && !e.startsWith('!=')) {
      return !_matchFilter(item, e.substring(1));
    }
    final m = RegExp(
      r"^(?:@|\$)\.([A-Za-z0-9_.-]+)(\.length)?\s*(==|!=|>=|<=|>|<|=~)\s*(.+)$",
    ).firstMatch(e);
    final contains = RegExp(
      r'''^contains\(\s*@\.([A-Za-z0-9_.-]+)\s*,\s*(['"])(.*?)\2\s*\)$''',
    ).firstMatch(e);
    if (contains != null) {
      final value = _field(item, contains.group(1)!);
      return value?.toString().contains(contains.group(3)!) ?? false;
    }
    final textOp = RegExp(
      r'''^(?:@|\$)\.([A-Za-z0-9_.-]+)\s+(contains|startsWith|endsWith)\s+(['"])(.*?)\3$''',
    ).firstMatch(e);
    if (textOp != null) {
      final value = _field(item, textOp.group(1)!)?.toString() ?? '';
      final needle = textOp.group(4)!;
      switch (textOp.group(2)) {
        case 'contains':
          return value.contains(needle);
        case 'startsWith':
          return value.startsWith(needle);
        case 'endsWith':
          return value.endsWith(needle);
      }
    }
    if (m == null) {
      if (e.startsWith('@.') || e.startsWith(r'$.')) {
        final v = _field(item, e.substring(2));
        return _truthy(v);
      }
      return false;
    }
    var fieldName = m.group(1)!;
    final useLength = m.group(2) != null || fieldName.endsWith('.length');
    if (fieldName.endsWith('.length')) {
      fieldName = fieldName.substring(0, fieldName.length - 7);
    }
    final rawLeft = _field(item, fieldName);
    final left = useLength ? _lengthOf(rawLeft) : rawLeft;
    final op = m.group(3)!;
    final raw = m.group(4)!.trim();
    final right = _literal(raw);
    switch (op) {
      case '==':
        return _asString(left) == _asString(right);
      case '!=':
        return _asString(left) != _asString(right);
      case '>':
        return _asNum(left) > _asNum(right);
      case '<':
        return _asNum(left) < _asNum(right);
      case '>=':
        return _asNum(left) >= _asNum(right);
      case '<=':
        return _asNum(left) <= _asNum(right);
      case '=~':
        try {
          final pattern = right is RegExp ? right : RegExp(_asString(right));
          return pattern.hasMatch(_asString(left));
        } catch (_) {
          // A malformed source rule must reject this item, not abort the
          // whole catalog/search extraction pass.
          return false;
        }
      default:
        return false;
    }
  }

  String _stripOuterParens(String value) {
    var out = value;
    while (out.startsWith('(') && out.endsWith(')')) {
      var depth = 0;
      String? quote;
      var balanced = true;
      for (var i = 0; i < out.length; i++) {
        final c = out[i];
        if (quote != null) {
          if (c == quote && !_isEscaped(out, i)) quote = null;
          continue;
        }
        if (c == "'" || c == '"') {
          quote = c;
        } else if (c == '(') {
          depth++;
        } else if (c == ')') {
          depth--;
          if (depth == 0 && i != out.length - 1) {
            balanced = false;
            break;
          }
        }
      }
      if (!balanced || depth != 0) break;
      out = out.substring(1, out.length - 1).trim();
    }
    return out;
  }

  List<String> _splitFilterOperator(String value, String operator) {
    final out = <String>[];
    var start = 0;
    var depth = 0;
    String? quote;
    for (var i = 0; i <= value.length - operator.length; i++) {
      final c = value[i];
      if (quote != null) {
        if (c == quote && !_isEscaped(value, i)) quote = null;
        continue;
      }
      if (c == "'" || c == '"') {
        quote = c;
        continue;
      }
      if (c == '(' || c == '[') {
        depth++;
        continue;
      }
      if (c == ')' || c == ']') {
        if (depth > 0) depth--;
        continue;
      }
      if (depth == 0 && value.startsWith(operator, i)) {
        out.add(value.substring(start, i).trim());
        i += operator.length - 1;
        start = i + 1;
      }
    }
    if (out.isEmpty) return [value];
    out.add(value.substring(start).trim());
    return out;
  }

  bool _truthy(dynamic value) {
    if (value is List) return value.isNotEmpty;
    return value != null && value != false && value != '' && value != 0;
  }

  int _lengthOf(dynamic value) {
    return switch (value) {
      String v => v.length,
      List v => v.length,
      Map v => v.length,
      _ => 0,
    };
  }

  dynamic _field(dynamic item, String key) {
    dynamic current = item;
    final parts = RegExp(r'''([A-Za-z0-9_-]+)|\[\s*(['"]?)([^\]'"]+)\2\s*\]''')
        .allMatches(key)
        .map((m) => m.group(1) ?? m.group(3) ?? '')
        .where((part) => part.isNotEmpty);
    for (final part in parts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else if (current is List) {
        final index = int.tryParse(part);
        if (index == null || index < 0 || index >= current.length) return null;
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }

  dynamic _literal(String raw) {
    if ((raw.startsWith("'") && raw.endsWith("'")) ||
        (raw.startsWith('"') && raw.endsWith('"'))) {
      return raw.substring(1, raw.length - 1);
    }
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    if (raw == 'null') return null;
    if (raw.startsWith('/') && raw.lastIndexOf('/') > 0) {
      final end = raw.lastIndexOf('/');
      final pattern = raw.substring(1, end);
      final flags = raw.substring(end + 1);
      // The pattern is fixed by the rule's filter literal; compile it once and
      // reuse it.  A malformed pattern yields `null`, which the =~ branch keeps
      // as literal text (identical to the previous try/catch fallback).
      final re = RuleCompileCache.regex(
        pattern,
        caseSensitive: !flags.contains('i'),
      );
      if (re != null) return re;
      // Keep malformed regex literals as text so the =~ branch can reject
      // them safely instead of aborting the complete filter evaluation.
      return raw;
    }
    return num.tryParse(raw) ?? raw;
  }

  String _asString(dynamic v) => v?.toString() ?? '';

  num _asNum(dynamic v) {
    if (v is num) return v;
    return num.tryParse(v?.toString() ?? '') ?? 0;
  }

  num? _numOrNull(dynamic v) {
    if (v is num) return v;
    if (v is bool) return v ? 1 : 0;
    if (v is String) return num.tryParse(v);
    return null;
  }

  /// Parse a single `name(arg, arg)` call.  Returns `null` for a plain key or a
  /// comparison, so it is only used to recognise genuine Jayway-style function
  /// postfixes (e.g. `$.a.length()`).
  _JpFn? _parseFunctionCall(String expr) {
    final m = RegExp(r'^([A-Za-z_][\w-]*)\s*\((.*)\)$').firstMatch(expr.trim());
    if (m == null) return null;
    final argsRaw = m.group(2)!.trim();
    return _JpFn(m.group(1)!, argsRaw.isEmpty ? const [] : _splitJpArgs(argsRaw));
  }

  List<String> _splitJpArgs(String s) {
    final out = <String>[];
    var start = 0;
    var depth = 0;
    String? quote;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (quote != null) {
        if (c == quote && !_isEscaped(s, i)) quote = null;
        continue;
      }
      if (c == "'" || c == '"') {
        quote = c;
      } else if (c == '(' || c == '[') {
        depth++;
      } else if (c == ')' || c == ']') {
        if (depth > 0) depth--;
      } else if (c == ',' && depth == 0) {
        out.add(s.substring(start, i).trim());
        start = i + 1;
      }
    }
    out.add(s.substring(start).trim());
    return out;
  }

  /// The receiver of a Jayway function postfix.  `_walk` reaches the function
  /// token one node at a time, so [node] is the value the function applies to
  /// (an array, an object, or a scalar), not the enclosing selection list.
  List<dynamic> _fnContext(dynamic node) {
    if (node is List) return List<dynamic>.from(node);
    if (node == null) return const [];
    return [node];
  }

  /// Apply a Jayway function to [node].
  /// 对齐 Legado-E AnalyzeByJSonPath.kt（Jayway 2.10.0 函数扩展）。
  /// Legado 的返回值最终会被 `toString()` 化，Chloris 保留原生数值/列表，
  /// 由 `getString` / `_stringify` 统一转字符串，结果内容一致。
  List<dynamic> _applyJsonFunction(_JpFn fn, dynamic node) {
    switch (fn.name) {
      case 'length':
        // Jayway: the size of the selected array/object/string.
        if (node is Map) return [node.length];
        if (node is List) return [node.length];
        if (node is String) return [node.length];
        return [0];
      case 'first':
        if (node is List) return node.isEmpty ? const [null] : [node.first];
        return node == null ? const [null] : [node];
      case 'last':
        if (node is List) return node.isEmpty ? const [null] : [node.last];
        return node == null ? const [null] : [node];
      case 'sum':
        final nums = _fnContext(node).map(_numOrNull).whereType<num>();
        return [nums.fold(0.0, (a, b) => a + b)];
      case 'min':
        // Jayway 的 min()/max() 返回 Double，`toString()` 形如 "1.0"（判题进程
        // 实测 `$.a.min()` 于 [1,2,3,4] → "1.0"）。此处同样返回 double 以对齐。
        final nums = _fnContext(node).map(_numOrNull).whereType<num>().toList();
        if (nums.isEmpty) return const [null];
        return [nums.reduce((a, b) => a <= b ? a : b).toDouble()];
      case 'max':
        final nums = _fnContext(node).map(_numOrNull).whereType<num>().toList();
        if (nums.isEmpty) return const [null];
        return [nums.reduce((a, b) => a >= b ? a : b).toDouble()];
      case 'avg':
        final nums = _fnContext(node).map(_numOrNull).whereType<num>().toList();
        if (nums.isEmpty) return const [null];
        return [nums.fold(0.0, (a, b) => a + b) / nums.length];
      case 'keys':
        if (node is Map) return List<dynamic>.from(node.keys);
        final maps = _fnContext(node).whereType<Map>().toList();
        if (maps.isEmpty) return const [null];
        if (maps.length == 1) return List<dynamic>.from(maps.first.keys);
        final keys = <dynamic>{};
        for (final m in maps) {
          keys.addAll(m.keys);
        }
        return keys.toList();
      default:
        // 未知函数：保持空结果，不影响其它后端（对齐 Legado-E 能力缺口）。
        return const [null];
    }
  }

  void _recursive(dynamic data, String key, List<dynamic> out) {
    // `$..*`：递归通配，收集全部值（对齐 Jayway/legado `AnalyzeByJSonPath.kt:18`）。
    final wildcard = key == '*';
    if (data is Map) {
      data.forEach((k, v) {
        if (wildcard || k.toString() == key) out.add(v);
        _recursive(v, key, out);
      });
    } else if (data is List) {
      for (final e in data) {
        if (wildcard) out.add(e);
        _recursive(e, key, out);
      }
    }
  }
}

/// A parsed Jayway-style function postfix: `name(arg, arg)`.
class _JpFn {
  const _JpFn(this.name, this.args);

  final String name;
  final List<String> args;

  @override
  String toString() => '$name(${args.join(', ')})';
}
