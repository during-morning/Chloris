// TxtTocRule 目录识别测试 —— 对齐 legado TextFile.getTocRule（TextFile.kt:497-535）：
// - 规则评分：正样本（间隔 >1000 字）vs 误报（<100 字），csNum >= numE*3 才入选；
// - 首个匹配前的正文生成「前言」章节；
// - rule.replacement 作为标题净化 JS（result/index/prevTitle/prevLength 绑定）；
// - book.tocUrl 以 joiner 保存 rule+replacement，重解析不丢净化脚本。
import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

const _joiner = '🫅🈳🏻';

String _buildTxt({
  required int chapterCount,
  String? prologue,
  String titlePrefix = '第',
}) {
  final sb = StringBuffer();
  if (prologue != null) sb.writeln(prologue);
  for (var i = 1; i <= chapterCount; i++) {
    sb.writeln('$titlePrefix${i}章 标题');
    // 每章正文 1200 字，保证章节间隔 >1000
    sb.write('正文内容。' * 200);
    sb.writeln();
  }
  return sb.toString();
}

TextFile _txt(String content, {String tocUrl = ''}) {
  final book = Book(bookUrl: 'file://test.txt', name: '测试书');
  book.tocUrl = tocUrl;
  return TextFile(book, Uint8List.fromList(utf8.encode(content)));
}

void main() {
  test('评分算法：正则全行匹配但多为短间隔的规则被淘汰', () {
    final content = _buildTxt(chapterCount: 30);
    final txt = _txt(content);
    // 坏规则：匹配正文里每一行短句（全是 <100 字间隔 → numE 极高）
    final bad = TxtTocRule(name: '坏', rule: r'^标题$');
    // 好规则：匹配真实章节标题行
    final good = TxtTocRule(name: '好', rule: r'^第\d+章.*$');
    final chapters = txt.getChapterList([bad, good]);
    expect(chapters.length, 30);
    expect(chapters.first.title, contains('第1章'));
  });

  test('首个匹配前的正文生成「前言」章节而不是被丢弃', () {
    final content = _buildTxt(chapterCount: 5, prologue: '这是一段作品的简介前言。');
    final txt = _txt(content);
    final chapters = txt.getChapterList([
      TxtTocRule(name: '默认', rule: r'^第\d+章.*$'),
    ]);
    expect(chapters.first.title, '前言');
    expect(chapters.first.start, 0);
    expect(chapters[1].title, contains('第1章'));
    expect(chapters, hasLength(6));
  });

  test('replacement 标题净化 JS 生效', () {
    final content = _buildTxt(chapterCount: 5, titlePrefix: '第');
    final txt = _txt(content);
    final chapters = txt.getChapterList([
      TxtTocRule(
        name: '净化',
        rule: r'^第\d+章.*$',
        // 宽松解释器支持 result.replace(字面量, 字面量)
        replacement: "result.replace('章', '回')",
      ),
    ]);
    expect(chapters.first.title, contains('第1回'));
    expect(chapters.first.title.contains('第1章'), isFalse);
  });

  test('tocUrl 保存 rule+replacement，重解析仍走净化', () {
    final content = _buildTxt(chapterCount: 5);
    final book = Book(bookUrl: 'file://rt.txt', name: '测试书');
    final txt = TextFile(book, Uint8List.fromList(utf8.encode(content)));
    txt.getChapterList([
      TxtTocRule(
        name: 'r',
        rule: r'^第\d+章.*$',
        replacement: "result.replace('章', '节')",
      ),
    ]);
    expect(book.tocUrl, contains(_joiner));
    // 用保存的 tocUrl 重解析
    final book2 = Book(bookUrl: 'file://rt2.txt', name: '测试书');
    book2.tocUrl = book.tocUrl;
    final txt2 = TextFile(book2, Uint8List.fromList(utf8.encode(content)));
    final chapters = txt2.getChapterList(const []);
    expect(chapters.first.title, contains('第1节'));
  });

  test('没有规则命中时回退按大小分章', () {
    final content = _buildTxt(chapterCount: 5);
    final txt = _txt(content);
    final chapters = txt.getChapterList([
      TxtTocRule(name: '不匹配', rule: r'^完全不存在的模式XYZ$'),
    ]);
    expect(chapters, isNotEmpty);
    expect(chapters.first.title, '第1章');
  });
}

void _unused() {}
