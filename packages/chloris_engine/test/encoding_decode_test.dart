import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:test/test.dart';

void main() {
  test('HTTP charset decoder honours UTF-16 BOM', () {
    final le = Uint8List.fromList(<int>[0xff, 0xfe, 0x4b, 0x00, 0x66, 0x4e]);
    final be = Uint8List.fromList(<int>[0xfe, 0xff, 0x00, 0x4b, 0x4e, 0x66]);
    expect(CharsetDecoder.decode(le, 'utf-8'), 'K书');
    expect(CharsetDecoder.decode(be, 'utf-8'), 'K书');
  });

  test('HTTP charset decoder handles explicit UTF-16 endianness', () {
    final le = Uint8List.fromList(<int>[0x41, 0x00, 0x42, 0x00]);
    final be = Uint8List.fromList(<int>[0x00, 0x41, 0x00, 0x42]);
    expect(CharsetDecoder.decode(le, 'utf-16le'), 'AB');
    expect(CharsetDecoder.decode(be, 'utf-16be'), 'AB');
  });

  test('HTTP charset decoder handles GBK and Big5 labels', () {
    final gbk = const GbkCodec().encoder.convert('中文');
    final big5 = const Big5Codec().encoder.convert('繁體');
    expect(CharsetDecoder.decode(gbk, 'gb18030'), '中文');
    expect(CharsetDecoder.decode(big5, 'Big5'), '繁體');
  });

  test('query encoding uses GBK bytes for GBK sources', () {
    expect(encodeQueryWithCharset('中文'), Uri.encodeQueryComponent('中文'));
    expect(encodeQueryWithCharset('中文', 'utf-8'), Uri.encodeQueryComponent('中文'));
    final gbk = encodeQueryWithCharset('中文', 'gbk');
    expect(gbk, isNot(Uri.encodeQueryComponent('中文')));
    expect(gbk.toUpperCase(), contains('%D6%D0'));
  });

  test('HTTP body decoder sniffs GBK when no charset is given', () {
    final gbk = Uint8List.fromList(const GbkCodec().encoder.convert('三国演义'));
    expect(HttpBodyDecoder.decode(gbk), contains('三国演义'));
    expect(HttpBodyDecoder.decode(gbk, charset: 'gbk'), '三国演义');
  });
}
