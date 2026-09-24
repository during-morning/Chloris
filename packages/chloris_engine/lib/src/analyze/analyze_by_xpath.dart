import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../debug/debug_log.dart';
import 'rule_analyzer.dart';
import 'rule_cache.dart';

/// Sentinel returned by the value-expression evaluator when an expression
/// cannot be interpreted by the Chloris XPath subset.  It lets [_XpStep._matches]
/// fall through to the legacy predicate branches and, failing those, emit a
/// visible [DebugLog] warning instead of silently returning an empty result
/// (the old `return false` at the end of [_matches] which masked unsupported
/// functions as "no match").
/// 对齐 Legado-E AnalyzeByXPath.kt:99-101 —— Legado 对不支持的函数抛异常，
/// Chloris 在此改为「可见告警 + 空匹配」，符合本计划 §12-P0-3「失败要可见」。
const Object _xpathUnrecognized = Object();

class _FnCall {
  const _FnCall(this.name, this.args);
  final String name;
  final List<String> args;
}

class _Cmp {
  const _Cmp(this.lhs, this.op, this.rhs);
  final String lhs;
  final String op;
  final String rhs;
}

/// Parse `name(arg, arg)` at the top level.  Returns `null` for anything that is
/// not a single function call (e.g. a child name or a comparison), so callers
/// can keep the legacy predicate branches authoritative.
_FnCall? _parseXPathFunctionCall(String expr) {
  final m = RegExp(r'^([A-Za-z_][\w-]*)\s*\((.*)\)$').firstMatch(expr.trim());
  if (m == null) return null;
  final argsRaw = m.group(2)!.trim();
  return _FnCall(m.group(1)!, argsRaw.isEmpty ? const [] : _splitXPathArgs(argsRaw));
}

