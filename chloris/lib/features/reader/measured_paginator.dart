import 'dart:collection';

import 'package:flutter/painting.dart';
import 'package:chloris_engine/chloris_engine.dart';

import 'reader_controller.dart';

/// TextPainter-based pagination used by the reader.
class MeasuredPaginator {
  /// 段落测量缓存：段落哈希 + 全部影响排版的参数 → 折行后的行。
  ///
  /// 同一段落在「预览分页 → 增量续排 / 字号微调回退 / 双页切换」等重排场景
  /// 会被反复测量；TextPainter.layout + computeLineMetrics 是排版热路径的
  /// 大头。静态缓存跨会话命中，容量封顶防泄漏。
  static const int _measureCacheCap = 800;
  static const int _measureCacheMaxChars = 4 * 1024 * 1024;
  static final LinkedHashMap<_MeasureKey, List<_MeasuredLine>> _measureCache =
      LinkedHashMap<_MeasureKey, List<_MeasuredLine>>();
  static int _measureCacheChars = 0;

  static _MeasureKey _cacheKey(
    String para,
    double width,
    TextStyle style,
    TextScaler textScaler,
  ) => (para, width, style, textScaler);

  static List<_MeasuredLine>? _measureCacheGet(
    String para,
    double w,
    TextStyle style,
    TextScaler textScaler,
  ) {
    final key = _cacheKey(para, w, style, textScaler);
    final hit = _measureCache.remove(key);
    if (hit == null) return null;
    // 重新插入以刷新 LRU 位置
    _measureCache[key] = hit;
    return hit;
  }

  static void _measureCachePut(
    String para,
    double w,
    TextStyle style,
    TextScaler textScaler,
    List<_MeasuredLine> lines,
  ) {
    final key = _cacheKey(para, w, style, textScaler);
    final old = _measureCache.remove(key);
    if (old != null) {
      _measureCacheChars -= para.length;
    }
    _measureCache[key] = lines;
    _measureCacheChars += para.length;
    while (_measureCache.length > _measureCacheCap ||
        _measureCacheChars > _measureCacheMaxChars) {
      final oldest = _measureCache.keys.first;
      _measureCacheChars -= oldest.$1.length;
      _measureCache.remove(oldest);
    }
  }

  static PaginatedChapter layout({
    required String content,
    required double width,
    required double height,
    required TextStyle style,
    TextScaler textScaler = TextScaler.noScaling,
    double paragraphSpacing = 8,
    int? maxChars,
    double? firstPageHeight,
    int startOffset = 0,
  }) {
    final w = width <= 1 ? 360.0 : width;
    final h = height <= 1 ? 640.0 : height;
    var pageH = firstPageHeight == null ? h : firstPageHeight.clamp(80.0, h);
    if (content.isEmpty) {
      return PaginatedChapter(
        content: '',
        pages: const [],
        totalChars: 0,
        consumedChars: 0,
      );
    }
    var work = content.replaceAll(RegExp(r'\r\n?'), '\n');
    final offset = startOffset.clamp(0, work.length);
    if (maxChars != null && work.length > maxChars) {
      var cut = maxChars;
      final nl = work.lastIndexOf('\n', cut);
      if (nl >= (maxChars * 0.6).floor()) cut = nl;
      work = work.substring(0, cut);
    }

    final pages = <TextPage>[];
    var lines = <String>[];
    var used = 0.0;
    var start = offset;
    var pos = 0;

    void flush() {
      if (lines.isEmpty) return;
      pages.add(
        TextPage(
          index: pages.length,
          lines: List<String>.from(lines),
          startPos: start,
          endPos: pos,
        ),
      );
      lines = <String>[];
      used = 0;
      start = pos;
      pageH = h;
    }

    List<_MeasuredLine> wrapParagraph(String para) {
      if (para.trim().isEmpty) {
        return const <_MeasuredLine>[];
      }

      final fontSize = style.fontSize ?? 18;
      // 布局缓存优先：同段落 + 同排版参数直接复用折行结果。
      final cached = _measureCacheGet(para, w, style, textScaler);
      if (cached != null) return cached;

      // Layout each paragraph once. ComputeLineMetrics is the source of truth
      // for visual rows: selection boxes may be split by fallback-font runs
      // within one CJK line and must not be treated as additional lines.
      final painter = TextPainter(
        text: TextSpan(text: para, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        strutStyle: StrutStyle(
          fontSize: fontSize,
          height: style.height,
          forceStrutHeight: true,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      )..layout(maxWidth: w);
      try {
        final metrics = painter.computeLineMetrics();
        if (metrics.isEmpty) {
          final lines = <_MeasuredLine>[_MeasuredLine(para, fontSize)];
          _measureCachePut(para, w, style, textScaler, lines);
          return lines;
        }

        final raw = <_MeasuredLine>[];
        var charOffset = 0;
        for (var i = 0; i < metrics.length && charOffset < para.length; i++) {
          final nextTop = i + 1 < metrics.length
              ? metrics[i + 1].baseline - metrics[i + 1].ascent
              : double.infinity;
          final end = _exclusiveLineEnd(
            painter: painter,
            start: charOffset,
            textLen: para.length,
            nextLineTop: nextTop,
          );
          raw.add(
            _MeasuredLine(
              para.substring(charOffset, end).replaceAll('\n', ''),
              metrics[i].height,
            ),
          );
          charOffset = end;
        }
        if (charOffset < para.length) {
          raw.add(
            _MeasuredLine(para.substring(charOffset), metrics.last.height),
          );
        }
        final tidy = _tidyCjkLines(raw);
        _measureCachePut(para, w, style, textScaler, tidy);
        return tidy;
      } finally {
        painter.dispose();
      }
    }

    final paragraphs = work
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    var needGap = false;
    // 增量续排：startOffset 之前的段落只推进位置、不重复测量渲染。
    // 调用方保证 startOffset 落在段落边界（maxChars 截断点在 \n 处）。
    for (
      var paragraphIndex = 0;
      paragraphIndex < paragraphs.length;
      paragraphIndex++
    ) {
      final para = paragraphs[paragraphIndex];
      final hasNewline = paragraphIndex < paragraphs.length - 1;
      final paraSpan = para.length + (hasNewline ? 1 : 0);
      final paraStart = pos;
      final paraEnd = pos + paraSpan;
      if (paraEnd <= offset) {
        // 整段在续排起点之前：跳过。
        if (para.trim().isNotEmpty) needGap = true;
        pos = paraEnd;
        continue;
      }
      final localOffset = (offset - paraStart).clamp(0, para.length);
      final remaining = para.substring(localOffset);
      pos = paraStart + localOffset;
      if (remaining.isEmpty && hasNewline) {
        // The preview consumed all paragraph text and stopped immediately
        // before its newline. Advance over that separator exactly once.
        pos++;
        if (para.trim().isNotEmpty) needGap = true;
        continue;
      }
      if (remaining.trim().isEmpty) {
        needGap = lines.isNotEmpty;
        pos = paraEnd;
        continue;
      }
      if (needGap && paragraphSpacing > 0 && lines.isNotEmpty) {
        if (used + paragraphSpacing > pageH) flush();
        if (lines.isNotEmpty) {
          lines.add('');
          used += paragraphSpacing;
        }
      }
      needGap = true;
      // A continuation inside a paragraph has no paragraph gap at its start.
      if (localOffset > 0) needGap = false;
      final wrapped = wrapParagraph(remaining);
      for (var i = 0; i < wrapped.length; i++) {
        final line = wrapped[i].text;
        final lh = wrapped[i].height;
        if (line.trim().isEmpty) {
          pos += line.length;
          continue;
        }
        if (used > 0 && used + lh > pageH) flush();
        lines.add(line);
        used += lh;
        pos += line.length;
      }
      if (hasNewline) pos += 1; // the paragraph newline
    }
    flush();
    if (pages.isEmpty && offset == 0) {
      pages.add(
        TextPage(index: 0, lines: [work], startPos: 0, endPos: content.length),
      );
    }
    return PaginatedChapter(
      content: work,
      pages: pages,
      totalChars: work.length,
      consumedChars: pos,
    );
  }
}

typedef _MeasureKey = (String, double, TextStyle, TextScaler);

/// Collapse blank / whitespace-only lines so `\n\n` and `　　\n` do not paint
/// as extra full-height rows in scroll mode.
String collapseReaderBlankLines(String text) {
  return text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'(?:[ \t\u00a0\u3000]*\n){2,}'), '\n');
}

