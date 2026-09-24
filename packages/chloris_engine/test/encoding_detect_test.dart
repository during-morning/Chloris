import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('BOM UTF-8', () {
    expect(
      EncodingDetect.getEncode(Uint8List.fromList([0xEF, 0xBB, 0xBF, 0x61])),
      'UTF-8',
    );
  });
  test('UTF-16LE BOM', () {
    expect(
      EncodingDetect.getEncode(Uint8List.fromList([0xFF, 0xFE, 0x61, 0x00])),
      'UTF-16LE',
    );
  });
  test('invalid utf8 falls back to GBK', () {
    expect(EncodingDetect.getEncode(Uint8List.fromList([0xB0, 0xA1])), 'GBK');
  });

  test('UTF-16BE BOM', () {
    expect(
      EncodingDetect.getEncode(Uint8List.fromList([0xFE, 0xFF, 0x00, 0x61])),
      'UTF-16BE',
    );
  });

  test('decode UTF-8', () {
    expect(
      EncodingDetect.decode(Uint8List.fromList('hi'.codeUnits), 'UTF-8'),
      'hi',
    );
  });

  test('decode GBK 你好', () {
    final bytes = Uint8List.fromList([0xC4, 0xE3, 0xBA, 0xC3]);
    expect(EncodingDetect.decode(bytes, 'gbk'), '你好');
  });

  test('decode UTF-16LE and UTF-16BE with BOM', () {
    final le = Uint8List.fromList([0xFF, 0xFE, 0x60, 0x4F, 0x7D, 0x59]);
    final be = Uint8List.fromList([0xFE, 0xFF, 0x4F, 0x60, 0x59, 0x7D]);
    expect(EncodingDetect.decode(le, 'UTF-16LE'), '你好');
    expect(EncodingDetect.decode(be, 'UTF-16BE'), '你好');
  });
}
