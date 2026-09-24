import 'dart:convert';

import '../debug/debug_log.dart';
import '../js/java_host.dart';
import '../js/js_host_bridge.dart';
import '../js/js_runtime.dart';
import '../models/book.dart';
import '../models/domain_protocol.dart';
import '../models/book_source.dart';
import '../net/engine_limits.dart';
import '../net/network_utils.dart';
import '../net/web_view_port.dart';
import 'analyze_by_css.dart';
import 'analyze_by_jsonpath.dart';
import 'analyze_by_regex.dart';
import 'analyze_by_xpath.dart';
import 'rule_analyzer.dart';
import 'rule_cache.dart';
import 'rule_data.dart';
import 'rule_mode.dart';

class AnalyzeRule {
  AnalyzeRule({
    this.ruleData,
    this.source,
    this.javaHost,
    required this.jsRuntime,
  }) {
    javaHost?.analyzeRule = this;
  }

  RuleData? ruleData;
  BookSource? source;
  Book? book;
  BookChapter? chapter;
  JavaHost? javaHost;
  final JsRuntime jsRuntime;

  Object? content;
  String? baseUrl;
  String? redirectUrl;

  /// URL of the next chapter supplied by the caller.  Legado exposes this as
  /// a distinct JS binding; falling back to the current chapter URL changes
  /// pagination rules that inspect `nextChapterUrl`.
  String? nextChapterUrl;
  bool isJson = false;
  bool isRegex = false;
  int page = 1;

  AnalyzeByCss? _css;
  AnalyzeByJsonPath? _json;
  AnalyzeByXPath? _xpath;

  AnalyzeRule setContent(Object? value, [String? base]) {
    content = value;
    isJson =
        value is Map ||
        value is List ||
        (value is String && _looksJson(value.toString()));
    if (base != null) baseUrl = base;
    _css = null;
    _json = null;
    _xpath = null;
    return this;
  }

  AnalyzeRule setBaseUrl(String? url) {
    if (url != null) baseUrl = url;
    return this;
  }

  AnalyzeRule setRedirectUrl(String url) {
    // Legado does not replace a useful redirect with a data URI (cover/image
    // rules occasionally pass one through this setter).
    if (url.toLowerCase().startsWith('data:')) return this;
    redirectUrl = url;
    return this;
  }

  AnalyzeRule setNextChapterUrl(String? url) {
    nextChapterUrl = url;
    return this;
  }

  AnalyzeRule setBook(Book? value) {
    book = value;
    return this;
  }

  AnalyzeRule setChapter(BookChapter? value) {
    chapter = value;
    return this;
  }

