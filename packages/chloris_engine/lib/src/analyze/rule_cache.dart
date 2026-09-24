/// Small LRU for compiled regexes, split rules, and rule programs.
import 'rule_analyzer.dart';
import 'rule_ir.dart';

class RuleCompileCache {
  static const int maxEntries = 256;
  static final Map<String, RegExp> _regex = {};
  static final Map<String, List<String>> _split = {};
  static final Map<String, RuleProgram> _programs = {};
  // Generic, backend-typed cache for rule-dependent parse products that are
  // neither a single RegExp nor a split result — e.g. parsed XPath step specs,
  // CSS index rules or CSS :contains predicate trees.  Callers own the type:
  // `getProduct` returns `Object?` and is cast back at the call site.  Keys
  // MUST be prefixed with `<backend>:` (and the rule text) so products from
  // different backends never collide, e.g. `'xpath:steps:$path'`.
  static final Map<String, Object> _products = {};

  static RegExp? regex(
    String pattern, {
    bool multiLine = true,
    bool dotAll = false,
    bool caseSensitive = true,
  }) {
    final key = '$multiLine|$dotAll|$caseSensitive|$pattern';
    final hit = _regex.remove(key);
    if (hit != null) {
      // Map insertion order is used by [_put] for eviction.  Reinsert hits so
      // this is an actual LRU instead of FIFO; hot source rules stay compiled
      // while one-off rules are evicted first.
      _regex[key] = hit;
      return hit;
    }
    try {
      final compiled = RegExp(
        pattern,
        multiLine: multiLine,
        dotAll: dotAll,
        caseSensitive: caseSensitive,
      );
      _put(_regex, key, compiled);
      return compiled;
    } catch (_) {
      return null;
    }
  }

  static List<String> splitParts(String rule, String sep) {
    final key = '$sep|$rule';
    final hit = _split.remove(key);
    if (hit != null) {
      _split[key] = hit;
      return hit;
    }
    // Use the same quote/bracket-aware lexer as CSS/XPath/JSONPath. Regex
    // groups and JSONPath filters may legally contain `&&`; only separators
    // at the current expression level split a rule.
    final parts = RuleAnalyzer(rule).splitRule([sep]);
    _put(_split, key, parts);
    return parts;
  }

  static RuleProgram program(
    String source, {
    bool isJson = false,
    bool isRegex = false,
    bool allInOne = false,
  }) {
    final key = '$isJson|$isRegex|$allInOne|$source';
    final hit = _programs.remove(key);
    if (hit != null) {
      _programs[key] = hit;
      return hit;
    }
    final compiled = const RuleCompiler().compile(
      source,
      isJson: isJson,
      isRegex: isRegex,
      allInOne: allInOne,
    );
    _put(_programs, key, compiled);
    return compiled;
  }

  static void clear() {
    _regex.clear();
    _split.clear();
    _programs.clear();
    _products.clear();
  }

  /// Fetch a previously cached backend parse product (cast at the call site).
  static Object? getProduct(String key) {
    final hit = _products.remove(key);
    if (hit != null) {
      _products[key] = hit;
      return hit;
    }
    return null;
  }

  /// Store a backend parse product under [key] (callers prefix it with the
  /// backend name and the rule text to avoid collisions).
  static void putProduct(String key, Object value) {
    _put(_products, key, value);
  }

  static void _put<T>(Map<String, T> map, String key, T value) {
    if (map.length >= maxEntries) {
      map.remove(map.keys.first);
    }
    map[key] = value;
  }
}
