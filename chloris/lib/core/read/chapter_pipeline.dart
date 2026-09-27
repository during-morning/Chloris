import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

String chapterPipelineIsolate(Map<String, Object?> args) {
  final rawRules = args['rules'];
  return ChapterPipeline.run(
    content: args['content'] as String? ?? '',
    bookTitle: args['bookTitle'] as String? ?? '',
    bookAuthor: args['bookAuthor'] as String? ?? '',
    chapterTitle: args['chapterTitle'] as String? ?? '',
    enableReplace: args['enableReplace'] == true,
    replaceRules: rawRules is List
        ? [
            for (final r in rawRules)
              if (r is Map) ReplaceRule.fromJson(Map<String, dynamic>.from(r)),
          ]
        : const [],
    chineseConvert: args['chineseConvert'] == true,
    paragraphIndent: (args['paragraphIndent'] as num?)?.toInt() ?? 2,
  );
}

/// One-shot chapter text: replace → convert → HTML to plain. Not for [build].
class ChapterPipeline {
  const ChapterPipeline._();

  static const offMainChars = 4000;
  static final RegExp _lineSeparators = RegExp(
    r'\r\n|[\r\n\u000b\u000c\u001c-\u001e\u0085\u2028\u2029]',
  );

  static Future<String> runOffMain({
    required String content,
    required String bookTitle,
    required String bookAuthor,
    required String chapterTitle,
    required bool enableReplace,
    required List<ReplaceRule> replaceRules,
    required bool chineseConvert,
    int paragraphIndent = 2,
  }) async {
    if (content.length < offMainChars) {
      return run(
        content: content,
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
        chapterTitle: chapterTitle,
        enableReplace: enableReplace,
        replaceRules: replaceRules,
        chineseConvert: chineseConvert,
        paragraphIndent: paragraphIndent,
      );
    }
    try {
      return await compute(chapterPipelineIsolate, <String, Object?>{
        'content': content,
        'bookTitle': bookTitle,
        'bookAuthor': bookAuthor,
        'chapterTitle': chapterTitle,
        'enableReplace': enableReplace,
        'rules': [for (final r in replaceRules) r.toJson()],
        'chineseConvert': chineseConvert,
        'paragraphIndent': paragraphIndent,
      });
    } catch (_) {
      return run(
        content: content,
        bookTitle: bookTitle,
        bookAuthor: bookAuthor,
        chapterTitle: chapterTitle,
        enableReplace: enableReplace,
        replaceRules: replaceRules,
        chineseConvert: chineseConvert,
        paragraphIndent: paragraphIndent,
      );
    }
  }

  static String run({
    required String content,
    required String bookTitle,
    required String bookAuthor,
    required String chapterTitle,
    required bool enableReplace,
    required List<ReplaceRule> replaceRules,
    required bool chineseConvert,
    int paragraphIndent = 2,
  }) {
    var text = content;
    if (enableReplace && replaceRules.isNotEmpty) {
      final book = Book(
        bookUrl: bookTitle,
        name: bookTitle,
        author: bookAuthor,
        origin: '',
      );
      final ch = BookChapter(url: '', title: chapterTitle);
      text = ContentProcessor.forBook(
        book,
        allRules: replaceRules,
      ).processSync(book: book, chapter: ch, content: text).text;
    }
    if (chineseConvert) text = ChineseConvert.s2t(text);
    // 排版（含段首两字缩进）必须在**任何**路径上都执行 —— 以前它藏在
    // ContentProcessor.process 里，而那只在配了替换规则时才会被调用，
    // 于是「没配替换规则的书」整段没有缩进。
    //
    // 段间必须保留空行（\n\n）：这条路径原先来自 htmlToPlain，段间就是空行；
    // 若压成单个 \n，段与段之间失去视觉间隔，整章会挤成一坨。
    return ContentProcessor.resegment(
      stripLeadingTitle(chapterTitle, htmlToPlain(text)),
      paragraphGap: '\n\n',
      indent: paragraphIndent,
    );
  }