  Future<String> getString(
    String? rule, {
    Object? mContent,
    bool isUrl = false,
    bool unescape = true,
  }) async {
    if (rule == null || rule.isEmpty) return '';
    final rules = splitSourceRule(rule);
    var result = mContent ?? content;
    for (final sourceRule in rules) {
      await putMap(sourceRule.putMap);
      await sourceRule.makeUp(this, result);
      if (sourceRule.literalValue != null) {
        result = sourceRule.literalValue;
        if (sourceRule.replaceRegex.isNotEmpty) {
          result = _replaceRegex(result.toString(), sourceRule);
        }
        continue;
      }
      if (sourceRule.rule.isEmpty && sourceRule.replaceRegex.isEmpty) continue;
      result = await _apply(sourceRule, result, isUrl: isUrl);
      if (result != null && sourceRule.replaceRegex.isNotEmpty) {
        result = _replaceRegex(result.toString(), sourceRule);
      }
    }
    var str = result?.toString() ?? '';
    if (unescape && str.contains('&')) str = htmlUnescape(str);
    if (isUrl) {
      final trimmed = str.trim();
      // A blank extracted URL resolves against the document base, not the
      // redirect target.  This is the behaviour of NetworkUtils' Legado
      // overload and matters for empty/optional link selectors.
      if (trimmed.isEmpty) return baseUrl ?? '';
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('javascript:') ||
          lower.startsWith('mailto:') ||
          trimmed == '#') {
        return '';
      }
      return getAbsoluteUrl(redirectUrl ?? baseUrl, trimmed);
    }
    return str;
  }

  Future<List<String>> getStringList(
    String? rule, {
    Object? mContent,
    bool isUrl = false,
  }) async {
    if (rule == null || rule.isEmpty) return [];
    final rules = splitSourceRule(rule);
    var result = mContent ?? content;
    for (final sourceRule in rules) {
      await putMap(sourceRule.putMap);
      await sourceRule.makeUp(this, result);
      if (sourceRule.literalValue != null) {
        result = sourceRule.literalValue;
        if (sourceRule.replaceRegex.isNotEmpty) {
          result = _replaceRegex(result.toString(), sourceRule);
        }
        continue;
      }
      result = await _apply(sourceRule, result, list: true, isUrl: isUrl);
      if (sourceRule.replaceRegex.isNotEmpty && result is List) {
        result = [
          for (final item in result) _replaceRegex(item.toString(), sourceRule),
        ];
      } else if (sourceRule.replaceRegex.isNotEmpty && result != null) {
        result = _replaceRegex(result.toString(), sourceRule);
      }
    }
    if (result == null) return [];
    if (result is String) result = result.split('\n');
    if (isUrl && result is List) {
      final urls = <String>[];
      for (final url in result) {
        final abs = getAbsoluteUrl(redirectUrl ?? baseUrl, url.toString());
        if (abs.isNotEmpty && !urls.contains(abs)) urls.add(abs);
      }
      return urls;
    }
    if (result is List) {
      return [
        for (final e in result)
          if (e != null && e.toString().isNotEmpty) e.toString(),
      ];
    }
    return [result.toString()];
  }

  Future<List<Object>> getElements(String rule) async {
    if (rule.isEmpty || content == null) return [];
    final rules = splitSourceRule(rule, allInOne: true);
    Object? result = content;
    for (final sourceRule in rules) {
      await putMap(sourceRule.putMap);
      await sourceRule.makeUp(this, result);
      if (sourceRule.literalValue != null) {
        result = sourceRule.literalValue;
        if (sourceRule.replaceRegex.isNotEmpty) {
          result = _replaceRegex(result.toString(), sourceRule);
        }
        continue;
      }
      result = await _apply(sourceRule, result, elements: true);
    }
    if (result is List) {
      return [for (final e in result) e as Object];
    }
    return result == null ? [] : [result];
  }

  Future<Object?> getElement(String rule) async {
    final list = await getElements(rule);
    return list.isEmpty ? null : list.first;
  }

  Future<void> putMap(Map<String, String> map) async {
    // Legado evaluates the value in the current rule context before storing it.
    // Keeping this awaited is important: a later @get must observe the value,
    // rather than the selector text itself.
    for (final entry in map.entries) {
      final value = entry.value;
      if (value.trim().isEmpty) {
        put(entry.key, '');
      } else {
        final evaluated = await getString(value);
        // Source authors also use @put for constants (for example a label or
        // an API flag).  A plain constant is indistinguishable from a selector
        // until it is evaluated; when selector evaluation yields no value,
        // preserve the literal for values that contain no rule syntax.  Keep
        // selector-looking values empty so a genuinely missing field does not
        // leak its selector text into the result.
        put(
          entry.key,
          evaluated.isEmpty && _isPlainPutLiteral(value)
              ? value.trim()
              : evaluated,
        );
      }
    }
  }

  static bool _isPlainPutLiteral(String value) {
    final text = value.trim();
    if (text.isEmpty) return true;
    // Non-ASCII text, whitespace, URLs, and scalar JSON values are common
    // constants in source definitions and cannot be useful CSS selectors.
    if (RegExp(r'[\u0080-\uFFFF]').hasMatch(text) ||
        RegExp(r'\s').hasMatch(text) ||
        RegExp(r'^(?:https?|data):', caseSensitive: false).hasMatch(text) ||
        num.tryParse(text) != null ||
        text == 'true' ||
        text == 'false' ||
        text == 'null') {
      return true;
    }
    // Explicit Legado/JSON/JS/CSS operators indicate a rule, not a literal.
    if (RegExp(r'''[@$#\.\[\]{}():><|&/]''').hasMatch(text) ||
        text.contains('##') ||
        text.contains('{{') ||
        text.contains('}}')) {
      return false;
    }
    // Keep the standard HTML element names selector-like.  Other bare words
    // are accepted as constants when no matching element was found.
    const htmlTags = {
      'a',
      'article',
      'aside',
      'body',
      'button',
      'canvas',
      'dd',
      'div',
      'dl',
      'dt',
      'em',
      'footer',
      'form',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'head',
      'header',
      'html',
      'img',
      'input',
      'label',
      'li',
      'main',
      'meta',
      'nav',
      'ol',
      'option',
      'p',
      'script',
      'section',
      'select',
      'small',
      'span',
      'strong',
      'style',
      'table',
      'tbody',
      'td',
      'textarea',
      'tfoot',
      'th',
      'thead',
      'title',
      'tr',
      'ul',
    };
    return !htmlTags.contains(text.toLowerCase());
  }

  String put(String key, String value) {
    if (chapter != null) {
      chapter!.putVariable(key, value);
    } else if (book != null) {
      book!.putVariable(key, value);
    } else if (ruleData != null) {
      ruleData!.put(key, value);
    } else if (source != null) {
      source!.put(key, value);
    } else {
      (ruleData ??= RuleData()).put(key, value);
    }
    return value;
  }

  String get(String key) {
    if (key == 'bookName' && book != null) return book!.name;
    if (key == 'title' && chapter != null) return chapter!.title;
    final fromChapter = chapter?.getVariable(key) ?? '';
    if (fromChapter.isNotEmpty) return fromChapter;
    final fromBook = book?.getVariable(key) ?? '';
    if (fromBook.isNotEmpty) return fromBook;
    final fromRule = ruleData?.get(key) ?? '';
    if (fromRule.isNotEmpty) return fromRule;
    final fromSource = source?.get(key) ?? '';
    if (fromSource.isNotEmpty) return fromSource;
    return '';
  }

  Future<Object?> evalJs(
    String code,
    Object? result, {
    Map<String, Object?> extra = const {},
    bool strict = true,
  }) async {
    final scope = JsScope(
      variables: {
        'result': result,
        'baseUrl': baseUrl ?? '',
        'book': book,
        'chapter': chapter,
        'source': source,
        // In Legado `src` is the original document, while `source` is the
        // BookSource object.  Several image/content scripts rely on this
        // distinction (using the source object here silently breaks them).
        'src': content,
        'cookie': source == null || javaHost == null
            ? ''
            : javaHost!.cookieStore.get(source!.bookSourceUrl),
        'nextChapterUrl': nextChapterUrl ?? '',
        // The Android host exposes a boolean indicating whether the rule was
        // evaluated from book-info context.  A truthy Book object is not
        // equivalent when a JS script serializes or compares the value.
        'fromBookInfo': book != null,
        'key': ruleData?.get('key') ?? '',
        'page': page,
        // Legado binds these in the rule scope. Leaving any of them out made a
        // script that referenced one raise ReferenceError, which the runtime
        // swallowed and turned into "return the input unchanged" -- a silent
        // wrong answer rather than a visible failure.
        'title': chapter?.title ?? '',
        'rssArticle': null,
        'speakText': '',
        'speakSpeed': '',
        'infoMap': const <String, Object?>{},
        'java': javaHost,
        ...extra,
      },
    );
    try {
      return await JsHostBridge.evalWithDeadline(
        jsRuntime,
        JsHostBridge.prependJsLib(source?.jsLib, code),
        scope,
        timeout: EngineLimits.jsEvalTimeout,
        rule: code,
      );
    } catch (e) {
      // 超时是调用方保护行为，不属于「静默退化」范畴：原样透传，
      // 让上层拿到 js_deadline 而不是被包装成 js_eval_failed。
      if (e is DomainError && e.code == 'js_deadline') rethrow;
      // 没有 JS 虚拟机时（Web/测试），引擎用 NoJsRuntime 或 LenientJsRuntime 作为最佳
      // 努力解释器。NoJsRuntime.eval 始终抛 UnsupportedError，LenientJsRuntime 自身
      // 就是宽松解释器。这两种「无 VM」情况回退到 LenientJsRuntime.interpretJs 是刻意的、
      // 有价值的行为，必须保留（对齐 Legado-E 无 VM 场景）。
      // 见差异文档 §12 P1「JS 异常路径静默退化」。
      final noVmEngine =
          jsRuntime is NoJsRuntime || jsRuntime is LenientJsRuntime;
      if (noVmEngine) {
        return LenientJsRuntime.interpretJs(code, scope);
      }
      // 有完整 JS 引擎（如 QuickJS/浏览器）但脚本执行失败：对齐 Legado-E 严格失败可见。
      // 严格模式下不再静默退化为宽松解释器「猜中」的看似合理的值（result/key/page/URL/
      // result.replace/java.x() 等），而是经 DebugLog 上报并抛出可见的 DomainError。
      // 宽松解释器的「静默猜中」正是文档指出的最危险退化。非严格模式仍允许宽松回退
      // （仅用于诊断/迁移场景）。
      if (strict) {
        DebugLog.error('evalJs', 'JS 求值失败，已阻断静默退化：$code', e);
        throw DomainError(
          code: 'js_eval_failed',
          stage: DomainErrorStage.render,
          message: 'JS 求值失败且不允许静默回退到宽松解释器',
          cause: code,
          recoverable: false,
          retryable: false,
          suggestedAction: '该规则需要完整 JS 运行时；请检查书源规则或改用受支持写法',
        );
      }
      return LenientJsRuntime.interpretJs(code, scope);
    }
  }

  Future<Object?> _apply(
    SourceRule sourceRule,
    Object? current, {
    bool list = false,
    bool elements = false,
    bool isUrl = false,
  }) async {
    final rule = sourceRule.rule;
    if (rule.isEmpty) return current;
    switch (sourceRule.mode) {
      case RuleMode.js:
        return evalJs(rule, current);
      case RuleMode.webJs:
        final port = javaHost?.webViewPort;
        if (port != null) {
          try {
            final response = await port.run(
              WebViewRequest(
                url: baseUrl ?? '',
                html: current?.toString(),
                javaScript: rule,
              ),
            );
            if (response != null) {
              // BackstageWebView returns JSON for arrays/objects.  Legado
              // converts a JSON array to a list for getStringList while
              // retaining scalar bodies as strings.
              final body = response.body;
              if (list || elements) {
                try {
                  final decoded = jsonDecode(body);
                  if (decoded is List || decoded is Map) return decoded;
                } catch (_) {
                  // Scalar/non-JSON body: keep the raw response.
                }
              }
              return body;
            }
          } catch (_) {
            // Fall back to the regular runtime for headless/test hosts.
          }
        }
        return evalJs(rule, current);
      case RuleMode.json:
        final jp = current == content
            ? (_json ??= AnalyzeByJsonPath(current ?? ''))
            : AnalyzeByJsonPath(current ?? '');
        if (elements) return jp.getList(rule);
        if (list) return jp.getStringList(rule);
        return jp.getString(rule);
      case RuleMode.xpath:
        final xp = current == content
            ? (_xpath ??= AnalyzeByXPath(current ?? ''))
            : AnalyzeByXPath(current ?? '');
        if (elements) return xp.getElements(rule);
        if (list) return xp.getStringList(rule);
        return xp.getString(rule);
      case RuleMode.regex:
        final text = current?.toString() ?? '';
        final parts = RuleCompileCache.splitParts(rule, '&&');
        if (elements) {
          return AnalyzeByRegex.getElements(text, parts);
        }
        final one = AnalyzeByRegex.getElement(text, parts);
        return list ? one : (one.isEmpty ? '' : one.first);
      case RuleMode.css:
        final css = current == content
            ? (_css ??= AnalyzeByCss(current ?? ''))
            : AnalyzeByCss(current ?? '');
        if (elements) return css.getElements(rule);
        if (list) return css.getStringList(rule);
        return isUrl ? css.getString0(rule) : css.getString(rule);
    }
  }

  String _replaceRegex(String result, SourceRule rule) {
    if (rule.replaceRegex.isEmpty) return result;
    try {
      final re =
          RuleCompileCache.regex(rule.replaceRegex, dotAll: true) ??
          RegExp(rule.replaceRegex, dotAll: true);
      if (rule.replaceFirst) {
        final m = re.firstMatch(result);
        if (m == null) return '';
        return result.replaceFirstMapped(
          re,
          (m) => _expandDollars(m, rule.replacement),
        );
      }
      return result.replaceAllMapped(
        re,
        (m) => _expandDollars(m, rule.replacement),
      );
    } catch (_) {
      // Kotlin's fallback is String.replace(old, new), not a no-op.  This is
      // observable for malformed regex suffixes and keeps a field-local
      // replacement from leaking the original marker.
      return result.replaceAll(rule.replaceRegex, rule.replacement);
    }
  }

  static String _expandDollars(Match m, String replacement) {
    if (replacement.isEmpty) return '';
    return replacement.replaceAllMapped(RegExp(r'\$(\d+)'), (rm) {
      final i = int.tryParse(rm.group(1)!) ?? 0;
      if (i < 0 || i > m.groupCount) return '';
      return m.group(i) ?? '';
    });
  }

  List<SourceRule> splitSourceRule(String ruleStr, {bool allInOne = false}) {
    if (ruleStr.isEmpty) return [];
    final program = RuleCompileCache.program(
      ruleStr,
      isJson: isJson,
      isRegex: isRegex,
      allInOne: allInOne,
    );
    if (allInOne && ruleStr.startsWith(':')) isRegex = true;
    return [
      for (final step in program.steps) SourceRule(step.expression, step.mode),
    ];
  }

  bool _looksJson(String s) {
    final t = s.trimLeft();
    // JSON scalar roots are valid Legado documents too (for example a source
    // returning `"next"`), so do not restrict this check to object/array
    // delimiters.  The first-byte guard still avoids attempting a parse for
    // ordinary HTML/text responses.
    if (!(t.startsWith('{') ||
        t.startsWith('[') ||
        t.startsWith('"') ||
        t.startsWith('-') ||
        RegExp(r'\d').hasMatch(t) ||
        t.startsWith('true') ||
        t.startsWith('false') ||
        t.startsWith('null'))) {
      return false;
    }
    // Legado's String.isJson() validates the document rather than relying on
    // its first byte.  Avoid routing HTML fragments such as `{loading}` into
    // the JSONPath evaluator (which otherwise turns a CSS rule into an empty
    // result).
    try {
      final value = jsonDecode(s);
      return value != null;
    } catch (_) {
      return false;
    }
  }
}

