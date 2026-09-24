import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:test/test.dart';

import 'package:chloris_engine/chloris_engine.dart';

void main() {
  test('dual-record KF8 reads a directly readable HTML flow', () {
    final html = utf8.encode(
      '<html><body><h1>第一章</h1><p>KF8 正文流</p></body></html>',
    );
    final bytes = _dualKf8(html);
    final document = const LocalDocumentParser().parseMobi(
      bytes,
      fileName: 'flow.azw3',
    );

    expect(document.format, LocalDocumentFormat.kf8);
    expect(document.chapters, isNotEmpty);
    expect(document.chapters.first.content, contains('KF8 正文流'));
  });

  test('PDF 未压缩页面文本进入 canonical chapter', () {
    final raw = '''
%PDF-1.4
1 0 obj
<< /Type /Page /Contents 2 0 R >>
endobj
2 0 obj
<< /Length 29 >>
stream
BT
(Hello PDF) Tj
ET
endstream
endobj
trailer
<< /Root 1 0 R >>
% outline metadata
/Title (Chapter 1)
%%EOF
''';
    final document = const LocalDocumentParser().parsePdf(
      Uint8List.fromList(utf8.encode(raw)),
      fileName: 'sample.pdf',
    );
    expect(document.chapters, hasLength(1));
    expect(document.chapters.first.content, 'Hello PDF');
    expect(document.outlines, contains('Chapter 1'));
  });

  test('PDF Flate 内容流可解压提取正文', () {
    const content = 'BT\n(Compressed PDF) Tj\nET\n';
    final compressed = const ZLibEncoder().encode(utf8.encode(content));
    final prefix = latin1.encode('''
%PDF-1.4
1 0 obj
<< /Type /Page /Contents 2 0 R >>
endobj
2 0 obj
<< /Length ${compressed.length} /Filter /FlateDecode >>
stream
''');
    final suffix = latin1.encode('''

endstream
endobj
%%EOF
''');
    final document = const LocalDocumentParser().parsePdf(
      Uint8List.fromList(<int>[...prefix, ...compressed, ...suffix]),
      fileName: 'compressed.pdf',
    );
    expect(document.chapters.first.content, 'Compressed PDF');
  });
}

Uint8List _dualKf8(List<int> html) {
  // The PDB record table occupies bytes 78..109 for four records; the first
  // record must begin after that table or its MOBI header would be overwritten
  // by the offsets below.
  const rec0Offset = 110;
  final rec0 = Uint8List(300);
  final rec0Data = ByteData.sublistView(rec0);
  rec0Data.setUint16(0, 1);
  rec0Data.setUint32(4, 0);
  rec0Data.setUint16(8, 0);
  _writeAscii(rec0, 16, 'MOBI');
  rec0Data.setUint32(20, 232);
  rec0Data.setUint32(28, 65001);
  rec0Data.setUint32(36, 6);
  rec0Data.setUint32(144, 0x40);
  const exth = 16 + 232;
  _writeAscii(rec0, exth, 'EXTH');
  rec0Data.setUint32(exth + 8, 1);
  rec0Data.setUint32(exth + 12, 121);
  rec0Data.setUint32(exth + 16, 12);
  rec0Data.setUint32(exth + 20, 2);

  final rec1 = Uint8List(1);
  final rec2 = Uint8List(280);
  final rec2Data = ByteData.sublistView(rec2);
  rec2Data.setUint16(0, 1);
  rec2Data.setUint32(4, html.length);
  rec2Data.setUint16(8, 1);
  _writeAscii(rec2, 16, 'MOBI');
  rec2Data.setUint32(20, 232);
  rec2Data.setUint32(28, 65001);
  rec2Data.setUint32(36, 8);
  final rec3 = Uint8List.fromList(html);

  final rec1Offset = rec0Offset + rec0.length;
  final rec2Offset = rec1Offset + rec1.length;
  final rec3Offset = rec2Offset + rec2.length;
  final out = Uint8List(rec3Offset + rec3.length);
  final header = ByteData.sublistView(out);
  header.setUint16(76, 4);
  header.setUint32(78, rec0Offset);
  header.setUint32(86, rec1Offset);
  header.setUint32(94, rec2Offset);
  header.setUint32(102, rec3Offset);
  out.setRange(rec0Offset, rec1Offset, rec0);
  out.setRange(rec1Offset, rec2Offset, rec1);
  out.setRange(rec2Offset, rec3Offset, rec2);
  out.setRange(rec3Offset, out.length, rec3);
  return out;
}

void _writeAscii(Uint8List bytes, int offset, String value) {
  bytes.setRange(offset, offset + value.length, value.codeUnits);
}
