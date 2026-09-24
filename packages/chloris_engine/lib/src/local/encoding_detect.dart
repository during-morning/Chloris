import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_convert/enough_convert.dart';

class EncodingDetect {
  static String getEncode(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return 'UTF-8';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return 'UTF-16LE';
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return 'UTF-16BE';
    }
    var utf8Ok = true;
    var i = 0;
    final limit = bytes.length < 4096 ? bytes.length : 4096;
    while (i < limit) {
      final b = bytes[i];
      if (b <= 0x7F) {
        i++;
        continue;
      }
      int need;
      if (b >= 0xC2 && b <= 0xDF) {
        need = 1;
      } else if (b >= 0xE0 && b <= 0xEF) {
        need = 2;
      } else if (b >= 0xF0 && b <= 0xF4) {
        need = 3;
      } else {
        utf8Ok = false;
        break;
      }
      if (i + need >= bytes.length) {
        utf8Ok = false;
        break;
      }
      for (var j = 1; j <= need; j++) {
        if (bytes[i + j] & 0xC0 != 0x80) {
          utf8Ok = false;
          break;
        }
      }
      if (!utf8Ok) break;
      i += 1 + need;
    }
    if (utf8Ok) return 'UTF-8';
    return 'GBK';
  }

  static String decode(Uint8List bytes, String charset) {
    final name = charset.toLowerCase();
    if (name.contains('gb')) {
      return const GbkCodec(allowInvalid: true).decode(bytes);
    }
    if (name.contains('utf-16')) {
      final littleEndian =
          name.contains('le') ||
          (!name.contains('be') && bytes.length >= 2 && bytes[0] == 0xFF);
      var offset = 0;
      if (bytes.length >= 2 &&
          ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
              (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
        offset = 2;
      }
      final units = <int>[];
      for (var i = offset; i + 1 < bytes.length; i += 2) {
        final unit = littleEndian
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1];
        units.add(unit);
      }
      return String.fromCharCodes(units);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