class SourceRule {
  SourceRule(String ruleStr, [this.mode = RuleMode.css]) {
    var raw = ruleStr;
    if (mode == RuleMode.js || mode == RuleMode.regex) {
      rule = raw;
    } else if (raw.toLowerCase().startsWith('@css:')) {
      mode = RuleMode.css;
      rule = raw;
    } else if (raw.startsWith('@@')) {
      mode = RuleMode.css;
      rule = raw.substring(2);
    } else if (raw.toLowerCase().startsWith('@xpath:')) {
      mode = RuleMode.xpath;
      rule = raw.substring(7);
    } else if (raw.toLowerCase().startsWith('@json:')) {
      mode = RuleMode.json;
      rule = raw.substring(6);
    } else if (raw.startsWith(r'$.') || raw.startsWith(r'$[')) {
      mode = RuleMode.json;
      rule = raw;
    } else if (raw.startsWith('/') && mode != RuleMode.json) {
      mode = RuleMode.xpath;
      rule = raw;
    } else {
      rule = raw;
    }
    rule = _splitPut(rule);
  }

  RuleMode mode;
  String rule = '';
  String replaceRegex = '';
  String replacement = '';
  bool replaceFirst = false;
  Object? literalValue;
  final Map<String, String> putMap = {};

  String _splitPut(String input) {
    // Do not use `\{.*?\}` here: nested objects/arrays and a quoted `}` are
    // legal in a Legado put map.  A balanced scan is both faster than a
    // backtracking expression on large JS rules and matches the lexer used by
    // RuleAnalyzer for combinators.
    if (input.isEmpty) return input;
    final out = StringBuffer();
    var i = 0;
    while (i < input.length) {
      final isPut =
          i + 5 <= input.length &&
          input.substring(i, i + 5).toLowerCase() == '@put:';
      if (isPut && i + 5 < input.length && input[i + 5] == '{') {
        final end = RuleAnalyzer.balancedEnd(input, i + 5);
        if (end > i + 5 && end <= input.length) {
          final map = input.substring(i + 5, end);
          final decoded = _parsePutJson(map);
          // A syntactically valid empty map still denotes a put directive and
          // should be removed; malformed maps are retained as rule text.
          if (decoded.isNotEmpty || map.trim() == '{}') {
            putMap.addAll(decoded);
            i = end;
            continue;
          }
        }
      }
      out.write(input[i]);
      i++;
    }
    return out.toString();
  }

