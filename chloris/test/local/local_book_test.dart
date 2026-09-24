import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:chloris_engine/chloris_engine.dart';

import 'package:chloris/features/local/local_book_service.dart';
import 'package:chloris/features/local/local_book_provider.dart';
import 'package:chloris/features/local/umd_file.dart';

void main() {
  test('TXT 按目录规则分章并可取正文', () {
    const raw = '第一章 开始\n\n这是正文一。\n\n第二章 继续\n\n这是正文二。\n\n第三章 结束\n\n这是正文三。\n';
    final bytes = utf8.encode(raw);
    final service = LocalBookService(
      tocRules: [TxtTocRule(name: '章', rule: r'第[一二三四五六七八九十]+章', enable: true)],
    );
    final bundle = service.parseTxt(
      bytes,
      fileName: 'sample.txt',
      overrideName: '示例',
    );
    expect(bundle.chapters.length, greaterThanOrEqualTo(3));
    expect(bundle.book.name, '示例');
    expect(bundle.chapters.first.title, contains('第一章'));
    final content = bundle.content(bundle.chapters.first);
    expect(content, contains('这是正文一'));
  });

  test('未压缩 PalmDOC MOBI 可抽出正文', () {
    final body = List.filled(
      8,
      '第一章 开始。这是 MOBI 正文，需要足够长才能通过抽文本阈值检查。',
    ).join('\n');
    final text = utf8.encode(body);
    final rec0 = ByteData(16);
    rec0.setUint16(0, 1); // none
    rec0.setUint32(4, text.length);
    rec0.setUint16(8, 1); // 1 text record
    rec0.setUint16(10, 4096);
    final rec0b = rec0.buffer.asUint8List();
    const rec0off = 94;
    final rec1off = rec0off + 16;
    final head = ByteData(94);
    head.setUint16(76, 2);
    head.setUint32(78, rec0off);
    head.setUint32(86, rec1off);
    final pdb = Uint8List(rec1off + text.length);
    pdb.setAll(0, head.buffer.asUint8List());
    pdb.setAll(rec0off, rec0b);
    pdb.setAll(rec1off, text);
    final view = ByteData.sublistView(pdb);
    expect(view.getUint16(76), 2);
    expect(view.getUint32(78), rec0off);
    expect(view.getUint16(rec0off), 1);
    final bundle = LocalBookService().parseMobi(pdb, fileName: 't.mobi');
    expect(bundle.content(bundle.chapters.first), contains('MOBI 正文'));
    expect(localBundleKind(bundle), 'mobi');
  });

  test('PalmDOC 压缩 ASCII 可抽出', () {
    final body = List.filled(
      10,
      'Chapter 1 hello world from palmdoc inflate test.',
    ).join('\n');
    final text = utf8.encode(body);
    final rec0 = ByteData(16);
    rec0.setUint16(0, 2); // palmdoc
    rec0.setUint32(4, text.length);
    rec0.setUint16(8, 1);
    rec0.setUint16(10, 4096);
    const rec0off = 94;
    final rec1off = rec0off + 16;
    final head = ByteData(94);
    head.setUint16(76, 2);
    head.setUint32(78, rec0off);
    head.setUint32(86, rec1off);
    final pdb = Uint8List(rec1off + text.length);
    pdb.setAll(0, head.buffer.asUint8List());
    pdb.setAll(rec0off, rec0.buffer.asUint8List());
    pdb.setAll(rec1off, text);
    final bundle = LocalBookService().parseMobi(pdb, fileName: 'c.mobi');
    expect(bundle.content(bundle.chapters.first), contains('palmdoc inflate'));
  });

  test('KF8 给出明确错误', () {
    const rec0off = 94;
    const rec0len = 40;
    final rec1off = rec0off + rec0len;
    final head = ByteData(94);
    head.setUint16(76, 2);
    head.setUint32(78, rec0off);
    head.setUint32(86, rec1off);
    final rec0 = ByteData(rec0len);
    rec0.setUint16(0, 1);
    rec0.setUint16(8, 1);
    final rec0b = rec0.buffer.asUint8List();
    rec0b.setAll(16, utf8.encode('MOBI'));
    ByteData.sublistView(rec0b).setUint32(36, 8);
    final pdb = Uint8List(rec1off + 8);
    pdb.setAll(0, head.buffer.asUint8List());
    pdb.setAll(rec0off, rec0b);
    expect(
      () => LocalBookService().parseMobi(pdb, fileName: 'k.azw3'),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains('KF8')),
      ),
    );
  });

  test('PDF 需要有效文件头', () {
    expect(
      () => LocalBookService().parsePdf(
        Uint8List.fromList([1, 2, 3]),
        fileName: 'bad.pdf',
      ),
      throwsA(isA<StateError>()),
    );
    final bundle = LocalBookService().parsePdf(
      Uint8List.fromList(utf8.encode('%PDF-1.7\n')),
      fileName: 'ok.pdf',
    );
    expect(bundle.isPdf, isTrue);
    expect(bundle.chapters, hasLength(1));
  });

  test('非 UMD 魔数报错', () {
    expect(
      () => parseUmdBytes(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8])),
      throwsA(isA<StateError>()),
    );
  });
}
