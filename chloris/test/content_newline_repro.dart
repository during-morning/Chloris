// 复现「换行消失」：典型正文页 + 三种常见正文规则，跑引擎提取 + 应用侧
// ChapterPipeline 的 htmlToPlain/resegment 等价逻辑，检查段间换行是否存活。
// 运行：dart run test/content_newline_repro.dart
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

int failures = 0;

void expect(bool cond, String msg) {
  if (!cond) {
    failures++;
    print('FAIL: $msg');
  } else {
    print('OK: $msg');
  }
}

/// 应用侧 ChapterPipeline.htmlToPlain 的等价实现（chloris/lib/core/read/chapter_pipeline.dart）
String htmlToPlain(String raw) {
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

/// legado HtmlFormatter.format 的关键行：wrap 标签（含开标签）→ \n
String legadoFormat(String html) {
  return html
      .replaceAll(RegExp(r'</?(?:div|p|br|hr|h\d|article|dd|dl)[^>]*>'), '\n')
      .replaceAll(RegExp(r'<!--[^>]*-->'), '')
      .replaceAll(RegExp(r'<(?!!)[a-zA-Z]+(?=[ >])[^<>]*>'), '')
      .replaceAll(RegExp(r'\s*\n+\s*'), '\n　　')
      .replaceAll(RegExp(r'^[\n\s]+'), '　　')
      .replaceAll(RegExp(r'[\n\s]+$'), '');
}

void main() {
  // 场景 1：最常见的正文节点——<br> 分段
  const brPage = '<div id="content">'
      '　　段一第一行。<br>段一第二行。<br><br>'
      '　　段二第一行。<br>段二第二行。'
      '</div>';

  // 场景 2：<p> 分段
  const pPage = '<div id="content">'
      '<p>　　甲段内容。</p><p>　　乙段内容。</p><p>　　丙段内容。</p>'
      '</div>';

  // 场景 3：@text 的等价产物（package:html 的 e.text 会在 <br> 处直接吞行）
  final doc = html_parser.parse(brPage);
  final textOfDiv = doc.querySelectorAll('#content').first.text;
  print('--- @text 产物 ---');
  print(textOfDiv);

  expect(
    textOfDiv.contains('\n'),
    '场景1 @text：换行应存活（当前实现 e.text 会吞 <br>）',
  );

  // @html 产物 → htmlToPlain
  final htmlOut = doc.querySelectorAll('#content').first.outerHtml;
  final plain1 = htmlToPlain(htmlOut);
  print('--- @html → htmlToPlain ---');
  print(plain1);
  expect(plain1.contains('段一第二行。\n'), '场景1 @html→htmlToPlain：行内换行存活');
  expect(plain1.contains('\n\n'), '场景1 @html→htmlToPlain：段间空行存活');

  // <p> 分页 → htmlToPlain
  final doc2 = html_parser.parse(pPage);
  final plain2 = htmlToPlain(doc2.querySelectorAll('#content').first.outerHtml);
  print('--- <p> 分段 → htmlToPlain ---');
  print(plain2);
  expect(plain2.contains('乙段内容。\n'), '场景2 <p>分段：换行存活');

  // 对照：legado 的 wrap-tag 方式
  final lg = legadoFormat(htmlOut);
  print('--- legado format 对照 ---');
  print(lg);
  expect(lg.contains('段一第二行。\n'), 'legado format：行内换行存活');
}

// 引入 flutter 依赖前先确认退出码语义
// ignore: unused_element
void _done() => exit(failures == 0 ? 0 : 1);