  Map<String, String> _parsePutJson(String raw) {
    final out = <String, String>{};
    final body = raw.trim();
    if (!body.startsWith('{')) return out;
    final inner = body.substring(1, body.lastIndexOf('}'));
    // Split only at top-level commas/colons so selectors and JS snippets may
    // legitimately contain either character.
    final entries = <String>[];
    var start = 0, depth = 0;
    var quote = '';
    for (var i = 0; i < inner.length; i++) {
      final c = inner[i];
      if (quote.isNotEmpty) {
        if (c == quote && !_isEscaped(inner, i)) quote = '';
      } else if (c == '"' || c == "'") {
        quote = c;
      } else if (c == '{' || c == '[' || c == '(') {
        depth++;
      } else if (c == '}' || c == ']' || c == ')') {
        if (depth > 0) depth--;
      } else if (c == ',' && depth == 0) {
        entries.add(inner.substring(start, i));
        start = i + 1;
      }
    }
    entries.add(inner.substring(start));
    for (final part in entries) {
      var split = -1;
      depth = 0;
      quote = '';
      for (var i = 0; i < part.length; i++) {
        final c = part[i];
        if (quote.isNotEmpty) {
          if (c == quote && !_isEscaped(part, i)) quote = '';
        } else if (c == '"' || c == "'") {
          quote = c;
        } else if (c == '{' || c == '[' || c == '(') {
          depth++;
        } else if (c == '}' || c == ']' || c == ')') {
          if (depth > 0) depth--;
        } else if (c == ':' && depth == 0) {
          split = i;
          break;
        }
      }
      if (split <= 0) continue;
      String clean(String s) {
        final t = s.trim();
        if (t.length >= 2 &&
            ((t.startsWith('"') && t.endsWith('"')) ||
                (t.startsWith("'") && t.endsWith("'")))) {
          final body = t.substring(1, t.length - 1);
          if (t.startsWith('"')) {
            // Decode JSON escapes when possible; Gson does the same on
            // Android and selectors frequently contain `\\"` or `\\n`.
            try {
              final decoded = jsonDecode(t);
              if (decoded is String) return decoded;
            } catch (_) {
              // Fall through to the conservative unescape below.
            }
          }
          return body
              .replaceAll(r'\\"', '"')
              .replaceAll(r"\\'", "'")
              .replaceAll(r'\\\\', r'\\');
        }
        return t;
      }

      out[clean(part.substring(0, split))] = clean(part.substring(split + 1));
    }
    return out;
  }