  static String htmlToPlain(String raw) {
    if (!raw.contains('<')) return _joinWrappedFragments(raw);
    final doc = html_parser.parse(raw);
    for (final e in doc.querySelectorAll('br')) {
      e.replaceWith(html_dom.Text('\n'));
    }
    for (final e in doc.querySelectorAll('p,div,li,h1,h2,h3,blockquote')) {
      e.append(html_dom.Text('\n\n'));
    }
    final plain = doc.body?.text
            .replaceAll(_lineSeparators, '\n')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trim() ??
        raw;
    return _joinWrappedFragments(plain);
  }

  /// Rejoin physical lines that split a sentence during scraping. Blank lines
  /// and sentence-ending lines remain paragraph boundaries.
  static String _joinWrappedFragments(String raw) {
    final lines = raw
        // Some source rules emit Unicode line/paragraph separators instead of
        // LF. Flutter renders those as hard breaks, so normalize them before
        // the same short-fragment joining pass.
        .replaceAll(_lineSeparators, '\n')
        .split('\n');
    final paragraphs = <String>[];
    var current = '';
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        final complete = RegExp(r'[。！？!?；;」』”’]$').hasMatch(current);
        // HTML block boundaries become blank lines here. Treat them as real
        // paragraph breaks only after a complete sentence; some sources split
        // a sentence across <p> blocks, including a long fragment followed by
        // one or two characters (for example “随” + “后”).
        if (current.isNotEmpty && complete) {
          paragraphs.add(current);
          current = '';
        }
        continue;
      }
      final previousEndsSentence =
          current.isNotEmpty && RegExp(r'[。！？!?；;」』”’]$').hasMatch(current);
      if (current.isNotEmpty && !previousEndsSentence) {
        current = '$current$line';
      } else {
        if (current.isNotEmpty) paragraphs.add(current);
        current = line;
      }
    }
    if (current.isNotEmpty) paragraphs.add(current);

    // Some sites put every wrapped glyph in its own <p>/<div>, which creates
    // blank lines that ordinary line-wrap handling deliberately preserves.
    // Rejoin runs of tiny paragraphs so long Chinese lines cannot collapse
    // into a vertical column one character at a time.
    final out = <String>[];
    bool tiny(String value) => value.runes.length <= 3;
    for (var i = 0; i < paragraphs.length;) {
      if (!tiny(paragraphs[i])) {
        out.add(paragraphs[i++]);
        continue;
      }
      var end = i + 1;
      while (end < paragraphs.length && tiny(paragraphs[end])) {
        end++;
      }
      final run = paragraphs.sublist(i, end).join();
      final isRun = end - i > 1;
      final previousIsOpen =
          out.isNotEmpty && !RegExp(r'[。！？!?；;」』”’]$').hasMatch(out.last);
      if (out.isNotEmpty && (isRun || previousIsOpen)) {
        out[out.length - 1] = '${out.last}$run';
      } else {
        out.add(run);
      }
      i = end;
    }
    return out.join('\n\n');
  }

  static String stripLeadingTitle(String heading, String body) {
    final h = heading.trim();
    var rest = body.trimLeft();
    if (h.isEmpty) return rest;
    final first = rest;
    final compactHead = h.replaceAll(RegExp(r'\s+'), '');
    final compactBody = first.replaceAll(RegExp(r'\s+'), '');
    final starts = first.startsWith(h) || compactBody.startsWith(compactHead);
    if (!starts) return rest;
    if (rest.startsWith(h)) {
      rest = rest.substring(h.length);
    } else {
      var i = 0;
      var j = 0;
      while (i < rest.length && j < compactHead.length) {
        if (RegExp(r'\s').hasMatch(rest[i])) {
          i++;
          continue;
        }
        j++;
        i++;
      }
      rest = rest.substring(i);
    }
    rest = rest.replaceFirst(RegExp(r'^[\s　]*[—–\-_]{2,}[\s　]*'), '');
    return rest.replaceFirst(RegExp(r'^[\n\r]+'), '').trimLeft();
  }
}
