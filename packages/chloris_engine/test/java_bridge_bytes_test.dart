// 字节族桥接测试 —— 对齐 legado JsExtensions：strToBytes/bytesToStr/getByteArray
// 走「句柄注册表」模式（JSON 桥无法传二进制），句柄可跨 java.* 调用传递。
import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

import 'font_query_test.dart' show buildTtf;

class _NoHttp implements HttpPort {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('no http in test');
}

void main() {
  test('strToBytes → bytesToStr round-trip（默认 utf8）', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final handle = await host.invoke('strToBytes', ['正文内容甲乙丙']);
    expect(handle, isA<String>());
    expect((handle! as String).startsWith('bytes'), isTrue);
    final out = await host.invoke('bytesToStr', [handle]);
    expect(out, '正文内容甲乙丙');
  });

  test('strToBytes/bytesToStr 指定 GBK 字符集', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final handle = await host.invoke('strToBytes', ['小说', 'gbk']);
    // GBK 编码的两个汉字各 2 字节
    expect((handle! as String).isNotEmpty, isTrue);
    final out = await host.invoke('bytesToStr', [handle, 'gbk']);
    expect(out, '小说');
  });

  test('无效句柄 bytesToStr 返回空串（不抛错不崩）', () async {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final out = await host.invoke('bytesToStr', ['bytes999']);
    expect(out, '');
  });

  test('getByteArray 取网络字节→句柄→queryTTF 全链路', () async {
    final font = buildTtf('甲乙丙'.codeUnits, [1, 2, 3]);
    final host = JavaHost(http: _FakeHttp(font), cookieStore: CookieStore());
    final bytesHandle = await host.invoke('getByteArray', [
      'https://font.example.com/w.ttf',
    ]);
    expect((bytesHandle! as String).startsWith('bytes'), isTrue);
    final ttfHandle = await host.invoke('queryTTF', [bytesHandle]);
    expect((ttfHandle! as String).startsWith('ttf'), isTrue);
    // 句柄字体可正常参与 replaceFont
    final okHandle = await host.invoke('queryBase64TTF', [
      base64Encode(buildTtf('甲乙丙'.codeUnits, [1, 2, 3])),
    ]);
    final out = await host.invoke('replaceFont', [
      '甲乙丙',
      ttfHandle,
      okHandle,
      false,
    ]);
    expect(out, isA<String>());
    expect((out! as String).length, 3);
  });
}

class _FakeHttp implements HttpPort {
  _FakeHttp(this.bytes);
  final Uint8List bytes;

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) =>
      Future.value(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('unexpected in test');
}
