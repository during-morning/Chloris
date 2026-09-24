import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cookie_js_stub.dart'
    if (dart.library.html) 'cookie_js_web.dart';

class CookieVault {
  CookieVault._(this.prefsKey, this.mirrorToCookie);

  static final CookieVault instance = CookieVault._('chlorisVaultV1', true);

  /// Credentials get their own vault that never mirrors into a cookie.
  ///
  /// [instance] writes a copy into a browser cookie so settings survive a
  /// reload, which is fine for a theme or a shelf snapshot but wrong for a
  /// WebDAV password: cookies are attached to every request to the origin.
  static final CookieVault credentials = CookieVault._(
    'chlorisCredentialsV1',
    false,
  );

  final String prefsKey;
  final bool mirrorToCookie;

  static const cookieName = 'ca';
  static const _magic = 'CA1';
  static const _cookieBudget = 3500;
  static const _secret = 'chloris-lite-cookie-vault-v1';

  Future<void> put(String key, Object? value) async {
    final all = await snapshot();
    if (value == null) {
      all.remove(key);
    } else {
      all[key] = value;
    }
    await _write(all);
  }

  Future<void> putAll(Map<String, Object?> patch) async {
    final all = await snapshot();
    for (final e in patch.entries) {
      if (e.value == null) {
        all.remove(e.key);
      } else {
        all[e.key] = e.value;
      }
    }
    await _write(all);
  }

  Future<Map<String, dynamic>> snapshot() async {
    final packed = await _readPacked();
    if (packed == null || packed.isEmpty) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(_decrypt(packed)) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<T?> get<T>(String key) async {
    final all = await snapshot();
    final v = all[key];
    if (v is T) return v;
    return null;
  }

  Future<String?> _readPacked() async {
    if (kIsWeb && mirrorToCookie) {
      final fromCookie = htmlCookieGet();
      if (fromCookie != null && fromCookie.isNotEmpty) {
        for (final part in fromCookie.split(';')) {
          final i = part.indexOf('=');
          if (i <= 0) continue;
          if (part.substring(0, i).trim() != cookieName) continue;
          return Uri.decodeComponent(part.substring(i + 1).trim());
        }
      }
    }
    final p = await SharedPreferences.getInstance();
    return p.getString(prefsKey);
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final packed = _encrypt(jsonEncode(data));
    final p = await SharedPreferences.getInstance();
    await p.setString(prefsKey, packed);
    if (!kIsWeb || !mirrorToCookie) return;
    if (packed.length <= _cookieBudget) {
      htmlCookieSet(
        cookieName +
            '=' +
            Uri.encodeComponent(packed) +
            '; Path=/; Max-Age=31536000; SameSite=Lax',
      );
    } else {
      htmlCookieSet(cookieName + '=; Path=/; Max-Age=0; SameSite=Lax');
    }
  }

  String _encrypt(String plain) {
    final gz = GZipEncoder().encode(utf8.encode(plain));
    final iv = _randomBytes(12);
    final key = sha256.convert(utf8.encode(_secret)).bytes;
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(Uint8List.fromList(key)),
          128,
          iv,
          Uint8List(0),
        ),
      );
    final sealed = cipher.process(Uint8List.fromList(gz));
    final blob = Uint8List(iv.length + sealed.length)
      ..setAll(0, iv)
      ..setAll(iv.length, sealed);
    return _magic + '.' + base64Url.encode(blob).replaceAll('=', '');
  }

  String _decrypt(String packed) {
    if (!packed.startsWith(_magic + '.')) {
      throw const FormatException('bad vault');
    }
    var b64 = packed.substring(_magic.length + 1);
    final pad = (4 - b64.length % 4) % 4;
    b64 += '=' * pad;
    final blob = base64Url.decode(b64);
    final iv = Uint8List.fromList(blob.sublist(0, 12));
    final sealed = Uint8List.fromList(blob.sublist(12));
    final key = sha256.convert(utf8.encode(_secret)).bytes;
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(Uint8List.fromList(key)),
          128,
          iv,
          Uint8List(0),
        ),
      );
    final gz = cipher.process(sealed);
    return utf8.decode(GZipDecoder().decodeBytes(gz));
  }

  Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }
}
