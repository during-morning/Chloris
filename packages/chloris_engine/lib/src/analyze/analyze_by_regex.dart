/// Chained regex extraction matching legado `AnalyzeByRegex`.
///
/// `rule1&&rule2&&rule3`: each stage except the last concatenates all
/// full matches and feeds the next pattern. The last stage returns
/// capture groups per match.
class AnalyzeByRegex {
  static List<String> getElement(String content, List<String> regexes) {
    if (regexes.isEmpty) return [];
    return _element(content, regexes, 0) ?? [];
  }

  static List<List<String>> getElements(String content, List<String> regexes) {
    if (regexes.isEmpty) return [];
    return _elements(content, regexes, 0);
  }

  static List<String>? _element(String res, List<String> regs, int index) {
    final re = _compile(regs[index]);
    if (re == null) return null;
    final match = re.firstMatch(res);
    if (match == null) return null;
    if (index + 1 == regs.length) {
      return [for (var i = 0; i <= match.groupCount; i++) match.group(i) ?? ''];
    }
    final buf = StringBuffer(match.group(0) ?? '');
    for (final m in re.allMatches(res).skip(1)) {
      buf.write(m.group(0) ?? '');
    }
    return _element(buf.toString(), regs, index + 1);
  }

  static List<List<String>> _elements(String res, List<String> regs, int index) {
    final re = _compile(regs[index]);
    if (re == null) return [];
    final matches = re.allMatches(res).toList();
    if (matches.isEmpty) return [];
    if (index + 1 == regs.length) {
      return [
        for (final m in matches)
          [for (var i = 0; i <= m.groupCount; i++) m.group(i) ?? ''],
      ];
    }
    final buf = StringBuffer();
    for (final m in matches) {
      buf.write(m.group(0) ?? '');
    }
    return _elements(buf.toString(), regs, index + 1);
  }

  static RegExp? _compile(String raw) {
    final pattern = raw.trim();
    if (pattern.isEmpty) return null;
    try {
      // 对齐 Legado-E AnalyzeByRegex.kt:11 — `Pattern.compile(regs[index])` 无任何标志。
      // Java 默认：^/$ 只匹配整串首尾、`.` 不跨行。Chloris 原先的
      // `multiLine: true, dotAll: true` 会让同一条正则在真实站点多行正文上给出
      // 不同长度的结果且静默无提示，这是与 Legado 的非等价差异（见差异文档 §7 行 276）。
      // 需要跨行时 Legado 书源用 `[\s\S]` 而非 `.`，故直接去掉标志对齐默认语义。
      return RegExp(pattern);
    } catch (_) {
      return null;
    }
  }
}