/// Split comma-separated function arguments while respecting quotes and nested
/// parens/brackets so an argument like `concat(text(),'a,b')` is not split.
List<String> _splitXPathArgs(String s) {
  final out = <String>[];
  var start = 0;
  var depth = 0;
  String? quote;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (quote != null) {
      if (c == quote && !_isXpathEscaped(s, i)) quote = null;
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

bool _isXpathEscaped(String value, int index) {
  var slashes = 0;
  for (var i = index - 1; i >= 0 && value[i] == r'\'; i--) slashes++;
  return slashes.isOdd;
}

/// Subset of XPath used by legado book sources.
/// Supports child / descendant / parent / following-sibling /
/// preceding-sibling, `@attr`, `text()`, positional predicates, attribute and
/// text functions, and simple `and`/`or` predicate expressions.
class AnalyzeByXPath {
  AnalyzeByXPath(Object doc) : root = _asElement(doc);

  final Element root;

  static Element _asElement(Object doc) {
    if (doc is Element) return doc;
    if (doc is Document) return doc.documentElement ?? Element.tag('html');
    return html_parser.parse(doc.toString()).documentElement ??
        Element.tag('html');
  }

  List<Element> getElements(String rule) {
    if (rule.isEmpty) return [];
    final analyzer = RuleAnalyzer(rule);
    final parts = analyzer.splitRule(['&&', '||', '%%']);
    if (parts.length <= 1) return _select(root, rule);
    final groups = <List<Element>>[];
    for (final part in parts) {
      final els = getElements(part);
      groups.add(els);
      if (els.isNotEmpty && analyzer.elementsType == '||') break;
    }
    return _combine(groups, analyzer.elementsType);
  }

  /// 对齐 legado：多命中纯 `\n` 连接，不做 Chloris 旧式的包含折叠。
  String getString(String rule) => getStringList(rule).join('\n');

  List<String> getStringList(String rule) {
    if (rule.isEmpty) return [];
    final analyzer = RuleAnalyzer(rule);
    final parts = analyzer.splitRule(['&&', '||', '%%']);
    if (parts.length <= 1) return _stringOne(rule);
    final groups = <List<String>>[];
    for (final part in parts) {
      final values = getStringList(part);
      groups.add(values);
      if (values.isNotEmpty && analyzer.elementsType == '||') break;
    }
    return _combine(groups, analyzer.elementsType);
  }

  List<String> _stringOne(String rule) {
    final path = rule.trim();
    // 路径级函数。Legado-E 经 jsoupXpath 2.5.3 只对下列形态给出确定结果
    // （由 tool/legado_oracle 判题进程逐条复核）：
    //   count(//nosuch) → "0"、count(//t) → "2"、sum(//t) → "3"（纯数字）
    // 其余路径级函数在 jsoupXpath 上要么抛 NoSuchFunctionException
    // （string / normalize-space / name / local-name / number / min / max），
    // 要么抛 IndexOutOfBoundsException（`substring(//t,2)` 不带长度形参），
    // 因此这里**不**复制——不让 Chloris 长出没有依据的行为。
    final pathFn = _parseXPathFunctionCall(path);
    if (pathFn != null && pathFn.name == 'count') {
      return _evalPathCount(pathFn, path);
    }
    if (pathFn != null) {
      DebugLog.log(
        'XPath',
        '路径级函数 $path 在 Legado-E(jsoupXpath) 上无对应能力，按空结果处理',
        state: -1,
      );
      return const [];
    }
    // 路径末端 text()：对齐 Legado-E（jsoup-xpath）。
    //   //a/text()   -> 子轴文本节点 = 每个选中元素的**直接文本子节点**
    //   //a//text()  -> 后代轴文本节点 = 选中元素下的所有文本节点（按文档序）
    // 二者都**不能**用元素全文 e.text 兜底：<a>pre<b>mid</b>post</a> 的
    // //a/text() 实测为 ["pre","post"]（direct），而 e.text 会得到 "premidpost"。
    // 判题进程实测 //div//text() -> ["one","two"]，故后代轴需遍历全部文本节点。
    if (path.endsWith('//text()')) {
      final base = path.substring(0, path.length - '//text()'.length);
      return _select(root, base)
          .expand(_descendantTextValues)
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    if (path.endsWith('/text()')) {
      final base = path.substring(0, path.length - '/text()'.length);
      return _select(root, base)
          .expand(_directTextValues)
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    // 路径末端 node()：子轴/后代轴的**全部节点**（元素 + 文本）。
    // 字面值取 XPath 规则：文本节点取其文本，元素取其文本内容 —— 与
    // 下面纯元素路径 `e.text.trim()` 的取值口径一致，按文档序返回。
    if (path.endsWith('//node()')) {
      final base = path.substring(0, path.length - '//node()'.length);
      return _select(root, base)
          .expand((e) => _descendantNodeValues(e))
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    if (path.endsWith('/node()')) {
      final base = path.substring(0, path.length - '/node()'.length);
      return _select(root, base)
          .expand((e) => e.nodes.map(_nodeValue))
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    // 路径末端 @attr：属性节点 -> 属性值。命名空间前缀（foo:bar）一并支持。
    final attr = RegExp(r'/@([\w:-]+)$').firstMatch(path);
    if (attr != null) {
      final els = _select(root, path.substring(0, attr.start));
      return els
          .map((e) => e.attributes[attr.group(1)!] ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return _select(
      root,
      path,
    ).map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// 直接文本子节点（子轴 text()）的字符串值。对齐 jsoup-xpath：
  /// `//a/text()` 只取 `<a>` 的**直接**文本子节点，不含其后代元素内的文本。
  static Iterable<String> _directTextValues(Element e) =>
      e.nodes.whereType<Text>().map((t) => t.text.trim());

  /// 所有后代文本节点（后代轴 /text() 递归收集，按文档序）。
  static Iterable<String> _descendantTextValues(Element e) sync* {
    for (final child in e.nodes) {
      if (child is Text) {
        yield child.text.trim();
      } else if (child is Element) {
        yield* _descendantTextValues(child);
      }
    }
  }

  /// 节点的字面值：文本节点取其文本，元素取其聚合文本（与元素路径的
  /// `e.text` 取值口径一致），注释节点取 `data`。
  static String _nodeValue(Node n) {
    if (n is Text) return n.text.trim();
    if (n is Element) return n.text.trim();
    return n.text?.trim() ?? '';
  }

  /// 后代轴 node() 的全部节点（元素 + 文本，按文档序）。
  static Iterable<String> _descendantNodeValues(Element e) sync* {
    for (final child in e.nodes) {
      if (child is Text) {
        yield child.text.trim();
      } else if (child is Element) {
        yield child.text.trim();
        yield* _descendantNodeValues(child);
      }
    }
  }

  /// 路径级 `count(path)`。
  ///
  /// 对齐 Legado-E：jsoupXpath 的 `count()` 返回选中节点数。判题进程实测
  /// `count(//t)` → `2`、`count(//nosuch)` → `0`（**不是**空串），因此这里
  /// 必须返回 `"0"` 而不是空列表，否则「数为 0」和「规则失败」会被混为一谈。
  List<String> _evalPathCount(_FnCall fn, String original) {
    if (fn.args.length != 1) {
      DebugLog.log('XPath', 'count() 形参个数不合法，按空结果处理: $original', state: -1);
      return const [];
    }
    final arg = fn.args.first.trim();
    if (arg.isEmpty) {
      DebugLog.log('XPath', 'count() 缺少路径参数，按空结果处理: $original', state: -1);
      return const [];
    }
    return ['${_select(root, arg).length}'];
  }

  static List<T> _combine<T>(List<List<T>> groups, String type) {
    if (groups.isEmpty) return [];
    if (type == '%%' && groups.first.isNotEmpty) {
      final out = <T>[];
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

  List<Element> _select(Element from, String path) {
    var p = path.trim();
    if (p.toLowerCase().startsWith('@xpath:')) p = p.substring(7);
    final steps = _parseSteps(p);
    var current = <Element>[from];
    for (var stepIndex = 0; stepIndex < steps.length; stepIndex++) {
      final step = steps[stepIndex];
      if (step.axis == _Axis.attribute) continue;
      final next = <Element>[];
      final seen = <Element>{};
      for (final el in current) {
        final collected = <Element>[];
        // XPath `/html` starts at the document element itself. The html
        // package's `children` collection only contains descendants, so add
        // the context node for the first absolute step when it matches.
        if (stepIndex == 0 &&
            (step.axis == _Axis.child || step.axis == _Axis.descendant) &&
            step.matchesTag(el)) {
          collected.add(el);
        }
        collected.addAll(step.collect(el));
        for (final n in step.filter(collected)) {
          if (seen.add(n)) next.add(n);
        }
      }
      current = next;
    }
    return current;
  }

  List<_XpStep> _parseSteps(String path) {
    // The path parse is a pure function of the rule string, but it rescanns the
    // whole path on every `getElements`/`getString` call.  Cache the
    // owner-independent step specs; the per-instance `_XpStep` wrapper (which
    // carries the document owner used only for relative `count()`/`sum()`
    // expressions) is rebuilt cheaply from the spec.
    final specs = _cachedXpStepSpecs(path);
    return [for (final s in specs) _XpStep(s.axis, s.tag, s.predicates, this)];
  }

  static List<_XpStepSpec> _cachedXpStepSpecs(String path) {
    final key = 'xpath:steps:$path';
    final hit = RuleCompileCache.getProduct(key);
    if (hit is List<_XpStepSpec>) return hit;
    final specs = _XpStepSpec.parse(path);
    RuleCompileCache.putProduct(key, specs);
    return specs;
  }
}

/// Owner-independent parse product of an XPath path string.  `_XpStep` wraps
/// this with the owning [AnalyzeByXPath] instance so the cached spec can be
/// shared across documents without coupling the parse to a single instance.
class _XpStepSpec {
  const _XpStepSpec(this.axis, this.tag, this.predicates);

  final _Axis axis;
  final String tag;
  final List<String> predicates;

  static List<_XpStepSpec> parse(String path) {
    final out = <_XpStepSpec>[];
    var i = 0;
    var defaultAxis = _Axis.descendant;
    if (path.startsWith('//')) {
      defaultAxis = _Axis.descendant;
      i = 2;
    } else if (path.startsWith('/')) {
      defaultAxis = _Axis.child;
      i = 1;
    }
    while (i < path.length) {
      if (path.startsWith('//', i)) {
        defaultAxis = _Axis.descendant;
        i += 2;
        continue;
      }
      if (path[i] == '/') {
        defaultAxis = _Axis.child;
        i++;
        continue;
      }
      final start = i;
      var depth = 0;
      var parenDepth = 0;
      String? quote;
      while (i < path.length) {
        final c = path[i];
        if (quote != null) {
          if (c == quote && (i == 0 || path[i - 1] != r'\\')) quote = null;
        } else if (c == "'" || c == '"') {
          quote = c;
        } else if (c == '[') {
          depth++;
        } else if (c == ']') {
          depth--;
        } else if (c == '(') {
          parenDepth++;
        } else if (c == ')') {
          parenDepth--;
        }
        if (c == '/' && depth == 0 && parenDepth == 0 && quote == null) break;
        i++;
      }
      final raw = path.substring(start, i);
      if (raw.isNotEmpty && raw != '.' && !raw.startsWith('@')) {
        out.add(_XpStepSpec.parseOne(raw, defaultAxis));
      }
      defaultAxis = _Axis.child;
    }
    return out;
  }

  static _XpStepSpec parseOne(String raw, _Axis fallback) {
    var s = raw.trim();
    var axis = fallback;
    final sep = s.indexOf('::');
    if (sep > 0) {
      switch (s.substring(0, sep)) {
        case 'child':
          axis = _Axis.child;
          break;
        case 'descendant':
          axis = _Axis.descendant;
          break;
        case 'descendant-or-self':
          axis = _Axis.descendantOrSelf;
          break;
        case 'parent':
          axis = _Axis.parent;
          break;
        case 'ancestor':
          axis = _Axis.ancestor;
          break;
        case 'ancestor-or-self':
          axis = _Axis.ancestorOrSelf;
          break;
        case 'following-sibling':
          axis = _Axis.following;
          break;
        case 'preceding-sibling':
          axis = _Axis.preceding;
          break;
        case 'self':
          axis = _Axis.self;
          break;
        case 'attribute':
          axis = _Axis.attribute;
          break;
      }
      s = s.substring(sep + 2);
    }
    if (s == '..') return const _XpStepSpec(_Axis.parent, '*', []);
    String tag;
    final predicates = <String>[];
    final br = s.indexOf('[');
    if (br >= 0) {
      tag = s.substring(0, br);
      var i = br;
      while (i < s.length) {
        if (s[i] != '[') break;
        final start = i + 1;
        var depth = 1;
        String? quote;
        i++;
        while (i < s.length && depth > 0) {
          final c = s[i];
          if (quote != null) {
            if (c == quote && (i == 0 || s[i - 1] != r'\\')) quote = null;
          } else if (c == "'" || c == '"') {
            quote = c;
          } else if (c == '[') {
            depth++;
          } else if (c == ']') {
            depth--;
          }
          i++;
        }
        if (depth != 0) break;
        predicates.add(s.substring(start, i - 1).trim());
      }
    } else {
      tag = s;
    }
    if (tag.isEmpty) tag = '*';
    return _XpStepSpec(axis, tag, predicates);
  }
}

enum _Axis {
  child,
  descendant,
  descendantOrSelf,
  parent,
  ancestor,
  ancestorOrSelf,
  following,
  preceding,
  self,
  attribute,
}

class _XpStep {
  _XpStep(this.axis, this.tag, this.predicates, this.owner);

  final _Axis axis;
  final String tag;
  final List<String> predicates;
  // Back-reference to the owning [AnalyzeByXPath] so the predicate evaluator
  // can run relative path expressions (count/string/sum) against the context
  // element.  Legado-E delegates this to jsoupXpath; Chloris implements it.
  final AnalyzeByXPath owner;

  Iterable<Element> collect(Element el) {
    switch (axis) {
      case _Axis.self:
        return [el];
      case _Axis.parent:
        return el.parent == null ? const [] : [el.parent!];
      case _Axis.child:
        return el.children;
      case _Axis.descendant:
        final sel = tag == '*' ? '*' : tag;
        return el.querySelectorAll(sel);
      case _Axis.descendantOrSelf:
        final sel = tag == '*' ? '*' : tag;
        return [el, ...el.querySelectorAll(sel)];
      case _Axis.following:
        final sibs = <Element>[];
        var n = el.nextElementSibling;
        while (n != null) {
          sibs.add(n);
          n = n.nextElementSibling;
        }
        return sibs;
      case _Axis.preceding:
        final sibs = <Element>[];
        var n = el.previousElementSibling;
        while (n != null) {
          sibs.add(n);
          n = n.previousElementSibling;
        }
        return sibs.reversed;
      case _Axis.ancestor:
      case _Axis.ancestorOrSelf:
        final ancestors = <Element>[];
        Element? current = axis == _Axis.ancestorOrSelf ? el : el.parent;
        while (current != null) {
          ancestors.add(current);
          current = current.parent;
        }
        return ancestors;
      case _Axis.attribute:
        return const [];
    }
  }

  List<Element> filter(Iterable<Element> input) {
    var list = input.toList();
    if (tag != '*') {
      list = list.where((e) => matchesTag(e)).toList();
    }
    for (final raw in predicates) {
      final p = raw.trim();
      if (p.isEmpty) continue;
      list = [
        for (var i = 0; i < list.length; i++)
          if (_matches(list[i], p, i + 1, list.length)) list[i],
      ];
    }
    return list;
  }

  bool matchesTag(Element element) {
    final wanted = tag.toLowerCase();
    if (wanted == '*' || wanted.isEmpty) return true;
    final actual = (element.localName ?? '').toLowerCase();
    // Namespace prefixes are commonly stripped by package:html; matching the
    // local part keeps `xhtml:div` rules useful on both parsed forms.
    return actual == wanted || actual == wanted.split(':').last;
  }

  bool _matches(Element e, String expression, int position, int total) {
    final p = _stripOuterParens(expression.trim());
    final andParts = _splitLogical(p, 'and');
    if (andParts.length > 1) {
      return andParts.every((part) => _matches(e, part, position, total));
    }
    final orParts = _splitLogical(p, 'or');
    if (orParts.length > 1) {
      return orParts.any((part) => _matches(e, part, position, total));
    }
    if (p.startsWith('not(') && p.endsWith(')')) {
      return !_matches(e, p.substring(4, p.length - 1), position, total);
    }
    final number = int.tryParse(p);
    if (number != null) return position == number;
    if (p == 'last()') return position == total;
    final positional = RegExp(
      r'^position\(\)\s*(=|!=|>=|<=|>|<)\s*(last\(\)|\d+)$',
    ).firstMatch(p);
    if (positional != null) {
      final rhs = positional.group(2) == 'last()'
          ? total
          : int.parse(positional.group(2)!);
      return _compare(position, positional.group(1)!, rhs);
    }
    final lastOffset = RegExp(r'^last\(\)\s*([+-])\s*(\d+)$').firstMatch(p);
    if (lastOffset != null) {
      final offset = int.parse(lastOffset.group(2)!);
      final rhs = lastOffset.group(1) == '+' ? total + offset : total - offset;
      return position == rhs;
    }
    final attr = RegExp(
      r'''^@([\w:-]+)\s*(=|!=|>=|<=|>|<)\s*(['"])(.*?)\3$''',
    ).firstMatch(p);
    if (attr != null) {
      final left = e.attributes[attr.group(1)!] ?? '';
      return _compareString(left, attr.group(2)!, attr.group(4)!);
    }
    final attrExists = RegExp(r'^@([\w:-]+)$').firstMatch(p);
    if (attrExists != null) {
      return e.attributes.containsKey(attrExists.group(1));
    }
    final contains = RegExp(
      r'''^contains\(\s*@([\w:-]+)\s*,\s*(['"])(.*?)\2\s*\)$''',
    ).firstMatch(p);
    if (contains != null) {
      return (e.attributes[contains.group(1)!] ?? '').contains(
        contains.group(3)!,
      );
    }
    final starts = RegExp(
      r'''^starts-with\(\s*@([\w:-]+)\s*,\s*(['"])(.*?)\2\s*\)$''',
    ).firstMatch(p);
    if (starts != null) {
      return (e.attributes[starts.group(1)!] ?? '').startsWith(
        starts.group(3)!,
      );
    }
    final textContains = RegExp(
      r'''^contains\(\s*text\(\)\s*,\s*(['"])(.*?)\1\s*\)$''',
    ).firstMatch(p);
    if (textContains != null) return e.text.contains(textContains.group(2)!);
    final textStarts = RegExp(
      r'''^starts-with\(\s*text\(\)\s*,\s*(['"])(.*?)\1\s*\)$''',
    ).firstMatch(p);
    if (textStarts != null) {
      return e.text.trim().startsWith(textStarts.group(2)!);
    }
    final textEquals = RegExp(
      r'''^(?:normalize-space\(\s*)?text\(\)(?:\s*\))?\s*(=|!=)\s*(['"])(.*?)\2$''',
    ).firstMatch(p);
    if (textEquals != null) {
      final left = p.startsWith('normalize-space')
          ? e.text.trim().replaceAll(RegExp(r'\s+'), ' ')
          : e.text;
      return _compareString(left, textEquals.group(1)!, textEquals.group(3)!);
    }
    final childExists = RegExp(r'^([A-Za-z_][\w:.-]*)$').firstMatch(p);
    if (childExists != null) {
      return e.querySelector(childExists.group(1)!) != null;
    }
    final normalized = RegExp(
      r'''^normalize-space\(\s*text\(\)\s*\)\s*(=|!=)\s*(['"])(.*?)\2$''',
    ).firstMatch(p);
    if (normalized != null) {
      final value = e.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      return _compareString(value, normalized.group(1)!, normalized.group(3)!);
    }
    if (p == 'text()' || p == 'normalize-space(text())') {
      return e.text.trim().isNotEmpty;
    }
    // 对齐 Legado-E 能力缺口（AnalyzeByXPath.kt:48 调 jsoupXpath）。
    // 旧分支覆盖不到的新函数形态（count/substring/concat/string-length/number/
    // sum/name/local-name/string/normalize-space 组合、count(a)=2 数值比较等）
    // 由 [_evalExtended] 求值；仍无法解析时打可见告警而非静默返回空。
    return _evalExtended(e, p, position, total);
  }

  /// Additive value-expression layer.  Reached only for predicate forms the
  /// legacy regex branches above do not recognise.  Implements a small
  /// "value-expression + comparison + boolean" evaluator per XPath 1.0 relaxed
  /// semantics (数值/字符串上下文自动判定), as required by §12-P0-3.
  bool _evalExtended(Element e, String p, int position, int total) {
    final cmp = _splitComparison(p);
    if (cmp != null) {
      final left = _evalValue(e, cmp.lhs, position, total);
      final right = _evalValue(e, cmp.rhs, position, total);
      if (left == _xpathUnrecognized || right == _xpathUnrecognized) {
        return _warnUnsupported(p);
      }
      return _compareValues(left, cmp.op, right);
    }
    final v = _evalValue(e, p, position, total);
    if (v == _xpathUnrecognized) return _warnUnsupported(p);
    return _truthyXpath(v);
  }

  bool _warnUnsupported(String expr) {
    // 失败可见：旧实现直接 return false，用户看到的是「没搜到书」。
    // 这里用引擎已有的 DebugLog 打一条 error 级告警（state:-1 始终落盘）。
    DebugLog.log(
      'XPath',
      '谓词表达式无法解析，按空匹配处理（Legado-E 能力缺口，自实现）: $expr',
      state: -1,
    );
    return false;
  }

  /// Split a top-level comparison `LHS op RHS`.  Respects quotes and nested
  /// parens/brackets so operators inside string literals or function args are
  /// ignored.  Returns `null` when there is no top-level comparison operator.
  _Cmp? _splitComparison(String p) {
    var depth = 0;
    String? quote;
    for (var i = 0; i < p.length; i++) {
      final c = p[i];
      if (quote != null) {
        if (c == quote && !_isEscaped(p, i)) quote = null;
        continue;
      }
      if (c == "'" || c == '"') {
        quote = c;
      } else if (c == '(' || c == '[') {
        depth++;
      } else if (c == ')' || c == ']') {
        if (depth > 0) depth--;
      } else if (depth == 0) {
        final two = p.startsWith('>=', i) ||
            p.startsWith('<=', i) ||
            p.startsWith('!=', i);
        final one = c == '=' || c == '>' || c == '<';
        if (!two && !one) continue;
        // Skip the second char of a two-char operator (already consumed).
        if (i > 0 && (p[i - 1] == '>' || p[i - 1] == '<')) continue;
        final op = two ? p.substring(i, i + 2) : c;
        final lhs = p.substring(0, i).trim();
        final rhs = p.substring(i + op.length).trim();
        if (lhs.isEmpty || rhs.isEmpty) return null;
        return _Cmp(lhs, op, rhs);
      }
    }
    return null;
  }

  /// Evaluate a value expression against the context element [e].
  /// Supported: string/number literals, `@attr`, `text()`, `.`, `position()`,
  /// `last()`, `last()±N` / `position()±N`, and the functions
  /// `string()/count()/substring()/concat()/normalize-space()/string-length()/
  /// number()/sum()/name()/local-name()`.  Anything else returns
  /// [_xpathUnrecognized] so the legacy branches (or the warning) take over.
  dynamic _evalValue(Element e, String raw, int position, int total) {
    final expr = _stripOuterParens(raw.trim());
    if (expr.isEmpty) return _xpathUnrecognized;
    if ((expr.startsWith("'") && expr.endsWith("'") && expr.length >= 2) ||
        (expr.startsWith('"') && expr.endsWith('"') && expr.length >= 2)) {
      return expr.substring(1, expr.length - 1);
    }
    final numLit = num.tryParse(expr);
    if (numLit != null) return numLit;
    if (expr == 'position()') return position.toDouble();
    if (expr == 'last()') return total.toDouble();
    final arith =
        RegExp(r'^(last\(\)|position\(\))\s*([+-])\s*(\d+)$').firstMatch(expr);
    if (arith != null) {
      final base = arith.group(1) == 'last()' ? total : position;
      final off = int.parse(arith.group(3)!);
      final val = arith.group(2) == '+' ? base + off : base - off;
      return val.toDouble();
    }
    if (expr.startsWith('@')) {
      return e.attributes[expr.substring(1)] ?? '';
    }
    if (expr == 'text()' || expr == '.') return e.text;
    final fn = _parseXPathFunctionCall(expr);
    if (fn != null) return _evalFunction(e, fn, position, total);
    return _xpathUnrecognized;
  }

  dynamic _evalFunction(
    Element e,
    _FnCall fn,
    int position,
    int total,
  ) {
    switch (fn.name) {
      // 对齐 Legado-E 能力缺口：jsoupXpath 2.5.3 对下述函数抛
      // NoSuchFunctionException，Chloris 自实现。
      case 'string':
        return _stringValue(e, fn.args.isEmpty ? '.' : fn.args[0].trim());
      case 'normalize-space':
        return _stringValue(e, fn.args.isEmpty ? '.' : fn.args[0].trim())
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ');
      case 'string-length':
        return _stringValue(e, fn.args.isEmpty ? '.' : fn.args[0].trim())
            .length
            .toDouble();
      case 'count':
        // Legado-E 支持；jsoupXpath 的 count() 经 AnalyzeByXPath.kt 透传。
        if (fn.args.isEmpty) return _xpathUnrecognized;
        return owner._select(e, fn.args[0].trim()).length.toDouble();
      case 'substring':
        if (fn.args.length < 2) return _xpathUnrecognized;
        final str = _asText(_evalValue(e, fn.args[0], position, total));
        final start =
            (_toNum(_evalValue(e, fn.args[1], position, total)) ?? 0).toInt();
        final len = fn.args.length >= 3
            ? _toNum(_evalValue(e, fn.args[2], position, total))
            : null;
        // XPath substring() 是 1-based 索引。
        final s = start <= 0 ? 0 : start - 1;
        if (len == null) return str.substring(s);
        final end = s + len.toInt();
        return str.substring(s, end.clamp(0, str.length));
      case 'concat':
        return fn.args
            .map((a) => _asText(_evalValue(e, a, position, total)))
            .join('');
      case 'number':
        if (fn.args.isEmpty) return _xpathUnrecognized;
        return _toNum(_evalValue(e, fn.args[0], position, total)) ?? double.nan;
      case 'sum':
        // Legado-E 经 jsoupXpath 对 sum() 实际返回空（见判题进程复核），
        // Chloris 自实现节点集数值求和。
        if (fn.args.isEmpty) return _xpathUnrecognized;
        final vals = _selectedValues(e, fn.args[0].trim());
        var acc = 0.0;
        for (final v in vals) {
          final n = _toNum(v);
          if (n != null) acc += n;
        }
        return acc;
      case 'name':
        return e.localName ?? '';
      case 'local-name':
        return e.localName ?? '';
      // 以下为 XPath 1.0/2.0 标准谓词函数，对齐 legado（jsoup-xpath）语义。
      // 与 L489-514 的硬编码字面量正则快路径互补：正则负责常见
      // `contains(@attr,'lit')` / `contains(text(),'lit')` 形态（已有测试守护），
      // 此处的通用实现额外支持「参数可为文本/数字/@attr/text()/函数调用/路径」
      // 的递归求值，从而覆盖嵌套表达式与动态参数。
      case 'contains':
        if (fn.args.length < 2) return _xpathUnrecognized;
        return _asText(_evalValue(e, fn.args[0], position, total))
            .contains(_asText(_evalValue(e, fn.args[1], position, total)));
      case 'starts-with':
        if (fn.args.length < 2) return _xpathUnrecognized;
        return _asText(_evalValue(e, fn.args[0], position, total))
            .startsWith(_asText(_evalValue(e, fn.args[1], position, total)));
      case 'ends-with':
        // XPath 2.0 函数；legado 经 jsoup-xpath 的 own 实现提供。大小写敏感。
        if (fn.args.length < 2) return _xpathUnrecognized;
        return _asText(_evalValue(e, fn.args[0], position, total))
            .endsWith(_asText(_evalValue(e, fn.args[1], position, total)));
      case 'translate':
        // 标准 XPath translate()：按字符映射，from 中超出 to 长度的字符被删除，
        // to 多出的字符被忽略；不在 from 中的字符原样保留。对齐 jsoup-xpath。
        if (fn.args.length < 3) return _xpathUnrecognized;
        return _xpathTranslate(
          _asText(_evalValue(e, fn.args[0], position, total)),
          _asText(_evalValue(e, fn.args[1], position, total)),
          _asText(_evalValue(e, fn.args[2], position, total)),
        );
      case 'not':
        // 对齐 jsoup-xpath 的 not() 布尔语义（参数按 XPath 真值表判定后取反）。
        if (fn.args.isEmpty) return _xpathUnrecognized;
        return !_truthyXpath(_evalValue(e, fn.args[0], position, total));
      default:
        return _xpathUnrecognized;
    }
  }

  /// 标准 XPath `translate(string, from, to)` 的字符级映射实现。
  static String _xpathTranslate(String str, String from, String to) {
    final map = <int, String?>{};
    final fromRunes = from.runes.toList();
    final toRunes = to.runes.toList();
    for (var i = 0; i < fromRunes.length; i++) {
      // from 中超出 to 长度的字符 → 映射到 null（删除）。
      map[fromRunes[i]] =
          i < toRunes.length ? String.fromCharCode(toRunes[i]) : null;
    }
    final buf = StringBuffer();
    for (final r in str.runes) {
      final repl = map[r];
      if (repl == null) {
        // 映射结果为 null 表示「删除该字符」；原本就不在 map 中的字符原样保留。
        if (map.containsKey(r)) continue;
        buf.writeCharCode(r);
      } else {
        buf.write(repl);
      }
    }
    return buf.toString();
  }

  /// String value of a node-set expression: `.`/`text()` → element text;
  /// `@attr` → attribute value; otherwise the concatenated text of the nodes
  /// selected by the relative path (approximates XPath string-value).
  String _stringValue(Element e, String inner) {
    final s = inner.trim();
    if (s == '.' || s == 'text()') return e.text;
    if (s.startsWith('@')) return e.attributes[s.substring(1)] ?? '';
    return owner
        ._select(e, s)
        .map((n) => n.text)
        .join('');
  }

  /// Values of a node-set expression used by `count`/`sum`.  A trailing
  /// `/@attr` selects the parent nodes and reads the attribute values, because
  /// [_select] skips attribute-axis steps (mirrors AnalyzeByXPath attribute
  /// handling).
  List<dynamic> _selectedValues(Element e, String path) {
    final trimmed = path.trim();
    final attrMatch = RegExp(r'/@([\w:-]+)$').firstMatch(trimmed);
    if (attrMatch != null) {
      final nodes =
          owner._select(e, trimmed.substring(0, attrMatch.start));
      return nodes.map((n) => n.attributes[attrMatch.group(1)!] ?? '').toList();
    }
    return owner._select(e, trimmed).map((n) => n.text).toList();
  }

  /// Compare two value expressions under XPath 1.0 relaxed semantics: if both
  /// sides are numeric, compare numerically; otherwise compare as strings
  /// (with the same numeric fallback the legacy [_compareString] uses).
  bool _compareValues(dynamic left, String op, dynamic right) {
    final ln = _toNum(left);
    final rn = _toNum(right);
    if (ln != null && rn != null) return _compareNum(ln, op, rn);
    return _compareString(_asText(left), op, _asText(right));
  }

  bool _compareNum(double left, String op, double right) {
    switch (op) {
      case '=':
        return left == right;
      case '!=':
        return left != right;
      case '>':
        return left > right;
      case '<':
        return left < right;
      case '>=':
        return left >= right;
      case '<=':
        return left <= right;
      default:
        return false;
    }
  }

  bool _truthyXpath(dynamic v) {
    if (v is bool) return v;
    if (v == null) return false;
    if (v is num) return v != 0;
    if (v is String) return v.isNotEmpty;
    if (v is List) return v.isNotEmpty;
    return true;
  }

  double? _toNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is bool) return v ? 1.0 : 0.0;
    if (v is String) return num.tryParse(v)?.toDouble();
    return null;
  }

  String _asText(dynamic v) {
    if (v == null) return '';
    if (v is List) return v.map(_asText).join('');
    return v.toString();
  }

  bool _compare(int left, String op, int right) {
    switch (op) {
      case '=':
        return left == right;
      case '!=':
        return left != right;
      case '>':
        return left > right;
      case '<':
        return left < right;
      case '>=':
        return left >= right;
      case '<=':
        return left <= right;
      default:
        return false;
    }
  }

  bool _compareString(String left, String op, String right) {
    switch (op) {
      case '=':
        return left == right;
      case '!=':
        return left != right;
      default:
        final l = num.tryParse(left);
        final r = num.tryParse(right);
        return l != null && r != null && _compare(l.toInt(), op, r.toInt());
    }
  }

  String _stripOuterParens(String value) {
    var out = value;
    while (out.startsWith('(') && out.endsWith(')')) {
      var depth = 0;
      var balanced = true;
      String? quote;
      for (var i = 0; i < out.length; i++) {
        final c = out[i];
        if (quote != null) {
          if (c == quote && !_isEscaped(out, i)) quote = null;
        } else if (c == "'" || c == '"') {
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

  List<String> _splitLogical(String value, String operator) {
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
      if (c == '(') {
        depth++;
        continue;
      }
      if (c == ')') {
        depth--;
        continue;
      }
      if (depth == 0 &&
          value.startsWith(operator, i) &&
          (i == 0 || value[i - 1].trim().isEmpty) &&
          (i + operator.length == value.length ||
              value[i + operator.length].trim().isEmpty)) {
        out.add(value.substring(start, i).trim());
        start = i + operator.length;
        i += operator.length - 1;
      }
    }
    if (out.isEmpty) return [value];
    out.add(value.substring(start).trim());
    return out;
  }

  bool _isEscaped(String value, int index) {
    var slashes = 0;
    for (var i = index - 1; i >= 0 && value[i] == r'\'; i--) {
      slashes++;
    }
    return slashes.isOdd;
  }
}
