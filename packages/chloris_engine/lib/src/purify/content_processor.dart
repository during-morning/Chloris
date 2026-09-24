import '../debug/debug_log.dart';
import '../models/aux_entities.dart';
import '../models/book.dart';
import '../models/domain_protocol.dart';
import 'chinese_convert.dart';
import 'regex_watchdog.dart';

class BookContent {
  BookContent({
    required this.text,
    this.sameTitleRemoved = false,
    this.effectiveRules = const [],
  });

  final String text;
  final bool sameTitleRemoved;
  final List<ReplaceRule> effectiveRules;
}

class ContentProcessor {
  ContentProcessor({
    required this.bookName,
    required this.bookOrigin,
    this.titleRules = const [],
    this.contentRules = const [],
  });

  final String bookName;
  final String bookOrigin;
  List<ReplaceRule> titleRules;
  List<ReplaceRule> contentRules;

  factory ContentProcessor.forBook(
    Book book, {
    required List<ReplaceRule> allRules,
  }) {
    bool inScope(ReplaceRule r, bool title) {
      if (!r.isEnabled || !r.isValid) return false;
      if (title && !r.scopeTitle) return false;
      if (!title && !r.scopeContent) return false;
      // 对齐 legado ReplaceRuleDao.findEnabledByContentScope/TitleScope：
      // scope 为空 = 全适用；否则对书名/书源名做子串匹配；
      // excludeScope 非空且命中书名/书源名子串 → 排除。
      final scope = r.scope ?? '';
      if (scope.isNotEmpty &&
          !scope.contains(book.name) &&
          !scope.contains(book.origin)) {
        return false;
      }
      final exclude = r.excludeScope ?? '';
      if (exclude.contains(book.name) || exclude.contains(book.origin)) {
        return false;
      }
      return true;
    }

    return ContentProcessor(
      bookName: book.name,
      bookOrigin: book.origin,
      titleRules: allRules.where((r) => inScope(r, true)).toList(),
      contentRules: allRules.where((r) => inScope(r, false)).toList(),
    );
  }

  /// 标题规则只在主线程小文本上跑，async 化以复用看门狗。
  Future<String> processTitle(String title, {bool chineseConvert = false}) async {
    var t = title;
    for (final r in titleRules) {
      t = await _apply(t, r);
    }
    if (chineseConvert) t = ChineseConvert.s2t(t);
    return t;
  }

  /// 异步、带看门狗的正文处理（主线程调用方走这条路径）。
  ///
  /// 大文本的正则替换会丢进短命 isolate 受 [replaceWithWatchdog] 看门狗保护；
  /// 某条规则超时/异常时，[DomainError] 被 [_apply] 捕获后记录可见告警并
  /// 跳过该规则，继续后续规则（对齐 legado「超时禁用该规则」语义的 Chloris 版）。
  Future<BookContent> process({
    required Book book,
    required BookChapter chapter,
    required String content,
    bool useReplace = true,
  }) async {
    var text = content;
    var removed = false;
    if (content != 'null') {
      try {
        final title = RegExp.escape(chapter.title).replaceAll(r'\ ', r'\s*');
        final re = RegExp('^(\\s|\\p{P}|${RegExp.escape(book.name)})*$title(\\s)*');
        final m = re.firstMatch(text);
        if (m != null) {
          text = text.substring(m.end);
          removed = true;
        }
      } catch (_) {}
    }
    final used = <ReplaceRule>[];
    if (useReplace) {
      for (final r in contentRules) {
        final next = await _apply(text, r);
        if (next != text) used.add(r);
        text = next;
      }
    }
    text = resegment(text);
    return BookContent(text: text, sameTitleRemoved: removed, effectiveRules: used);
  }