  static bool _isEscaped(String value, int index) {
    var slashes = 0;
    for (var i = index - 1; i >= 0 && value[i] == r'\'; i--) {
      slashes++;
    }
    return slashes.isOdd;
  }

  Future<void> makeUp(AnalyzeRule host, Object? result) async {
    var composed = rule;
    final directGet = _singleGetKey(composed.trim());
    if (directGet != null) {
      literalValue = host.get(directGet);
      rule = '';
      return;
    }
    composed = await _expandGetTokens(composed, host);
    // Embedded Legado rules are expressions, not placeholders to erase.  They
    // must be evaluated against the current result before the outer selector
    // is executed (e.g. {{@@.chapter@text}} and {{$.items[0].title}}).
    final sections = composed.split('##');
    final rawRule = sections.first;
    // Keep the replacement suffix while interpolating the selector. The
    // previous implementation rebuilt `composed` from `rawRule` and silently
    // dropped `##match##replacement`, which changed Legado content rules.
    final replacementSuffix = sections.length > 1
        ? '##${sections.skip(1).join('##')}'
        : '';
    final sb = StringBuffer();
    var last = 0;
    for (final token in _doubleBraceTokens(rawRule)) {
      sb.write(rawRule.substring(last, token.start));
      final inner = token.body.trim();
      if (_isRule(inner)) {
        final value = await host.getString(inner, mContent: result);
        if (token.start == 0 && token.end == rawRule.length) {
          literalValue = value;
        }
        sb.write(_stripRuleLeak(value));
      } else if (inner == 'key' ||
          inner == 'page' ||
          inner.startsWith('source.') ||
          inner.startsWith('book.')) {
        sb.write(await _evalSimple(host, inner, result));
      } else {
        final value = await host.evalJs(inner, result);
        sb.write(_stripRuleLeak(_stringifyJsValue(value)));
      }
      last = token.end;
    }
    sb.write(rawRule.substring(last));
    composed = sb.toString() + replacementSuffix;
    final parts = composed.split('##');
    rule = parts.first.trim();
    if (parts.length > 1) replaceRegex = parts[1];
    if (parts.length > 2) replacement = parts[2];
    if (parts.length > 3) replaceFirst = true;
  }

