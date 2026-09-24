import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris/features/local/local_book_service.dart';
import 'package:chloris/services/export_service.dart';

void main() {
  test('ExportService.buildTxt 拼接章节', () {
    const raw = '第一章\n\n正文一。\n\n第二章\n\n正文二。\n';
    final bundle = LocalBookService(
      tocRules: [TxtTocRule(name: '章', rule: r'第[一二三四五六七八九十]+章', enable: true)],
    ).parseTxt(utf8.encode(raw), fileName: 'a.txt', overrideName: '示例');
    final txt = const ExportService().buildTxt(bundle);
    expect(txt, contains('示例'));
    expect(txt, contains('第一章'));
    expect(txt, contains('正文一。'));
  });

  test('ExportService.buildEpub 生成可读取的 EPUB 结构', () {
    final bundle =
        LocalBookService(
          tocRules: [
            TxtTocRule(name: '章', rule: r'第[一二三四五六七八九十]+章', enable: true),
          ],
        ).parseTxt(
          utf8.encode('第一章\n\n正文 <一>。\n'),
          fileName: 'a.txt',
          overrideName: '示例',
        );
    final bytes = const ExportService().buildEpub(bundle);
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.findFile('mimetype'), isNotNull);
    expect(archive.findFile('META-INF/container.xml'), isNotNull);
    expect(archive.findFile('OEBPS/content.opf'), isNotNull);
    expect(archive.findFile('OEBPS/nav.xhtml'), isNotNull);
    expect(archive.findFile('OEBPS/chapter0.xhtml'), isNotNull);
    final chapter = utf8.decode(
      archive.findFile('OEBPS/chapter0.xhtml')!.content as List<int>,
    );
    expect(chapter, contains('&lt;一&gt;'));
  });

  test('ExportService.buildEpub preserves paragraph and line breaks', () {
    final bundle = LocalBookService().parseTxt(
      utf8.encode('第一段\n第二行\n\n第二段'),
      fileName: 'breaks.txt',
    );
    final bytes = const ExportService().buildEpub(bundle);
    final archive = ZipDecoder().decodeBytes(bytes);
    final chapter = utf8.decode(
      archive.findFile('OEBPS/chapter0.xhtml')!.content as List<int>,
    );
    expect(chapter, contains('<p>第一段<br/>第二行</p>'));
    expect(chapter, contains('<p>第二段</p>'));
  });
}