  /// 同步、不带 isolate 看门狗的正文处理。
  ///
  /// 仅供**已处于独立 isolate 之外**的调用方使用（目前是 [ChapterPipeline]
  /// 经 Flutter `compute` 跑在 worker isolate 里的路径）——此时主线程本就
  /// 不会被卡住，再包一层 isolate 既浪费又无法 `compute` 同步回调返回，故
  /// 直接同步执行，仅对单条规则的异常做「跳过」保护。
  BookContent processSync({
    required Book book,
    required BookChapter chapter,
    required String content,
    bool useReplace = true,
  }) {
    var text = content;
    var removed = false;
    if (content != 'null') {
      try {
        final title = RegExp.escape(chapter.title).replaceAll(r'\ ', r'\s*');
        final re = RegExp('^(\\s|\\p{P}|${RegExp.escape(book.name)})*$title(\\s)*');
        final m = re.firstMatch(text);
        if (m != null) {
          text = text.substring(m.end);
          removed = true;
        }
      } catch (_) {}
    }
    final used = <ReplaceRule>[];
    if (useReplace) {
      for (final r in contentRules) {
        final next = _applySync(text, r);
        if (next != text) used.add(r);
        text = next;
      }
    }
    text = resegment(text);
    return BookContent(text: text, sameTitleRemoved: removed, effectiveRules: used);
  }

  /// 自动排版：去空行、段首补缩进（[indent] 个全角空格，对齐 legado
  /// `ReadBookConfig.paragraphIndent` 可配字符数；0 = 不缩进）。
  ///
  /// 这是公开的 —— [ChapterPipeline.run] 在「没有替换规则」时也要做同样的排版，
  /// 否则缩进只在配了替换规则的书上生效，表现成「有的书有缩进、有的没有」。
  ///
  /// [paragraphGap] 是段与段之间的分隔。[replace] 路径保持单个 `\n`（对齐 Legado，
  /// 它的正文段落分隔就是单换行）；而阅读器那条**没有替换规则**的路径原先来自
  /// `htmlToPlain`，段间是 `\n\n`（空行）——若这里也压成 `\n`，段与段之间就没有了
  /// 视觉间隔，整章挤成一坨。这是实际踩过的坑，两个调用方必须各自传对。
  static String resegment(
    String input, {
    String paragraphGap = '\n',
    int indent = 2,
  }) {
    final pad = indent > 0 ? '　' * indent : '';
    return input
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) {
          if (l.startsWith('<img') || l.startsWith('http')) return l;
          if (pad.isEmpty) return l;
          return l.startsWith('　') ? l : '$pad$l';
        })
        .join(paragraphGap);
  }

  /// 单条规则的替换（async，走看门狗）。规则超时/异常时按 legado 语义跳过。
  Future<String> _apply(String input, ReplaceRule rule) async {
    try {
      return await replaceWithWatchdog(
        input: input,
        pattern: rule.pattern,
        replacement: rule.replacement,
        isRegex: rule.isRegex,
        timeout: Duration(milliseconds: rule.timeoutMillisecond),
        ruleName: rule.name,
      );
    } on DomainError catch (e) {
      // 对齐 legado「超时/异常则禁用该规则」：记录可见告警并跳过，继续后续规则。
      DebugLog.error(
        'replace',
        '替换规则「${rule.name}」已跳过（${e.code}）：${e.message}',
      );
      return input;
    }
  }

  /// [_apply] 的同步版，供 [processSync]（已在 isolate 外）使用。
  String _applySync(String input, ReplaceRule rule) {
    try {
      if (!rule.isRegex) {
        return input.replaceAll(rule.pattern, rule.replacement);
      }
      final re = RegExp(rule.pattern, multiLine: true);
      if (rule.replacement.startsWith('@js:')) {
        return input; // JS replace needs runtime; skipped in processor
      }
      return input.replaceAll(re, rule.replacement);
    } catch (e) {
      DebugLog.error(
        'replace',
        '替换规则「${rule.name}」已跳过（regex_invalid）：$e',
      );
      return input;
    }
  }
}