class _MeasuredLine {
  const _MeasuredLine(this.text, this.height);

  final String text;
  final double height;
}

/// Punctuation that must not start a line (kinsoku / 行首禁则).
const _cjkNoLineStart = '。，、；：！？）》」』】〉…—–-,."”’';

/// Opening marks that should not end a line.
const _cjkNoLineEnd = '（《「『【〈“‘';

int _exclusiveLineEnd({
  required TextPainter painter,
  required int start,
  required int textLen,
  required double nextLineTop,
}) {
  if (start >= textLen) return textLen;
  if (!nextLineTop.isFinite) return textLen;
  var lo = start + 1;
  var hi = textLen;
  var end = textLen;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    final dy = painter
        .getOffsetForCaret(TextPosition(offset: mid), Rect.zero)
        .dy;
    if (dy >= nextLineTop - 0.5) {
      end = mid;
      hi = mid - 1;
    } else {
      lo = mid + 1;
    }
  }
  if (end <= start) return (start + 1).clamp(1, textLen);
  return end;
}

/// Pulls line-start punctuation and leftover single glyphs back onto the
/// previous line so CJK pages do not show `。` or a lone `法` as their own row.
List<String> tidyCjkLineStrings(List<String> lines) {
  return _tidyCjkLines([
    for (final line in lines) _MeasuredLine(line, 20),
  ]).map((e) => e.text).toList();
}

List<_MeasuredLine> _tidyCjkLines(List<_MeasuredLine> raw) {
  if (raw.length <= 1) return raw;
  final out = <_MeasuredLine>[];
  for (final line in raw) {
    var text = line.text;
    if (text.isEmpty || out.isEmpty) {
      out.add(line);
      continue;
    }
    while (text.isNotEmpty && _cjkNoLineStart.contains(text[0])) {
      final prev = out.removeLast();
      out.add(_MeasuredLine(prev.text + text[0], prev.height));
      text = text.substring(1);
    }
    if (text.isEmpty) continue;
    if (text.length == 1 &&
        !_cjkNoLineStart.contains(text) &&
        out.last.text.length >= 2 &&
        !_cjkNoLineEnd.contains(out.last.text[out.last.text.length - 1])) {
      final prev = out.removeLast();
      final steal = prev.text[prev.text.length - 1];
      out.add(
        _MeasuredLine(
          prev.text.substring(0, prev.text.length - 1),
          prev.height,
        ),
      );
      text = steal + text;
    }
    if (out.isNotEmpty &&
        out.last.text.isNotEmpty &&
        _cjkNoLineEnd.contains(out.last.text[out.last.text.length - 1])) {
      final prev = out.removeLast();
      text = prev.text[prev.text.length - 1] + text;
      final kept = prev.text.substring(0, prev.text.length - 1);
      if (kept.isNotEmpty) out.add(_MeasuredLine(kept, prev.height));
    }
    out.add(_MeasuredLine(text, line.height));
  }
  return out;
}
