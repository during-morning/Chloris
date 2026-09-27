import 'dart:typed_data';

import '../constants/constants.dart';
import '../js/js_runtime.dart';
import '../models/aux_entities.dart';
import '../models/book.dart';
import 'encoding_detect.dart';

class TextFile {
  TextFile(this.book, this.bytes) {
    book.charset ??= EncodingDetect.getEncode(bytes);
    content = EncodingDetect.decode(bytes, book.charset!);
    if (content.startsWith('\uFEFF')) {
      content = content.substring(1);
    }
  }

  final Book book;
  final Uint8List bytes;
  late String content;

  static const overRuleCount = 2;

  List<BookChapter> getChapterList(List<TxtTocRule> rules) {
    if (content.trim().isEmpty) throw StateError('空 TXT 文件');
    TxtTocRule? chosen;
    if (book.tocUrl.isNotEmpty) {
      // book.tocUrl 里存的是「规则<joiner>标题净化JS」，与 legado 的 rule+replacement 对应。
      final parts = book.tocUrl.split(AppPattern.txtTocJoiner);
      chosen = TxtTocRule(
        rule: parts.first,
        replacement: parts.length > 1 ? parts[1] : '',
      );
    } else {
      chosen = _pickRule(rules);
      book.tocUrl = chosen == null || chosen.rule.isEmpty
          ? ''
          : '${chosen.rule}${AppPattern.txtTocJoiner}${chosen.replacement}';
    }
    final chapters = chosen == null || chosen.rule.isEmpty
        ? _bySize()
        : _byRegex(chosen);
    for (var i = 0; i < chapters.length; i++) {
      chapters[i].index = i;
      chapters[i].bookUrl = book.bookUrl;
      chapters[i].url = '${book.bookUrl}#$i';
    }
    book.totalChapterNum = chapters.length;
    if (chapters.isNotEmpty) {
      book.durChapterTitle ??= chapters.first.title;
      book.latestChapterTitle = chapters.last.title;
    }
    return chapters;
  }

  String getContent(BookChapter chapter) {
    final start = (chapter.start ?? 0).clamp(0, content.length);
    final end = (chapter.end ?? content.length).clamp(0, content.length);
    var text = content.substring(start, end);
    return text.replaceFirst(RegExp(r'^[\n\s]+'), '　　');
  }

  /// 规则评选：对齐 legado TextFile.getTocRule（TextFile.kt:497-535）。
  ///
  /// 对每条启用规则按 MULTILINE 试跑：
  /// - 两次匹配间隔 >1000 字（或首个匹配）计入正样本 csNum；
  /// - 间隔 <100 字视为误报 numE（多半是「卷」或导航行）；
  /// - 仅当 csNum >= numE*3 且 csNum > maxNum+2 时刷新最优；
  /// - 累计章节 >70 提前收敛（排前的规则已足够可信）。
  TxtTocRule? _pickRule(List<TxtTocRule> rules) {
    // 只采样前缀，避免超长 TXT 对每条规则都跑全量正文。
    final sample = content.length > 120000 ? content.substring(0, 120000) : content;
    var maxNum = -1;
    TxtTocRule? best;
    for (final r in rules.where((e) => e.enable)) {
      final RegExp re;
      try {
        re = RegExp(r.rule, multiLine: true);
      } catch (_) {
        continue;
      }
      var start = 0;
      var csNum = 0;
      var numE = 0;
      var lineStartMatches = 0;
      for (final m in re.allMatches(sample)) {
        final lineStart = m.start == 0
            ? 0
            : sample.lastIndexOf('\n', m.start - 1) + 1;
        if (sample.substring(lineStart, m.start).trim().isEmpty) {
          lineStartMatches++;
        }
        final contentLength = m.start - start;
        if (start == 0 || contentLength > 1000) {
          csNum++;
          start = m.end;
        } else if (contentLength < 100) {
          numE++;
        }
      }
      // Short TXT files can contain perfectly valid chapter headings less
      // than 100 characters apart. In that case prefer repeated headings on
      // their own lines over the distance-only false-positive filter.
      final repeatedLineHeadings = lineStartMatches >= 3 &&
          lineStartMatches > numE;
      if ((csNum >= numE * 3 || repeatedLineHeadings) &&
          (csNum > maxNum + overRuleCount ||
              (repeatedLineHeadings && lineStartMatches > maxNum))) {
        maxNum = csNum;
        best = r;
        if (maxNum > 70) break;
      }
    }
    return best;
  }

  /// 按规则切章：对齐 legado 的行为——
  /// - 首个匹配之前若有正文，生成「前言」章节而不是丢弃；
  /// - 标题经过 rule.replacement 的 JS 净化（result/index/prevTitle/prevLength 绑定）。
  List<BookChapter> _byRegex(TxtTocRule rule) {
    final re = RegExp(rule.rule, multiLine: true);
    final matches = re.allMatches(content).toList();
    if (matches.length < 3) return _bySize();
    final chapters = <BookChapter>[];
    final prologue = content.substring(0, matches.first.start);
    if (prologue.trim().isNotEmpty) {
      chapters.add(
        BookChapter(
          url: '',
          title: _purifyTitle('前言', rule, 0, null, prologue.length),
          start: 0,
          end: matches.first.start,
        ),
      );
    }
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final end = i + 1 < matches.length ? matches[i + 1].start : content.length;
      chapters.add(
        BookChapter(
          url: '',
          title: _purifyTitle(
            m.group(0)!.trim(),
            rule,
            chapters.length,
            i > 0 ? matches[i - 1].group(0)?.trim() : null,
            end - m.start,
          ),
          start: m.start,
          end: end,
        ),
      );
    }
    return chapters;
  }

  /// 标题净化：绑定与 legado TextFile.evalJs 一致
  /// （result=原标题, index=章序, prevTitle, prevLength）。
  /// JS 求值失败时保留原标题——目录识别不能因为净化脚本挂掉。
  String _purifyTitle(
    String title,
    TxtTocRule rule,
    int index,
    String? prevTitle,
    int prevLength,
  ) {
    final js = rule.replacement.trim();
    if (js.isEmpty) return title;
    try {
      final out = LenientJsRuntime.interpretJs(
        js,
        JsScope(variables: <String, Object?>{
          'result': title,
          'index': index + 1,
          'prevTitle': prevTitle,
          'prevLength': prevLength,
        }),
      );
      final s = out?.toString().trim();
      if (s != null && s.isNotEmpty) return s;
    } catch (_) {}
    return title;
  }

  List<BookChapter> _bySize() {
    final chapters = <BookChapter>[];
    var i = 0;
    var index = 0;
    while (i < content.length) {
      var end = (i + 4000).clamp(0, content.length);
      final nl = content.lastIndexOf('\n', end);
      if (nl > i + 800) end = nl;
      chapters.add(
        BookChapter(
          url: '',
          title: '第${index + 1}章',
          start: i,
          end: end,
        ),
      );
      i = end;
      if (i < content.length && content[i] == '\n') i++;
      index++;
    }
    return chapters;
  }
}
