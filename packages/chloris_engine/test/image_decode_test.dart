import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

void main() {
  test('sniffResourceUrl picks the first matching http URL', () {
    const html = '''
    <html><script src="https://cdn.ex/app.js"></script>
    <img src="https://img.ex/cover.bin">
    <video src="https://media.ex/play.m3u8"></video>
    </html>
    ''';
    expect(sniffResourceUrl(html, r'.*\.m3u8$'), 'https://media.ex/play.m3u8');
    expect(sniffResourceUrl(html, r'cover\.bin'), 'https://img.ex/cover.bin');
    expect(sniffResourceUrl(html, r'not-there'), isNull);
  });

  test('ImageDecoder.bytesFromJs reads base64 and data URI', () {
    final raw = Uint8List.fromList([1, 2, 3, 4]);
    final b64 = base64.encode(raw);
    expect(ImageDecoder.bytesFromJs(b64, 'other'), raw);
    expect(ImageDecoder.bytesFromJs('data:image/png;base64,$b64', 'x'), raw);
    expect(ImageDecoder.bytesFromJs(b64, b64), isNull);
  });

  test('ImageDecoder.decode keeps bytes when JS returns result', () async {
    final raw = Uint8List.fromList([9, 8, 7]);
    final out = await ImageDecoder.decode(
      bytes: raw,
      src: 'https://ex.com/c.bin',
      js: 'result',
      jsRuntime: const LenientJsRuntime(),
    );
    expect(out, raw);
  });

  test('java.aesDecrypt round-trips PKCS7-padded plaintext', () {
    final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
    final key = Uint8List.fromList(utf8.encode('1234567890abcdef'));
    final plain = utf8.encode('hello image');
    final padded = _pkcs7(Uint8List.fromList(plain), 16);
    final encrypted = _aesCbcEncrypt(padded, key);
    final outB64 = host.aesDecryptStr(
      base64.encode(encrypted),
      '1234567890abcdef',
    );
    expect(utf8.decode(base64.decode(outB64)), 'hello image');
  });

  test('coverDecodeJs vs imageDecode selection', () {
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      coverDecodeJs: 'cover',
      ruleContent: ContentRule(imageDecode: 'page'),
    );
    expect(ImageDecoder.decodeJs(source, isCover: true), 'cover');
    expect(ImageDecoder.decodeJs(source, isCover: false), 'page');
    expect(ImageDecoder.decodeJs(null, isCover: true), isNull);
  });
}

Uint8List _pkcs7(Uint8List data, int block) {
  final pad = block - (data.length % block);
  return Uint8List.fromList([...data, ...List.filled(pad, pad)]);
}

Uint8List _aesCbcEncrypt(Uint8List data, Uint8List key) {
  final cipher = CBCBlockCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(key), Uint8List(16)));
  final out = Uint8List(data.length);
  var offset = 0;
  while (offset < data.length) {
    offset += cipher.processBlock(data, offset, out, offset);
  }
  return out;
}

class _NoHttp implements HttpPort {
  @override
  Future<StrResponse> send(HttpRequestSpec spec) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async =>
      throw UnimplementedError();

  @override
  void cancelInFlight() {}
}
