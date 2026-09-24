import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  group('digest', () {
    test('MD5 / SHA-256 known vectors', () {
      expect(
        JsCrypto.digestHex('abc', 'MD5'),
        '900150983cd24fb0d6963f7d28e17f72',
      );
      expect(
        JsCrypto.digestHex('abc', 'SHA-256'),
        'ba7816bf8f01cfea414140de5dae2223'
        'b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('algorithm spelling is normalised', () {
      // Hutool accepts SHA256, SHA-256 and sha256 alike.
      final a = JsCrypto.digestHex('abc', 'SHA-256');
      expect(JsCrypto.digestHex('abc', 'SHA256'), a);
      expect(JsCrypto.digestHex('abc', 'sha256'), a);
      expect(JsCrypto.digestHex('abc', 'SHA_256'.replaceAll('_', '')), a);
    });

    test('digestBase64Str is standard Base64 of the raw digest', () {
      expect(
        JsCrypto.digestBase64('abc', 'MD5'),
        'kAFQmDzST7DWlj99KOF/cg==',
      );
    });

    test('unknown algorithm fails loudly instead of returning empty', () {
      expect(() => JsCrypto.digestHex('abc', 'NOPE-1'), throwsFormatException);
    });
  });

  group('HMAC', () {
    const msg = 'The quick brown fox jumps over the lazy dog';

    test('HmacMD5 known vector', () {
      expect(
        JsCrypto.hmacHex(msg, 'HmacMD5', 'key'),
        '80070713463e7749b90c2dc24911e275',
      );
    });

    test('HMacBase64 matches the same bytes', () {
      expect(
        JsCrypto.hmacBase64(msg, 'HmacMD5', 'key'),
        'gAcHE0Y+d0m5DC3CSRHidQ==',
      );
    });

    test('HmacSHA256 known vector', () {
      expect(
        JsCrypto.hmacHex(msg, 'HmacSHA256', 'key'),
        'f7bc83f430538424b13298e6aa6fb143'
        'ef4d59a14946175997479dbc2d1a3cd8',
      );
    });

    test('bare algorithm name is accepted', () {
      expect(
        JsCrypto.hmacHex(msg, 'SHA256', 'key'),
        JsCrypto.hmacHex(msg, 'HmacSHA256', 'key'),
      );
    });
  });

  group('symmetric', () {
    test('AES/ECB/NoPadding known vector', () {
      // Classic FIPS-197 style vector: an all-zero key over an all-zero block.
      // Hutool takes the plaintext as a String, so the block is 16 NUL code
      // units (one UTF-8 byte each), while the key uses the Base64 flag.
      const zeroKeyB64 = 'AAAAAAAAAAAAAAAAAAAAAA==';
      expect(
        JsCrypto.symmetric(
          transformation: 'AES/ECB/NoPadding',
          key: zeroKeyB64,
          data: '\x00' * 16,
          operation: 'encryptHex',
          keyIsBase64: true,
        ),
        '66e94bd4ef8a2c3b884cfa59ca342b2e',
      );
    });

    test('AES/CBC/PKCS5Padding round-trips through Base64 and back', () {
      final enc = JsCrypto.symmetric(
        transformation: 'AES/CBC/PKCS5Padding',
        key: '1234567890123456',
        iv: 'abcdefghijklmnop',
        data: '书源加密测试 hello',
        operation: 'encryptBase64',
      );
      final dec = JsCrypto.symmetric(
        transformation: 'AES/CBC/PKCS5Padding',
        key: '1234567890123456',
        iv: 'abcdefghijklmnop',
        data: enc,
        operation: 'decryptStr',
      );
      expect(dec, '书源加密测试 hello');
    });

    test('DESede round-trips and expands a 16-byte key', () {
      final enc = JsCrypto.symmetric(
        transformation: 'DESede/CBC/PKCS5Padding',
        key: '1234567890abcdef',
        iv: '12345678',
        data: 'triple des',
        operation: 'encryptBase64',
      );
      final dec = JsCrypto.symmetric(
        transformation: 'DESede/CBC/PKCS5Padding',
        key: '1234567890abcdef',
        iv: '12345678',
        data: enc,
        operation: 'decryptStr',
      );
      expect(dec, 'triple des');
    });

    test('hex input is auto-detected on decrypt', () {
      final hexOut = JsCrypto.symmetric(
        transformation: 'AES/ECB/PKCS5Padding',
        key: '1234567890123456',
        data: 'abc',
        operation: 'encryptHex',
      );
      expect(
        JsCrypto.symmetric(
          transformation: 'AES/ECB/PKCS5Padding',
          key: '1234567890123456',
          data: hexOut,
          operation: 'decryptStr',
        ),
        'abc',
      );
    });

    test('CBC without iv fails loudly', () {
      expect(
        () => JsCrypto.symmetric(
          transformation: 'AES/CBC/PKCS5Padding',
          key: '1234567890123456',
          data: 'abc',
          operation: 'encryptBase64',
        ),
        throwsFormatException,
      );
    });

    test('single DES reports the backend limitation', () {
      expect(
        () => JsCrypto.symmetric(
          transformation: 'DES/ECB/PKCS5Padding',
          key: '12345678',
          data: 'abc',
          operation: 'encryptBase64',
        ),
        throwsFormatException,
      );
    });
  });

  group('host wiring', () {
    test('digest and HMAC are reachable through invokeSync', () {
      final host = JavaHost(http: _NoHttp(), cookieStore: CookieStore());
      expect(
        host.invokeSync('digestHex', ['abc', 'MD5']),
        '900150983cd24fb0d6963f7d28e17f72',
      );
      expect(
        host.invokeSync('HMacHex', [
          'The quick brown fox jumps over the lazy dog',
          'HmacMD5',
          'key',
        ]),
        '80070713463e7749b90c2dc24911e275',
      );
    });

    test('the JS prelude exposes every new crypto entry point', () {
      final prelude = JsHostBridge.prelude(vars: const {});
      for (final name in const [
        'createSymmetricCrypto',
        'digestHex',
        'digestBase64Str',
        'HMacHex',
        'HMacBase64',
        'aesDecodeToString',
        'aesDecodeArgsBase64Str',
        'aesEncodeToBase64String',
        'aesEncodeArgsBase64Str',
        'desDecodeToString',
        'desEncodeToBase64String',
        'tripleDESDecodeStr',
        'tripleDESDecodeArgsBase64Str',
        'tripleDESEncodeBase64Str',
        'tripleDESEncodeArgsBase64Str',
      ]) {
        expect(prelude, contains('$name:'), reason: name);
      }
    });

    test('createSymmetricCrypto returns an object with all Hutool methods', () {
      final prelude = JsHostBridge.prelude(vars: const {});
      for (final method in const [
        'decrypt',
        'decryptStr',
        'encrypt',
        'encryptBase64',
        'encryptHex',
      ]) {
        expect(prelude, contains('$method: function'), reason: method);
      }
    });
  });
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
