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
              if (r is Map)
                ReplaceRule.fromJson(Map<String, dynamic>.from(r)),
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
      text = ContentProcessor.forBook(book, allRules: replaceRules)
          .processSync(book: book, chapter: ch, content: text)
          .text;
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
    if (!raw.contains('<')) return raw;
    final doc = html_parser.parse(raw);
    for (final e in doc.querySelectorAll('br')) {
      e.replaceWith(html_dom.Text('\n'));
    }
    for (final e in doc.querySelectorAll('p,div,li,h1,h2,h3,blockquote')) {
      e.append(html_dom.Text('\n\n'));
    }
    return doc.body?.text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim() ?? raw;
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
