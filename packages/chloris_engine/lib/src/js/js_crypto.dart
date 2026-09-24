import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Java / Hutool-compatible crypto primitives exposed to rule JavaScript.
///
/// Legado-E implements these with Hutool (`DigestUtil`, `HMac`,
/// `SymmetricCrypto`) and exposes them on the `java` object. Book sources use
/// them for signed search URLs, encrypted API parameters and anti-bot tokens,
/// so the byte-level output has to match rather than merely be "some
/// encryption".
///
/// Byte-valued results cannot cross the JSON bridge, so they are returned as
/// Base64 strings — the same representation a rule would get from
/// `encryptBase64`, and the one that round-trips.
class JsCrypto {
  JsCrypto._();

  /// Hutool `DigestUtil.digester(algorithm).digestHex(data)`.
  static String digestHex(String data, String algorithm) {
    final digest = _digest(algorithm);
    final out = digest.process(_utf8(data));
    return _hex(out);
  }

  /// Hutool `Base64.encodeToString(digest, NO_WRAP)`.
  static String digestBase64(String data, String algorithm) {
    final digest = _digest(algorithm);
    return base64.encode(digest.process(_utf8(data)));
  }

  /// Hutool `HMac(algorithm, key.toByteArray()).digestHex(data)`.
  static String hmacHex(String data, String algorithm, String key) {
    return _hex(_hmac(data, algorithm, key));
  }

  /// Hutool `Base64.encodeToString(HMac(...).digest(data), NO_WRAP)`.
  static String hmacBase64(String data, String algorithm, String key) {
    return base64.encode(_hmac(data, algorithm, key));
  }

  /// Symmetric encrypt/decrypt matching Hutool's `SymmetricCrypto`.
  ///
  /// [transformation] uses the JCE spelling, e.g. `AES/ECB/PKCS5Padding`,
  /// `AES/CBC/NoPadding`, `DESede/CBC/PKCS5Padding`.
  ///
  /// [operation] is one of `decrypt`, `decryptStr`, `encrypt`,
  /// `encryptBase64`, `encryptHex`.
  static String symmetric({
    required String transformation,
    required String key,
    String? iv,
    required String data,
    required String operation,
    bool keyIsBase64 = false,
    bool ivIsBase64 = false,
  }) {
    final parts = transformation.split('/');
    if (parts.length < 2) {
      throw FormatException('transformation 需要 ALGO/MODE[/PADDING]: $transformation');
    }
    final algorithm = parts[0].trim();
    final mode = parts[1].trim().toUpperCase();
    final padding = parts.length > 2
        ? parts[2].trim()
        : (mode == 'ECB' ? 'PKCS5Padding' : 'PKCS5Padding');

    // Legado is inconsistent here, so the flags are per-call rather than
    // global: `aesDecodeArgsBase64Str` Base64-decodes both key and iv, while
    // `aesEncodeArgsBase64Str` passes both through as plain text and the
    // tripleDES ArgsBase64 pair decodes only the key. Each call site mirrors
    // exactly what its Legado counterpart does.
    final keyBytes = _normalizeKey(
      algorithm,
      keyIsBase64 ? _autoDecode(key) : _utf8(key),
    );
    final ivBytes = (iv == null || iv.isEmpty)
        ? null
        : (ivIsBase64 ? _autoDecode(iv) : _utf8(iv));
    final cipher = _blockCipher(algorithm);

    final wantsDecrypt = operation == 'decrypt' || operation == 'decryptStr';
    final input = wantsDecrypt ? _autoDecode(data) : _utf8(data);

    final padded = !padding.toLowerCase().startsWith('nopadding');
    final out = _run(
      cipher: cipher,
      mode: mode,
      padded: padded,
      keyBytes: keyBytes,
      ivBytes: ivBytes,
      input: input,
      decrypt: wantsDecrypt,
    );

    return switch (operation) {
      'decryptStr' => utf8.decode(out, allowMalformed: true),
      'encryptStr' => utf8.decode(out, allowMalformed: true),
      // A Java byte[] has no direct JSON representation; Base64 is the
      // lossless stand-in and matches what encryptBase64 produces.
      'decrypt' => base64.encode(out),
      'encryptHex' => _hex(out),
      'encrypt' => base64.encode(out),
      _ => base64.encode(out),
    };
  }

  // ---------------------------------------------------------------- internals

  static Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

  static String _hex(List<int> bytes) {
    final b = StringBuffer();
    for (final v in bytes) {
      b.write((v & 0xff).toRadixString(16).padLeft(2, '0'));
    }
    return b.toString();
  }