  /// 规则原文不许漏进正文。
  ///
  /// 「模板型书源」会把 `{{java.getString(...)}}` 这类内嵌规则写进简介/标题/章节名，
  /// 一旦求值失败（缺 `host` 这类源变量、或需要真 JS 虚拟机），旧实现会把**整段规则
  /// 原文**当成内容展示出来 —— 用户看到的就是
  /// 「读到：java.getString("$.data.freeContUrlPrefix"」。
  ///
  /// 这里兜底：求值结果**仍然长得像规则**，就按失败处理 —— 返回空串并留一条可见
  /// 告警，而不是把规则文本喂给读者。正文里出现 `{{`/`}}`/以 `java.` 开头的概率
  /// 趋近于零，误伤可以忽略。
  static String _stripRuleLeak(String value) {
    final t = value.trim();
    if (t.isEmpty) return value;
    final looksLikeRule =
        t.contains('{{') ||
        t.contains('}}') ||
        t.startsWith('java.') ||
        t.startsWith('@js:') ||
        t.startsWith('<js>');
    if (!looksLikeRule) return value;
    DebugLog.log(
      'AnalyzeRule',
      '规则求值结果仍是规则原文，按失败处理：${t.substring(0, t.length.clamp(0, 90))}',
      state: -1,
    );
    return '';
  }

