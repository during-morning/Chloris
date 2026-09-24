/// Split legado combinators `&&` `||` `%%` and `@` without breaking
/// quotes, brackets, or JSONPath filters.
class RuleAnalyzer {
  /// [code] mirrors Legado's code-balanced mode.  The Dart scanner uses the
  /// same quote/bracket rules for both modes, but keeping the flag in the
  /// public constructor makes callers which share rules with Legado source
  /// compatible without a second parser allocation.
  RuleAnalyzer(this.data, [this.code = false]);

  final String data;
  final bool code;
  String elementsType = '';

  /// Skip one lexical unit that can contain a rule combinator.
  ///
  /// Legado rules routinely embed quoted JSONPath predicates, CSS pseudo
  /// selectors, regular-expression groups and JavaScript template literals.
  /// Keeping this scanner in one place prevents the splitters from treating
  /// an `&&`, `||`, `%%` or `@` inside one of those units as a top-level
  /// combinator.  The return value is the first index after the unit, or
  /// [index] when the character does not start a protected unit.
  static int skipUnit(String s, int index) {
    if (index < 0 || index >= s.length) return index;
    final c = s[index];
    if (c == "'" || c == '"') return _skipQuoted(s, index, c);
    if (c == '`') return _skipTemplate(s, index);
    if (c == '[' || c == '(' || c == '{') {
      return _skipBalanced(s, index);
    }
    return index;
  }

  /// Return the first index after the balanced group beginning at [index].
  /// Returns [index] when no group starts there, and `s.length` for an
  /// unterminated group.  Keeping this operation public (rather than
  /// duplicating a regex) lets `SourceRule` parse nested `@put:{...}` values
  /// with exactly the same lexer used for combinators.
  static int balancedEnd(String s, int index) =>
      _isGroupStart(s, index) ? _skipBalanced(s, index) : index;

  static bool _isGroupStart(String s, int index) {
    if (index < 0 || index >= s.length) return false;
    final c = s[index];
    return c == '[' || c == '(' || c == '{';
  }

  List<String> splitRule(List<String> seps) {
    if (data.isEmpty) return [];
    final found = _findSep(data, seps);
    if (found == null) {
      elementsType = '';
      return [data];
    }
    elementsType = found.sep;
    return _splitAll(data, found.sep);
  }

  List<String> splitAt() => splitRule(const ['@']);

  _Found? _findSep(String input, List<String> seps) {
    var i = 0;
    while (i < input.length) {
      final skip = skipUnit(input, i);
      if (skip != i) {
        i = skip;
        continue;
      }
      for (final sep in seps) {
        if (input.startsWith(sep, i)) {
          return _Found(i, sep);
        }
      }
      i++;
    }
    return null;
  }

  List<String> _splitAll(String input, String sep) {
    final out = <String>[];
    var start = 0;
    var i = 0;
    while (i < input.length) {
      final skip = skipUnit(input, i);
      if (skip != i) {
        i = skip;
        continue;
      }
      if (input.startsWith(sep, i)) {
        out.add(input.substring(start, i));
        i += sep.length;
        start = i;
        continue;
      }
      i++;
    }
    out.add(input.substring(start));
    return out.where((e) => e.isNotEmpty).toList();
  }

  static int _skipQuoted(String s, int i, String quote) {
    var j = i + 1;
    while (j < s.length) {
      if (s[j] == r'\') {
        // A backslash quotes the next code unit, including a quote or
        // another backslash.  Do not run past the end for a dangling slash.
        j += j + 1 < s.length ? 2 : 1;
        continue;
      }
      if (s[j] == quote) return j + 1;
      j++;
    }
    return s.length;
  }

  static int _skipTemplate(String s, int i) {
    var j = i + 1;
    while (j < s.length) {
      final c = s[j];
      if (c == r'\') {
        j += j + 1 < s.length ? 2 : 1;
        continue;
      }
      if (c == '`') return j + 1;
      if (c == r'$' && j + 1 < s.length && s[j + 1] == '{') {
        // Interpolations may contain nested groups and quoted strings.  They
        // are still part of the template literal and must not expose a
        // combinator to the outer rule splitter.
        j = _skipBalanced(s, j + 1);
        continue;
      }
      j++;
    }
    return s.length;
  }

  static int _skipBalanced(String s, int i) {
    final closers = <String, String>{'[': ']', '(': ')', '{': '}'};
    final stack = <String>[];
    final first = s[i];
    final firstClose = closers[first];
    if (firstClose == null) return i;
    stack.add(firstClose);
    var j = i + 1;
    while (j < s.length) {
      final c = s[j];
      if (c == "'" || c == '"') {
        j = _skipQuoted(s, j, c);
        continue;
      }
      if (c == '`') {
        j = _skipTemplate(s, j);
        continue;
      }
      final nestedClose = closers[c];
      if (nestedClose != null) {
        stack.add(nestedClose);
        j++;
        continue;
      }
      if (stack.isNotEmpty && c == stack.last) {
        stack.removeLast();
        j++;
        if (stack.isEmpty) return j;
        continue;
      }
      j++;
    }
    // Preserve the historical forgiving behavior for malformed rules: an
    // unclosed group consumes the remainder instead of splitting mid-group.
    return s.length;
  }
}

class _Found {
  _Found(this.index, this.sep);
  final int index;
  final String sep;
}