  /// Hutool `SecureUtil.decode`: hex when the text is pure hex with an even
  /// length, Base64 otherwise.
  static Uint8List _autoDecode(String data) {
    final t = data.trim();
    if (t.isNotEmpty &&
        t.length.isEven &&
        RegExp(r'^[0-9a-fA-F]+$').hasMatch(t)) {
      final out = Uint8List(t.length ~/ 2);
      for (var i = 0; i < out.length; i++) {
        out[i] = int.parse(t.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return out;
    }
    return Uint8List.fromList(base64.decode(base64.normalize(t)));
  }

  static Digest _digest(String algorithm) {
    final name = algorithm.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return switch (name) {
      'MD2' => MD2Digest(),
      'MD4' => MD4Digest(),
      'MD5' => MD5Digest(),
      'SHA1' => SHA1Digest(),
      'SHA224' => SHA224Digest(),
      'SHA256' => SHA256Digest(),
      'SHA384' => SHA384Digest(),
      'SHA512' => SHA512Digest(),
      'SHA3224' => SHA3Digest(224),
      'SHA3256' => SHA3Digest(256),
      'SHA3384' => SHA3Digest(384),
      'SHA3512' => SHA3Digest(512),
      'RIPEMD128' => RIPEMD128Digest(),
      'RIPEMD160' => RIPEMD160Digest(),
      'RIPEMD256' => RIPEMD256Digest(),
      'RIPEMD320' => RIPEMD320Digest(),
      'SM3' => SM3Digest(),
      'TIGER' => TigerDigest(),
      'WHIRLPOOL' => WhirlpoolDigest(),
      _ => throw FormatException('不支持的摘要算法: $algorithm'),
    };
  }

  /// HUTool accepts both `HmacSHA256` and `SHA256` spellings.
  static Uint8List _hmac(String data, String algorithm, String key) {
    final name = algorithm.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final bare = name.startsWith('HMAC') ? name.substring(4) : name;
    final digest = _digest(bare);
    // RFC 2104 block sizes, in bytes.
    final blockLength = switch (bare) {
      'SHA384' || 'SHA512' || 'SHA3384' || 'SHA3512' => 128,
      'SHA3224' || 'SHA3256' => 136,
      _ => 64,
    };
    final mac = HMac(digest, blockLength)
      ..init(KeyParameter(_utf8(key)));
    return mac.process(_utf8(data));
  }

  static BlockCipher _blockCipher(String algorithm) {
    final name = algorithm.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return switch (name) {
      'AES' => AESEngine(),
      'DESEDE' || 'TRIPLEDES' || '3DES' => DESedeEngine(),
      'BLOWFISH' => BlowfishEngine(),
      'CAMELLIA' => CamelliaEngine(),
      // pointycastle 4 dropped the single-DES engine (`DESEngine`). Fail with
      // a clear message rather than silently producing AES/DESede output for a
      // rule that asked for DES.
      'DES' => throw const FormatException(
        '单 DES 不被当前加密后端支持（pointycastle 4 已移除 DESEngine），请改用 DESede',
      ),
      _ => throw FormatException('不支持的对称算法: $algorithm'),
    };
  }

  /// Java expands a 16-byte DESede key to K1|K2|K1; AES keys must be 16/24/32.
  static Uint8List _normalizeKey(String algorithm, Uint8List key) {
    final name = algorithm.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if ((name == 'DESEDE' || name == 'TRIPLEDES' || name == '3DES') &&
        key.length == 16) {
      final out = Uint8List(24);
      out.setRange(0, 16, key);
      out.setRange(16, 24, key.sublist(0, 8));
      return out;
    }
    return key;
  }

  static Uint8List _run({
    required BlockCipher cipher,
    required String mode,
    required bool padded,
    required Uint8List keyBytes,
    required Uint8List? ivBytes,
    required Uint8List input,
    required bool decrypt,
  }) {
    final forEncryption = !decrypt;
    if (mode == 'CBC' && (ivBytes == null || ivBytes.isEmpty)) {
      throw const FormatException('CBC 模式需要 iv');
    }

    if (padded) {
      final base = mode == 'CBC'
          ? CBCBlockCipher(cipher)
          : ECBBlockCipher(cipher);
      final engine = PaddedBlockCipherImpl(PKCS7Padding(), base);
      final params = ivBytes == null
          ? KeyParameter(keyBytes)
          : ParametersWithIV(KeyParameter(keyBytes), ivBytes);
      engine.init(
        forEncryption,
        PaddedBlockCipherParameters<CipherParameters?, CipherParameters?>(
          params,
          null,
        ),
      );
      return engine.process(input);
    }

    // NoPadding: process whole blocks only, as the JCE does.
    final engine = mode == 'CBC' ? CBCBlockCipher(cipher) : ECBBlockCipher(cipher);
    final params = ivBytes == null
        ? KeyParameter(keyBytes)
        : ParametersWithIV(KeyParameter(keyBytes), ivBytes);
    engine.init(forEncryption, params);
    final blockSize = engine.blockSize;
    final out = Uint8List(input.length);
    for (var offset = 0; offset + blockSize <= input.length; offset += blockSize) {
      engine.processBlock(input, offset, out, offset);
    }
    return out;
  }
}