  Future<String> _evalSimple(
    AnalyzeRule host,
    String inner,
    Object? result,
  ) async {
    if (inner == 'key') return result?.toString() ?? '';
    if (inner.startsWith('book.name')) return host.book?.name ?? '';
    if (inner.startsWith('book.author')) return host.book?.author ?? '';
    if (inner.startsWith('source.')) {
      final field = inner.substring(7);
      if (field == 'key' || field == 'bookSourceUrl') {
        return host.source?.bookSourceUrl ?? '';
      }
    }
    return _stringifyJsValue(await host.evalJs(inner, result));
  }

  /// Expands every balanced `@get:{...}` token.  A regex cannot distinguish a
  /// closing brace in a nested object/string from the token's closing brace.
  Future<String> _expandGetTokens(String input, AnalyzeRule host) async {
    if (input.isEmpty) return input;
    final out = StringBuffer();
    var i = 0;
    while (i < input.length) {
      final marker =
          i + 6 <= input.length &&
          input.substring(i, i + 6).toLowerCase() == '@get:{';
      if (marker) {
        final end = RuleAnalyzer.balancedEnd(input, i + 5);
        if (end > i + 5 && end <= input.length) {
          out.write(host.get(input.substring(i + 6, end - 1).trim()));
          i = end;
          continue;
        }
      }
      out.write(input[i]);
      i++;
    }
    return out.toString();
  }

  String? _singleGetKey(String input) {
    final t = input.trim();
    if (t.length < 7 || !t.substring(0, 6).toLowerCase().startsWith('@get:{')) {
      return null;
    }
    final end = RuleAnalyzer.balancedEnd(t, 5);
    if (end != t.length || end <= 5) return null;
    return t.substring(6, end - 1).trim();
  }

  List<_DoubleBraceToken> _doubleBraceTokens(String input) {
    final out = <_DoubleBraceToken>[];
    var i = 0;
    while (i + 1 < input.length) {
      if (input[i] != '{' || input[i + 1] != '{') {
        i++;
        continue;
      }
      final end = RuleAnalyzer.balancedEnd(input, i);
      if (end <= i + 3 ||
          end > input.length ||
          input[end - 2] != '}' ||
          input[end - 1] != '}') {
        i += 2;
        continue;
      }
      out.add(_DoubleBraceToken(i, end, input.substring(i + 2, end - 2)));
      i = end;
    }
    return out;
  }

  static String _stringifyJsValue(Object? value) {
    if (value == null) return '';
    if (value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toString();
  }

  bool _isRule(String s) {
    return s.startsWith('@') ||
        s.startsWith(r'$.') ||
        s.startsWith(r'$[') ||
        s.startsWith('//');
  }
}

class _DoubleBraceToken {
  const _DoubleBraceToken(this.start, this.end, this.body);
  final int start;
  final int end;
  final String body;
}
