import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('PDF ASCIIHexDecode and hexadecimal text strings are readable', () {
    final stream = '42540a284865782066696c7465722920546a0a45540a>';
    final pdf = _pdf('/ASCIIHexDecode', stream);
    final doc = const LocalDocumentParser().parsePdf(
      Uint8List.fromList(pdf.codeUnits),
      fileName: 'hex.pdf',
    );
    expect(doc.chapters.single.content, 'Hex filter');

    final hexText = _pdf('', 'BT\n<004800650078> Tj\nET\n');
    final hexDoc = const LocalDocumentParser().parsePdf(
      Uint8List.fromList(hexText.codeUnits),
      fileName: 'hex-text.pdf',
    );
    expect(hexDoc.chapters.single.content, 'Hex');
  });

  test('PDF ASCII85Decode stream is readable', () {
    final pdf = _pdf('/ASCII85Decode', '<~6<":?5uU-B8N8RV+B3(_78sT~>');
    final doc = const LocalDocumentParser().parsePdf(
      Uint8List.fromList(pdf.codeUnits),
      fileName: 'a85.pdf',
    );
    expect(doc.chapters.single.content, 'ASCII85');
  });

  test('PDF LZWDecode stream is readable', () {
    final bytes = <int>[
      0x80,
      0x10,
      0x8a,
      0x80,
      0xa1,
      0x41,
      0x30,
      0xb4,
      0x57,
      0x14,
      0x88,
      0x0a,
      0x86,
      0xa0,
      0x51,
      0x14,
      0xa8,
      0x0a,
      0x80,
      0x80,
    ];
    final prefix = _pdfPrefix('/LZWDecode', bytes.length);
    final suffix = '\nendstream\nendobj\n%%EOF\n';
    final raw = <int>[...prefix.codeUnits, ...bytes, ...suffix.codeUnits];
    final doc = const LocalDocumentParser().parsePdf(
      Uint8List.fromList(raw),
      fileName: 'lzw.pdf',
    );
    expect(doc.chapters.single.content, 'LZW');
  });
}

String _pdf(String filter, String payload) {
  final dictionary = filter.isEmpty
      ? '<< /Type /Page /Contents 2 0 R >>'
      : '<< /Type /Page /Contents 2 0 R >>';
  final streamDict = filter.isEmpty
      ? '<< /Length ${payload.length} >>'
      : '<< /Length ${payload.length} /Filter $filter >>';
  return '%PDF-1.4\n'
      '1 0 obj\n$dictionary\nendobj\n'
      '2 0 obj\n$streamDict\nstream\n$payload\nendstream\nendobj\n'
      '%%EOF\n';
}

String _pdfPrefix(String filter, int length) =>
    '%PDF-1.4\n'
    '1 0 obj\n<< /Type /Page /Contents 2 0 R >>\nendobj\n'
    '2 0 obj\n<< /Length $length /Filter $filter >>\nstream\n';
