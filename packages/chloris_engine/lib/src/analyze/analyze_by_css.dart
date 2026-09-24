import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'rule_analyzer.dart';
import 'rule_cache.dart';

class AnalyzeByCss {
  AnalyzeByCss(Object doc) : element = _asElement(doc);

  final Element element;

  static Element _asElement(Object doc) {
    if (doc is Element) return doc;
    if (doc is Document) return doc.documentElement ?? Element.tag('html');
    return html_parser.parse(doc.toString()).documentElement ??
        Element.tag('html');
  }

  List<Element> getElements(String rule) {
    if (rule.isEmpty) return [];
    final isCss = rule.toLowerCase().startsWith('@css:');
    final body = isCss ? rule.substring(5).trim() : rule;
    final analyzer = RuleAnalyzer(body);
    final parts = analyzer.splitRule(['&&', '||', '%%']);
    final groups = <List<Element>>[];
    for (final part in parts) {
      final els = isCss ? _queryCss(element, part) : _chain(element, part);
      groups.add(els);
      if (els.isNotEmpty && analyzer.elementsType == '||') break;
    }
    return _combine(groups, analyzer.elementsType);
  }

  List<String> getStringList(String rule) {
    if (rule.isEmpty) return [];
    final isCss = rule.toLowerCase().startsWith('@css:');
    final body = isCss ? rule.substring(5).trim() : rule;
    final analyzer = RuleAnalyzer(body);
    final parts = analyzer.splitRule(['&&', '||', '%%']);
    final groups = <List<String>>[];
    for (final part in parts) {
      List<String> values;
      if (isCss) {
        // `@` is the Legado result operator only when it is outside CSS
        // attribute values, pseudo-class arguments and quoted selectors.
        // A naive lastIndexOf('@') turns selectors such as
        // `[data-label="@"]` into an invalid extraction rule.
        final lastAt = _topLevelResultAt(part);
        if (lastAt <= 0) {
          values = _queryCss(element, part).map(_text).toList();
        } else {
          values = _resultLast(
            _queryCss(element, part.substring(0, lastAt)),
            part.substring(lastAt + 1),
          );
        }
      } else {
        values = _stringChain(element, part);
      }
      groups.add(values);
      if (values.isNotEmpty && analyzer.elementsType == '||') break;
    }
    return _combine(groups, analyzer.elementsType);
  }

  /// 对齐 legado `AnalyzeByJSoup.kt:59`：多命中以 `\n` 连接，不做包含式折叠——
  /// 命中集去重/折叠是 Chloris 旧发明的行为，legado 的 getString 就是纯连接。
  String getString(String rule) => getStringList(rule).join('\n');

  String getString0(String rule) {
    final list = getStringList(rule);
    return list.isEmpty ? '' : list.first;
  }

