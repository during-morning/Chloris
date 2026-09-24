import 'rule_mode.dart';
import 'rule_analyzer.dart';

/// 规则的稳定中间表示。解析器只负责语法切分，执行器仍由 AnalyzeRule 负责。
class RuleProgram {
  const RuleProgram({required this.source, required this.steps});

  final String source;
  final List<RuleStep> steps;

  Map<String, Object?> toJson() => {
    'source': source,
    'steps': [for (final step in steps) step.toJson()],
  };
}

class RuleStep {
  const RuleStep({
    required this.mode,
    required this.expression,
    this.replaceRegex = '',
    this.replacement = '',
    this.replaceFirst = false,
    this.putMap = const {},
  });

  final RuleMode mode;
  final String expression;
  final String replaceRegex;
  final String replacement;
  final bool replaceFirst;
  final Map<String, String> putMap;

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'expression': expression,
    if (replaceRegex.isNotEmpty) 'replaceRegex': replaceRegex,
    if (replacement.isNotEmpty) 'replacement': replacement,
    if (replaceFirst) 'replaceFirst': true,
    if (putMap.isNotEmpty) 'put': putMap,
  };
}

/// Legado 规则 lexer/compiler。使用扫描游标而非多个 replace，避免 JS 代码
/// 中出现 `@webjs:`、正则括号或换行时破坏前后的 selector。
class RuleCompiler {
  const RuleCompiler();

  RuleProgram compile(
    String source, {
    bool isJson = false,
    bool isRegex = false,
    bool allInOne = false,
  }) {
    if (source.isEmpty) return RuleProgram(source: source, steps: const []);
    var baseMode = isJson ? RuleMode.json : RuleMode.css;
    var cursor = 0;
    if (allInOne && source.startsWith(':')) {
      baseMode = RuleMode.regex;
      cursor = 1;
    } else if (isRegex) {
      baseMode = RuleMode.regex;
    }
    final markers = _scanMarkers(source);
    final steps = <RuleStep>[];
    for (final marker in markers) {
      if (marker.start < cursor) continue;
      final prefix = source.substring(cursor, marker.start).trim();
      if (prefix.isNotEmpty)
        steps.add(RuleStep(mode: baseMode, expression: prefix));
      steps.add(
        RuleStep(mode: marker.mode, expression: marker.expression.trim()),
      );
      cursor = marker.end;
    }
    final tail = source.substring(cursor).trim();
    if (tail.isNotEmpty) steps.add(RuleStep(mode: baseMode, expression: tail));
    return RuleProgram(source: source, steps: List.unmodifiable(steps));
  }

  List<_Marker> _scanMarkers(String source) {
    final markers = <_Marker>[];
    var i = 0;
    while (i < source.length) {
      // Use the same balanced lexer as combinator splitting.  A marker in a
      // CSS attribute/pseudo argument or a template interpolation is literal
      // selector text, not a new JS step.
      final skip = RuleAnalyzer.skipUnit(source, i);
      if (skip != i) {
        i = skip;
        continue;
      }
      final lower = source.substring(i).toLowerCase();
      if (lower.startsWith('<js>')) {
        final endTag = lower.indexOf('</js>', 4);
        final end = endTag < 0 ? source.length : i + endTag + 5;
        final bodyEnd = endTag < 0 ? source.length : i + endTag;
        markers.add(
          _Marker(i, end, RuleMode.js, source.substring(i + 4, bodyEnd)),
        );
        i = end;
        continue;
      }
      // Keep parity with AppPattern.WebJS_PATTERN: a webjs body shorter than
      // five code units is not a marker and remains part of the selector.
      if (lower.startsWith('@webjs:') && source.length - (i + 7) >= 5) {
        markers.add(
          _Marker(i, source.length, RuleMode.webJs, source.substring(i + 7)),
        );
        break;
      }
      if (lower.startsWith('@js:')) {
        markers.add(
          _Marker(i, source.length, RuleMode.js, source.substring(i + 4)),
        );
        break;
      }
      i++;
    }
    return markers;
  }

  /// 编译一个带 Legado 前缀的单步规则，供 golden corpus 和外部工具使用。
  RuleStep compileStep(String source, {RuleMode fallback = RuleMode.css}) {
    var mode = fallback;
    var expression = source.trim();
    final lower = expression.toLowerCase();
    if (lower.startsWith('@css:')) {
      expression = expression.substring(5);
      mode = RuleMode.css;
    } else if (expression.startsWith('@@')) {
      expression = expression.substring(2);
      mode = RuleMode.css;
    } else if (lower.startsWith('@xpath:')) {
      expression = expression.substring(7);
      mode = RuleMode.xpath;
    } else if (lower.startsWith('@json:')) {
      expression = expression.substring(6);
      mode = RuleMode.json;
    } else if (expression.startsWith(r'$.') || expression.startsWith(r'$[')) {
      mode = RuleMode.json;
    } else if (expression.startsWith('/') && fallback != RuleMode.json) {
      mode = RuleMode.xpath;
    }
    return RuleStep(mode: mode, expression: expression);
  }
}

class _Marker {
  const _Marker(this.start, this.end, this.mode, this.expression);
  final int start;
  final int end;
  final RuleMode mode;
  final String expression;
}