  int _topLevelResultAt(String value) {
    var square = 0;
    var round = 0;
    String? quote;
    var found = -1;
    for (var i = 0; i < value.length; i++) {
      final c = value[i];
      if (quote != null) {
        if (c == quote && (i == 0 || value[i - 1] != r'\')) quote = null;
        continue;
      }
      if (c == '"' || c == "'") {
        quote = c;
      } else if (c == '[') {
        square++;
      } else if (c == ']') {
        if (square > 0) square--;
      } else if (c == '(') {
        round++;
      } else if (c == ')') {
        if (round > 0) round--;
      } else if (c == '@' && square == 0 && round == 0) {
        found = i;
      }
    }
    return found;
  }

  List<Element> _chain(Element root, String rule) {
    var current = <Element>[root];
    final parts = RuleAnalyzer(rule).splitAt();
    if (parts.isEmpty) return current;
    for (final part in parts) {
      final next = <Element>[];
      for (final el in current) {
        next.addAll(_single(el, part));
      }
      current = next;
      if (current.isEmpty) break;
    }
    return current;
  }

  List<String> _stringChain(Element root, String rule) {
    final parts = RuleAnalyzer(rule).splitAt();
    if (parts.isEmpty) return [_text(root)];
    if (parts.length == 1) {
      final op = parts.first.trim();
      if (const {
        'text',
        'html',
        'ownText',
        'href',
        'src',
        'content',
        'tag',
      }.contains(op)) {
        return _resultLast([root], op);
      }
      return _single(root, op).map(_text).toList();
    }
    final last = parts.last;
    var current = <Element>[root];
    for (var i = 0; i < parts.length - 1; i++) {
      final next = <Element>[];
      for (final el in current) {
        next.addAll(_single(el, parts[i]));
      }
      current = next;
    }
    return _resultLast(current, last);
  }

  List<Element> _single(Element temp, String rule) {
    final parsed = _cachedIndexRule(rule);
    List<Element> elements;
    final before = parsed.before;
    if (before.isEmpty) {
      elements = temp.children;
    } else if (_CssPredicates.parse(before) != null) {
      // Legado permits custom prefixes such as `tag.a:contains(...)` and
      // `class.chapter:containsOwn(...)`. Normalize the prefix before sending
      // the selector to the standard CSS parser.
      elements = _queryCss(temp, normalizeCustomSelector(before));
    } else {
      final bits = before.split('.');
      switch (bits[0]) {
        case 'children':
          elements = temp.children;
        case 'class':
          final cls = bits.length > 1 ? bits.sublist(1).join('.') : '';
          elements = [
            if (cls.isNotEmpty && temp.classes.contains(cls.split('.').first))
              temp,
            ...temp.getElementsByClassName(cls),
          ];
        case 'tag':
          final tag = bits.length > 1 ? bits[1].toLowerCase() : '*';
          final descendants = tag == '*'
              ? temp.querySelectorAll('*').toList()
              : temp.getElementsByTagName(tag);
          elements = [
            if (tag == '*' || (temp.localName ?? '').toLowerCase() == tag) temp,
            ...descendants,
          ];
        case 'id':
          final id = bits.length > 1 ? bits[1] : '';
          if (id.isNotEmpty && temp.id == id) {
            elements = [temp];
          } else {
            final found = temp.querySelector('#$id');
            elements = found == null ? <Element>[] : [found];
          }
        case 'text':
          final needle = bits.length > 1 ? bits.sublist(1).join('.') : '';
          elements = temp.querySelectorAll('*').where((e) {
            return e.nodes.any((n) => n is Text && n.text.contains(needle));
          }).toList();
        default:
          elements = _queryCss(temp, before);
      }
    }
    return parsed.apply(elements);
  }

  static String normalizeCustomSelector(String selector) {
    if (selector.startsWith('tag.')) return selector.substring(4);
    if (selector.startsWith('class.')) return '.${selector.substring(6)}';
    if (selector.startsWith('id.')) return '#${selector.substring(3)}';
    return selector;
  }

  /// Queries CSS selectors while supporting the `:contains(text)` extension
  /// used by Legado sources. The `html` package intentionally implements the
  /// standard CSS selector grammar only, so passing this pseudo selector to
  /// `querySelectorAll` throws an `UnimplementedError`.
  ///
  /// 复合选择器按组合子（空格 / `>` / `+` / `~`）逐段求值：谓词（`:contains` /
  /// `:has` 等）绑定在**它所在的那一段**上，而不是整条选择器的末端候选——
  /// 对齐 jsoup `AnalyzeByJSoup.kt:144` 的 `select(ruleStr)` 行为
  /// （如 `dd:contains(x) > a` 的谓词作用在 `dd` 上）。
  List<Element> _queryCss(Element root, String selector) {
    final groups = _splitSelectorGroups(selector);
    if (groups.length > 1) {
      final out = <Element>[];
      for (final group in groups) {
        for (final element in _queryCss(root, group)) {
          if (!out.contains(element)) out.add(element);
        }
      }
      return out;
    }
    return evalSelector([root], selector);
  }

  /// 逐段求值一条（可能复合的）选择器，roots 为求值起点集合。
  /// [firstIsChild] 供 `:has(>a)` 使用：首段以直接子代语义求值。
  static List<Element> evalSelector(
    List<Element> roots,
    String selector, {
    bool firstIsChild = false,
  }) {
    final segments = splitSelectorSegments(selector);
    if (segments.isEmpty) return List<Element>.from(roots);
    var current = roots;
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final comb = (i == 0 && firstIsChild) ? '>' : seg.combinator;
      final next = <Element>[];
      for (final el in current) {
        for (final hit in evalSegment(el, comb, seg.text)) {
          if (!next.contains(hit)) next.add(hit);
        }
      }
      current = next;
      if (current.isEmpty) break;
    }
    return current;
  }

  static List<Element> evalSegment(Element el, String comb, String text) {
    final predicates = _cachedCssPredicates(text);
    final base = (predicates?.selector ?? text).trim();
    final norm = normalizeCustomSelector(base);
    List<Element> candidates;
    switch (comb) {
      case '>':
        candidates = [
          for (final c in el.children)
            if (_matchesSimple(c, norm)) c,
        ];
      case '+':
        final sib = _nextElementSibling(el);
        candidates = (sib != null && _matchesSimple(sib, norm)) ? [sib] : const [];
      case '~':
        candidates = [
          for (
            Element? s = _nextElementSibling(el);
            s != null;
            s = _nextElementSibling(s)
          )
            if (_matchesSimple(s, norm)) s,
        ];
      default:
        if (norm.isEmpty) {
          candidates = el.querySelectorAll('*').toList();
        } else {
          try {
            candidates = el.querySelectorAll(norm);
          } catch (_) {
            candidates = const <Element>[];
          }
        }
    }
    if (predicates != null) {
      candidates = candidates.where(predicates.matches).toList();
    }
    return candidates;
  }

  /// 简单选择器（tag / .cls / #id / tag.cls#id / `tag.x` / `class.x` / `id.x`）匹配。
  static bool _matchesSimple(Element e, String sel) {
    sel = sel.trim();
    if (sel.isEmpty || sel == '*') return true;
    var tag = sel;
    if (sel.startsWith('tag.')) {
      tag = sel.substring(4);
    } else if (sel.startsWith('class.')) {
      return e.classes.contains(sel.substring(6).split('.').first);
    } else if (sel.startsWith('id.')) {
      return e.id == sel.substring(3);
    }
    var id = '';
    final classes = <String>[];
    final m = RegExp(r'^([a-zA-Z][\w-]*|\*)?((?:[.#][\w-]+)*)$').firstMatch(sel);
    if (m != null) {
      tag = m.group(1) ?? '*';
      final rest = m.group(2) ?? '';
      for (final piece in rest.split(RegExp(r'(?=[.#])'))) {
        if (piece.startsWith('.')) classes.add(piece.substring(1));
        if (piece.startsWith('#')) id = piece.substring(1);
      }
    }
    if (tag != '*' && (e.localName ?? '').toLowerCase() != tag.toLowerCase()) {
      return false;
    }
    if (id.isNotEmpty && e.id != id) return false;
    for (final c in classes) {
      if (!e.classes.contains(c)) return false;
    }
    return true;
  }

  static Element? _nextElementSibling(Element e) {
    final parent = e.parent;
    if (parent == null) return null;
    final siblings = parent.children;
    final i = siblings.indexOf(e);
    if (i < 0 || i + 1 >= siblings.length) return null;
    return siblings[i + 1];
  }

  /// 按顶层组合子切分选择器（忽略引号/括号/方括号内的分隔符）。
  static List<_SelSegment> splitSelectorSegments(String selector) {
    final out = <_SelSegment>[];
    final buf = StringBuffer();
    var pendingComb = ' ';
    String? quote;
    var square = 0;
    var round = 0;
    void flush() {
      final t = buf.toString().trim();
      if (t.isNotEmpty) out.add(_SelSegment(pendingComb, t));
      buf.clear();
    }

    for (var i = 0; i < selector.length; i++) {
      final ch = selector[i];
      if (quote != null) {
        buf.write(ch);
        if (ch == quote && (i == 0 || selector[i - 1] != r'\')) quote = null;
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        buf.write(ch);
        continue;
      }
      if (ch == '[') square++;
      if (ch == ']') square = square > 0 ? square - 1 : 0;
      if (ch == '(') round++;
      if (ch == ')') round = round > 0 ? round - 1 : 0;
      if (square == 0 && round == 0) {
        if (ch == '>' || ch == '+' || ch == '~') {
          flush();
          pendingComb = ch;
          continue;
        }
        if (ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r') {
          if (buf.isNotEmpty) {
            flush();
            pendingComb = ' ';
          }
          continue;
        }
      }
      buf.write(ch);
    }
    flush();
    return out;
  }

  List<String> _splitSelectorGroups(String selector) {
    final groups = <String>[];
    var start = 0;
    var squareDepth = 0;
    var parenDepth = 0;
    String? quote;
    for (var i = 0; i < selector.length; i++) {
      final ch = selector[i];
      if (quote != null) {
        if (ch == quote && (i == 0 || selector[i - 1] != r'\')) {
          quote = null;
        }
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
      } else if (ch == '[') {
        squareDepth++;
      } else if (ch == ']') {
        squareDepth = squareDepth > 0 ? squareDepth - 1 : 0;
      } else if (ch == '(') {
        parenDepth++;
      } else if (ch == ')') {
        parenDepth = parenDepth > 0 ? parenDepth - 1 : 0;
      } else if (ch == ',' && squareDepth == 0 && parenDepth == 0) {
        final part = selector.substring(start, i).trim();
        if (part.isNotEmpty) groups.add(part);
        start = i + 1;
      }
    }
    final tail = selector.substring(start).trim();
    if (tail.isNotEmpty) groups.add(tail);
    return groups.isEmpty ? [selector] : groups;
  }

  List<String> _resultLast(List<Element> elements, String lastRule) {
    final out = <String>[];
    switch (lastRule) {
      case 'text':
        for (final e in elements) {
          final t = _text(e);
          if (t.isNotEmpty) out.add(t);
        }
      case 'textNodes':
        for (final e in elements) {
          final nodes = e.nodes
              .whereType<Text>()
              .map((n) => n.text.trim())
              .where((t) => t.isNotEmpty)
              .toList();
          if (nodes.isNotEmpty) out.add(nodes.join('\n'));
        }
      case 'ownText':
        for (final e in elements) {
          // 直接子节点文本；子元素里的 <br> 记为 '\n'（与 @text 同理，保换行）。
          final sb = StringBuffer();
          for (final n in e.nodes) {
            if (n is Text) {
              sb.write(n.text);
            } else if (n is Element && n.localName == 'br') {
              sb.write('\n');
            }
          }
          final t = sb.toString().trim();
          if (t.isNotEmpty) out.add(t);
        }
      case 'html':
        for (final e in [...elements]) {
          e.querySelectorAll('script,style').forEach((n) => n.remove());
        }
        final html = elements.map(jsoupOuterHtml).join();
        if (html.isNotEmpty) out.add(html);
      case 'all':
        out.add(elements.map(jsoupOuterHtml).join());
      default:
        for (final e in elements) {
          final v = e.attributes[lastRule] ?? '';
          if (v.isNotEmpty && !out.contains(v)) out.add(v);
        }
    }
    return out;
  }

  /// 块级元素集合（对齐 jsoup `Element.text()`：块级子元素之间补一个空格，
  /// 如 `<p>作者：甲</p><p>简介：乙</p>` 的 text 为 `作者：甲 简介：乙`）。
  static const _blockTags = {
    'address', 'article', 'aside', 'blockquote', 'details', 'dialog', 'dd',
    'div', 'dl', 'dt', 'fieldset', 'figcaption', 'figure', 'footer', 'form',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hgroup', 'hr', 'li', 'main',
    'nav', 'ol', 'p', 'pre', 'section', 'summary', 'table', 'tbody', 'td',
    'tfoot', 'th', 'thead', 'tr', 'ul',
  };

  /// `@text` 取文本。`<br>` 是正文换行的主要来源（多数站点正文靠 <br> 分行），
  /// 而 `Element.text` 只拼接文本节点、`<br>` 作为元素会被直接吞掉——
  /// 多行正文压成一行，用户看到的就是「换行消失」。
  /// 这里递归拼接时把 <br> 记为 '\n'，换行得以保留；块级子元素之间补空格。
  static String _text(Element e) {
    final sb = StringBuffer();
    var lastCode = -1; // 上一写入字符，避免 toString() 的 O(n) 拷贝。
    void write(String s) {
      if (s.isEmpty) return;
      sb.write(s);
      lastCode = s.codeUnitAt(s.length - 1);
    }

    void walk(Node n) {
      if (n is Text) {
        write(n.text);
        return;
      }
      if (n is Element) {
        if (n.localName == 'br') {
          write('\n');
          return;
        }
        final isBlock = _blockTags.contains(n.localName);
        if (isBlock && lastCode != -1 && lastCode != 0x20 && lastCode != 0x0a && lastCode != 0x09) {
          write(' ');
        }
        for (final child in n.nodes) {
          walk(child);
        }
        if (isBlock && lastCode != -1 && lastCode != 0x20 && lastCode != 0x0a && lastCode != 0x09) {
          write(' ');
        }
      }
    }

    for (final child in e.nodes) {
      walk(child);
    }
    return sb.toString().trim();
  }

  /// Cache the `:contains`/`matches` predicate parse per selector string.
  static _CssPredicates? _cachedCssPredicates(String selector) {
    final key = 'css:pred:$selector';
    final hit = RuleCompileCache.getProduct(key);
    if (hit is _CssPredicates) return hit;
    final parsed = _CssPredicates.parse(selector);
    if (parsed != null) RuleCompileCache.putProduct(key, parsed);
    return parsed;
  }

  /// Cache the trailing index/range expression parse per rule string.
  static _IndexRule _cachedIndexRule(String rule) {
    final key = 'css:idx:$rule';
    final hit = RuleCompileCache.getProduct(key);
    if (hit is _IndexRule) return hit;
    final parsed = _IndexRule.parse(rule);
    RuleCompileCache.putProduct(key, parsed);
    return parsed;
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
}

class _SelSegment {
  const _SelSegment(this.combinator, this.text);
  final String combinator; // ' ', '>', '+', '~'
  final String text;
}

class _CssPredicates {
  const _CssPredicates({required this.selector, required this.predicates});

  final String selector;
  final List<_CssPredicate> predicates;

  bool matches(Element element) {
    return predicates.every((predicate) => predicate.matches(element));
  }

  static _CssPredicates? parse(String input) {
    final predicates = <_CssPredicate>[];
    var selector = input;
    var found = false;
    var cursor = 0;
    final pseudo = RegExp(
      r':(containsOwn|contains|matchesOwn|matches|has)\s*\(',
    );
    while (cursor < selector.length) {
      final match = pseudo.matchAsPrefix(selector, cursor);
      if (match == null) {
        cursor++;
        continue;
      }
      final start = cursor;
      final open = selector.indexOf('(', start);
      final close = _findClosingParen(selector, open);
      if (close < 0) return null;
      var argument = selector.substring(open + 1, close).trim();
      if (argument.length >= 2 &&
          ((argument.startsWith('"') && argument.endsWith('"')) ||
              (argument.startsWith("'") && argument.endsWith("'")))) {
        argument = argument.substring(1, argument.length - 1);
      }
      final kind = match.group(1)!;
      var negate = false;
      var removeStart = start;
      final notStart = start - 5;
      if (notStart >= 0 && selector.substring(notStart, start) == ':not(') {
        negate = true;
        removeStart = notStart;
      }
      final removeEnd =
          negate && close + 1 < selector.length && selector[close + 1] == ')'
          ? close + 2
          : close + 1;
      selector = selector.replaceRange(removeStart, removeEnd, '');
      predicates.add(
        _CssPredicate(kind: kind, pattern: argument, negate: negate),
      );
      found = true;
      cursor = removeStart;
    }
    if (!found) return null;
    return _CssPredicates(selector: selector.trim(), predicates: predicates);
  }

  static int _findClosingParen(String input, int open) {
    var depth = 0;
    String? quote;
    for (var i = open; i < input.length; i++) {
      final ch = input[i];
      if (quote != null) {
        if (ch == quote && (i == 0 || input[i - 1] != r'\')) quote = null;
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
      } else if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }
}

class _CssPredicate {
  const _CssPredicate({
    required this.kind,
    required this.pattern,
    required this.negate,
  });

  final String kind;
  final String pattern;
  final bool negate;

  bool matches(Element element) {
    // `:has(inner)` / `:not(:has(inner))`：对齐 jsoup StructuralEvaluator——
    // `:has(>a)` 只看直接子代，`:has(a)` 看全部后代。
    if (kind == 'has') {
      var inner = pattern;
      var childOnly = false;
      if (inner.startsWith('>')) {
        childOnly = true;
        inner = inner.substring(1).trim();
      }
      final result = AnalyzeByCss.evalSelector(
        [element],
        inner,
        firstIsChild: childOnly,
      ).isNotEmpty;
      return negate ? !result : result;
    }
    final ownText = element.nodes.whereType<Text>().map((n) => n.text).join();
    final value = kind.endsWith('Own') ? ownText : element.text;
    var result = false;
    if (kind.startsWith('contains')) {
      result = value.contains(pattern);
    } else {
      // The predicate pattern is fixed by the rule string, so compile it once
      // and reuse it across every element this rule is applied to.
      final re = RuleCompileCache.regex(pattern);
      if (re != null) {
        result = re.hasMatch(value);
      } else {
        result = value.contains(pattern);
      }
    }
    return negate ? !result : result;
  }
}

class _IndexRule {
  _IndexRule({
    required this.before,
    required this.mode,
    required this.indexes,
    this.ranges = const [],
  });

  final String before;
  final String mode; // '.' select, '!' exclude, '' none
  final List<int> indexes;
  final List<_Range> ranges;

  static _IndexRule parse(String rule) {
    final rus = rule.trim();
    final bracket = rus.lastIndexOf('[');
    // A trailing bracket is an index operator only when its complete body
    // matches Legado's numeric index/range grammar.  Plain CSS attribute
    // selectors such as `a[href]` must remain part of the selector.
    if (bracket >= 0 &&
        rus.endsWith(']') &&
        _isBracketIndexExpression(rus.substring(bracket + 1, rus.length - 1))) {
      final inside = rus.substring(bracket + 1, rus.length - 1);
      final before = rus.substring(0, bracket);
      final exclude = inside.startsWith('!');
      final body = exclude ? inside.substring(1) : inside;
      final idx = <int>[];
      final ranges = <_Range>[];
      for (final part in body.split(',')) {
        final p = part.trim();
        if (p.contains(':')) {
          final bits = p.split(':');
          final start = int.tryParse(bits[0].isEmpty ? '0' : bits[0]) ?? 0;
          final end = bits.length > 1 && bits[1].isNotEmpty
              ? int.tryParse(bits[1])
              : null;
          final step = bits.length > 2 ? int.tryParse(bits[2]) ?? 1 : 1;
          ranges.add(_Range(start, end, step));
        } else if (p.isNotEmpty) {
          idx.add(int.tryParse(p) ?? 0);
        }
      }
      return _IndexRule(
        before: before,
        mode: exclude ? '!' : '.',
        indexes: idx,
        ranges: ranges,
      );
    }
    final bang = rus.lastIndexOf('!');
    final dot = rus.lastIndexOf('.');
    final colon = rus.lastIndexOf(':');
    if (bang > 0 && _isIndexTail(rus.substring(bang + 1))) {
      return _IndexRule(
        before: rus.substring(0, bang),
        mode: '!',
        indexes: _parseTail(rus.substring(bang + 1)),
      );
    }
    if (dot > 0 &&
        _isIndexTail(rus.substring(dot + 1)) &&
        !_looksLikeClass(rus)) {
      return _IndexRule(
        before: rus.substring(0, dot),
        mode: '.',
        indexes: _parseTail(rus.substring(dot + 1)),
      );
    }
    if (colon > 0 && _isIndexTail(rus.substring(colon).replaceAll(':', '0'))) {
      return _IndexRule(
        before: rus.substring(0, rus.indexOf(RegExp(r'[.:!]-?\d'))),
        mode: '.',
        indexes: _parseTail(rus.substring(rus.indexOf(RegExp(r'-?\d')))),
      );
    }
    return _IndexRule(before: rus, mode: '', indexes: const []);
  }

  static bool _isBracketIndexExpression(String inside) {
    var value = inside.trim();
    if (value.startsWith('!')) value = value.substring(1).trim();
    if (value.isEmpty) return false;
    // Each comma-separated term is either an integer or a start:end[:step]
    // range. Empty range endpoints are accepted (`[:], [1:], [::-1]`).
    final term = RegExp(r'^-?\d*(?::\s*-?\d*){1,2}$');
    for (final raw in value.split(',')) {
      final part = raw.trim();
      if (part.isEmpty) return false;
      if (RegExp(r'^-?\d+$').hasMatch(part)) continue;
      if (!term.hasMatch(part.replaceAll(' ', ''))) return false;
    }
    return true;
  }

  static bool _looksLikeClass(String rus) {
    return rus.startsWith('class.') && !RegExp(r'\.\-?\d+$').hasMatch(rus);
  }

  static bool _isIndexTail(String s) {
    return RegExp(r'^-?\d+(?:[:-]-?\d+)*$').hasMatch(s.replaceAll(' ', ''));
  }

  static List<int> _parseTail(String s) {
    return s
        .split(RegExp(r'[:.]'))
        .where((e) => e.isNotEmpty)
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
  }

  List<Element> apply(List<Element> elements) {
    if (mode.isEmpty || (indexes.isEmpty && ranges.isEmpty)) return elements;
    final len = elements.length;
    final set = <int>{};
    for (final raw in indexes) {
      var i = raw;
      if (i < 0) i += len;
      if (i >= 0 && i < len) set.add(i);
    }
    for (final range in ranges) {
      // 对齐 Legado-E AnalyzeByJSoup.kt:342-347 负索引转正、右端省略取 len-1
      var start = range.start;
      if (start < 0) start += len;
      var end = range.end ?? (len - 1);
      if (end < 0) end += len;
      // 对齐 :348-351 同侧越界（区间两端整体在列表之外）→ 整段跳过
      if ((start < 0 && end < 0) || (start >= len && end >= len)) {
        continue;
      }
      // 对齐 :353-357 越界端点 clamp 到有效边界 [0, len-1]
      if (start >= len) {
        start = len - 1;
      } else if (start < 0) {
        start = 0;
      }
      if (end >= len) {
        end = len - 1;
      } else if (end < 0) {
        end = 0;
      }
      // 对齐 :359-364 两端重合或 step>=len 时区间仅含 start 一个元素
      if (start == end || range.step >= len) {
        set.add(start);
        continue;
      }
      // 对齐 :366-370 负 step 归一。Kotlin 侧归一后的 step 恒为正数：
      // `start..end step step` 升序、`start downTo end step step` 降序。
      final step = range.step > 0
          ? range.step
          : (-range.step < len ? range.step + len : 1);
      if (end > start) {
        for (var i = start; i <= end; i += step) {
          set.add(i);
        }
      } else {
        // 降序：Kotlin 的 `downTo` 用正 step 递减。此处必须 `-= step`，
        // 否则 start > end 时条件恒真、循环不会退出。
        for (var i = start; i >= end; i -= step) {
          set.add(i);
        }
      }
    }
    if (mode == '!') {
      return [
        for (var i = 0; i < elements.length; i++)
          if (!set.contains(i)) elements[i],
      ];
    }
    return [for (final i in set) elements[i]];
  }
}

class _Range {
  _Range(this.start, this.end, this.step);
  final int start;
  final int? end;
  final int step;
  int get sentinel => start;
}

// ---------------------------------------------------------------------------
// jsoup 1.16.2 pretty-print 序列化
//
// Legado 的 `e.outerHtml`/`el.html()` 走 jsoup 默认 OutputSettings
// （prettyPrint=true、indentAmount=1、syntax=html），`@html`/`@all` 拿到的是
// 缩进后的标记而不是 package:html 的紧凑序列化。下面是 jsoup 输出算法的
// 逐行移植：Element.outerHtmlHead/Tail + TextNode.outerHtmlHead +
// Node.indent（`\n` + depth*1 空格，封顶 30）。
// ---------------------------------------------------------------------------

/// jsoup Tag 表 —— blockTags（Tag.java）。
const _jsoupBlockTags = {
  'html', 'head', 'body', 'frameset', 'script', 'noscript', 'style', 'meta',
  'link', 'title', 'frame', 'noframes', 'section', 'nav', 'aside', 'hgroup',
  'header', 'footer', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol',
  'pre', 'div', 'blockquote', 'hr', 'address', 'figure', 'figcaption', 'form',
  'fieldset', 'ins', 'del', 'dl', 'dt', 'dd', 'li', 'table', 'caption',
  'thead', 'tfoot', 'tbody', 'colgroup', 'col', 'tr', 'th', 'td', 'video',
  'audio', 'canvas', 'details', 'menu', 'plaintext', 'template', 'article',
  'main', 'svg', 'math', 'center', 'dir', 'applet', 'marquee', 'listing',
};

/// jsoup emptyTags：无子节点时序列化为 `<tag>` 且不带 `</tag>`。
const _jsoupEmptyTags = {
  'meta', 'link', 'base', 'frame', 'img', 'br', 'wbr', 'embed', 'hr', 'input',
  'keygen', 'col', 'command', 'device', 'area', 'basefont', 'bgsound',
  'menuitem', 'param', 'source', 'track',
};

/// jsoup formatAsInlineTags：是 block 但子节点不按块缩进（p/a/li/td/pre…）。
const _jsoupFormatAsInlineTags = {
  'title', 'a', 'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'pre', 'address',
  'li', 'th', 'td', 'script', 'style', 'ins', 'del', 's',
};

/// jsoup preserveWhitespaceTags：子文本不做空白归一。
const _jsoupPreserveWhitespaceTags = {'pre', 'plaintext', 'title', 'textarea'};

/// jsoup Attributes.booleanAttributes：值为空或等于键名时可折叠为裸键。
const _jsoupBooleanAttrs = {
  'allowfullscreen', 'async', 'autofocus', 'checked', 'compact', 'declare',
  'default', 'defer', 'disabled', 'formnovalidate', 'hidden', 'inert',
  'ismap', 'itemscope', 'multiple', 'muted', 'nohref', 'noresize', 'noshade',
  'novalidate', 'nowrap', 'open', 'readonly', 'required', 'reversed',
  'seamless', 'selected', 'sortable', 'truespeed', 'typemustmatch',
};

bool _jsoupIsBlock(String? name) => _jsoupBlockTags.contains(name);

bool _jsoupIsEmpty(String? name) => _jsoupEmptyTags.contains(name);

bool _jsoupFormatAsBlock(String? name) =>
    _jsoupIsBlock(name) && !_jsoupFormatAsInlineTags.contains(name);

/// `Element.preserveWhitespace`：自身或至多 5 层祖先带 preserveWhitespace 标签。
bool _jsoupPreserveWhitespace(Node? node) {
  var el = node is Element ? node : node?.parent;
  var i = 0;
  while (i < 6 && el != null) {
    if (_jsoupPreserveWhitespaceTags.contains(el.localName)) return true;
    el = el.parent;
    i++;
  }
  return false;
}

int _nodeIndex(Node n) {
  final p = n.parentNode;
  return p == null ? 0 : p.nodes.indexOf(n);
}

Node? _prevSibling(Node n) {
  final p = n.parentNode;
  if (p == null) return null;
  final i = _nodeIndex(n);
  return i > 0 ? p.nodes[i - 1] : null;
}

Node? _nextSibling(Node n) {
  final p = n.parentNode;
  if (p == null) return null;
  final i = _nodeIndex(n);
  return i < p.nodes.length - 1 ? p.nodes[i + 1] : null;
}

/// 第一个子节点，或紧跟空白文本节点之后（jsoup `isEffectivelyFirst`）。
bool _isEffectivelyFirst(Element el) {
  final idx = _nodeIndex(el);
  if (idx == 0) return true;
  if (idx == 1) {
    final prev = _prevSibling(el);
    return prev is Text && prev.data.trim().isEmpty;
  }
  return false;
}

bool _isInlineable(Element el) {
  if (el.localName == 'br') return false;
  // jsoup Tag.isInline() = !isBlock；未知标签同理视作 inline。
  if (_jsoupIsBlock(el.localName)) return false;
  final parent = el.parent;
  return (parent == null || _jsoupIsBlock(parent.localName)) &&
      !_isEffectivelyFirst(el);
}

bool _isFormatAsBlock(Element el) =>
    _jsoupIsBlock(el.localName) ||
    (el.parent != null && _jsoupFormatAsBlock(el.parent!.localName));

bool _shouldIndentElement(Element el) =>
    _isFormatAsBlock(el) &&
    !_isInlineable(el) &&
    !_jsoupPreserveWhitespace(el.parentNode);

/// `\n` + depth 个空格（indentAmount=1），jsoup `maxPaddingWidth` 封顶 30。
void _indent(StringBuffer sb, int depth) {
  sb.write('\n');
  for (var i = 0; i < depth && i < 30; i++) {
    sb.write(' ');
  }
}

/// jsoup `StringUtil.normaliseWhitespace`：`\t\n\v\f\r` 与空格的连续段压成一个空格。
String _normaliseWhitespace(String text) {
  final sb = StringBuffer();
  var lastWasWs = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    final isWs = c == ' ' ||
        c == '\t' ||
        c == '\n' ||
        c == '\u000B' ||
        c == '\f' ||
        c == '\r';
    if (isWs) {
      if (lastWasWs) continue;
      sb.write(' ');
      lastWasWs = true;
    } else {
      sb.write(c);
      lastWasWs = false;
    }
  }
  return sb.toString();
}

/// 追加文本时若累加器末尾已是空白，吞掉新文本的前导空格
/// （jsoup `appendNormalisedWhitespace` 的 `lastCharIsWhitespace(accum)`）。
void _appendNormalised(StringBuffer sb, String text) {
  if (text.isEmpty) return;
  if (text.startsWith(' ') && sb.isNotEmpty) {
    final last = sb.toString()[sb.length - 1];
    if (last == ' ' || last == '\n') text = text.substring(1);
  }
  sb.write(text);
}

String _escapeText(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('\u00A0', '&nbsp;');

String _escapeAttr(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('\u00A0', '&nbsp;');

/// 逐行移植 jsoup `Element.outerHtml`（默认 prettyPrint、html syntax）。
String jsoupOuterHtml(Element el) {
  final sb = StringBuffer();
  _emitJsoup(el, sb, 0);
  return sb.toString();
}

void _emitJsoup(Node node, StringBuffer sb, int depth) {
  if (node is Element) {
    _emitElement(node, sb, depth);
  } else if (node is Text) {
    _emitText(node, sb, depth);
  } else if (node is Comment) {
    // jsoup Comment.outerHtmlHead：作为 formatAsBlock 父级的首个子节点时缩进。
    final parent = node.parent;
    if (_nodeIndex(node) == 0 &&
        parent != null &&
        _jsoupFormatAsBlock(parent.localName) &&
        (node.data ?? '').trim().isNotEmpty) {
      _indent(sb, depth);
    }
    sb.write('<!--${node.data ?? ''}-->');
  } else if (node is DocumentType) {
    sb.write('<!doctype html>');
  }
}

void _emitElement(Element el, StringBuffer sb, int depth) {
  if (_shouldIndentElement(el) && sb.isNotEmpty) _indent(sb, depth);
  final name = el.localName ?? '';
  sb.write('<');
  sb.write(name);
  el.attributes.forEach((key, value) {
    final k = key.toString();
    // Attribute.shouldCollapseAttribute：html 语法下值为空或等于键名的
    // 布尔属性折叠为裸键（`disabled`），其余一律 `key="escaped"`。
    final collapse = (value.isEmpty || value.toLowerCase() == k.toLowerCase()) &&
        _jsoupBooleanAttrs.contains(k.toLowerCase());
    sb.write(' ');
    sb.write(k);
    if (!collapse) {
      sb.write('="');
      sb.write(_escapeAttr(value));
      sb.write('"');
    }
  });
  final children = el.nodes;
  if (children.isEmpty && _jsoupIsEmpty(name)) {
    sb.write('>'); // html 语法下 empty 标签无自闭合斜杠、无尾标签
    return;
  }
  sb.write('>');
  for (final child in children) {
    _emitJsoup(child, sb, depth + 1);
  }
  if (children.isNotEmpty &&
      _jsoupFormatAsBlock(name) &&
      !_jsoupPreserveWhitespace(el.parentNode)) {
    _indent(sb, depth);
  }
  sb.write('</');
  sb.write(name);
  sb.write('>');
}

void _emitText(Text t, StringBuffer sb, int depth) {
  final parent = t.parent;
  final rawData = parent != null &&
      (parent.localName == 'script' || parent.localName == 'style');
  final normalise = !rawData && !_jsoupPreserveWhitespace(t.parentNode);
  var text = t.data;
  if (normalise) {
    final parentName = parent?.localName;
    final trimLikeBlock =
        parent != null && (_jsoupIsBlock(parentName) || _jsoupFormatAsBlock(parentName));
    final idx = _nodeIndex(t);
    final next = _nextSibling(t);
    final prev = _prevSibling(t);
    final trimLeading = (trimLikeBlock && idx == 0) || t.parentNode is Document;
    final trimTrailing = trimLikeBlock && next == null;
    final isBlank = text.trim().isEmpty;
    // 仅空白文本且下一节点要缩进 / 上一节点是块或 <br> 时整体跳过。
    final couldSkip = (next is Element && _shouldIndentElement(next)) ||
        (next is Text && next.data.trim().isEmpty) ||
        (prev is Element &&
            (_jsoupIsBlock(prev.localName) || prev.localName == 'br'));
    if (couldSkip && isBlank) return;
    if ((idx == 0 &&
            parent != null &&
            _jsoupFormatAsBlock(parentName) &&
            !isBlank) ||
        (idx > 0 && prev is Element && prev.localName == 'br')) {
      _indent(sb, depth);
    }
    text = _normaliseWhitespace(text);
    if (trimLeading) text = text.trimLeft();
    if (trimTrailing) text = text.trimRight();
    _appendNormalised(sb, _escapeText(text));
    return;
  }
  sb.write(rawData ? text : _escapeText(text));
}
