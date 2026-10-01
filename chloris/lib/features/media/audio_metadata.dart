import 'dart:convert';
import 'dart:typed_data';
import 'gb18030_codec.dart';

String decodeLyricBytes(Uint8List bytes) {
  if (bytes.length >= 4 &&
      (bytes[0] == 255 && bytes[1] == 254 && bytes[2] == 0 && bytes[3] == 0 ||
          bytes[0] == 0 &&
              bytes[1] == 0 &&
              bytes[2] == 254 &&
              bytes[3] == 255)) {
    final little = bytes[0] == 255;
    return String.fromCharCodes([
      for (var i = 4; i + 3 < bytes.length; i += 4)
        little
            ? bytes[i] |
                  bytes[i + 1] << 8 |
                  bytes[i + 2] << 16 |
                  bytes[i + 3] << 24
            : bytes[i] << 24 |
                  bytes[i + 1] << 16 |
                  bytes[i + 2] << 8 |
                  bytes[i + 3],
    ]);
  }
  if (bytes.length >= 2 &&
      ((bytes[0] == 255 && bytes[1] == 254) ||
          (bytes[0] == 254 && bytes[1] == 255))) {
    final le = bytes[0] == 255;
    return String.fromCharCodes([
      for (var i = 2; i + 1 < bytes.length; i += 2)
        le ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1],
    ]);
  }
  try {
    return utf8.decode(bytes).replaceFirst('\ufeff', '');
  } catch (_) {
    return decodeGb18030(bytes);
  }
}

Map<String, String> readAudioMetadata(Uint8List bytes) {
  final result = <String, String>{};
  int be(int i, int n) {
    var value = 0;
    for (var j = 0; j < n; j++) {
      value = (value << 8) | bytes[i + j];
    }
    return value;
  }

  int le(int i) {
    var value = 0;
    for (var j = 3; j >= 0; j--) {
      value = (value << 8) | bytes[i + j];
    }
    return value;
  }

  String ascii(int start, int end) => latin1.decode(bytes.sublist(start, end));
  String text(List<int> raw) {
    if (raw.isEmpty) return '';
    final encoding = raw.first;
    final data = Uint8List.fromList(raw.skip(1).toList());
    if (encoding == 1 || encoding == 2) {
      final little = encoding == 1 && data.length >= 2 && data[0] == 255;
      var start = data.length >= 2 && (data[0] == 255 || data[0] == 254)
          ? 2
          : 0;
      return String.fromCharCodes([
        for (var i = start; i + 1 < data.length; i += 2)
          little ? data[i] | data[i + 1] << 8 : data[i] << 8 | data[i + 1],
      ]).replaceAll('\u0000', '').trim();
    }
    return (encoding == 0
            ? latin1.decode(data)
            : utf8.decode(data, allowMalformed: true))
        .replaceAll('\u0000', '')
        .trim();
  }

  try {
    if (bytes.length > 10 && ascii(0, 3) == 'ID3') {
      final version = bytes[3];
      final size =
          ((bytes[6] & 127) << 21) |
          ((bytes[7] & 127) << 14) |
          ((bytes[8] & 127) << 7) |
          (bytes[9] & 127);
      var cursor = 10;
      while (cursor + 10 <= bytes.length && cursor < 10 + size) {
        final id = ascii(cursor, cursor + 4);
        if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(id)) break;
        var n = version == 4
            ? ((bytes[cursor + 4] & 127) << 21) |
                  ((bytes[cursor + 5] & 127) << 14) |
                  ((bytes[cursor + 6] & 127) << 7) |
                  (bytes[cursor + 7] & 127)
            : be(cursor + 4, 4);
        cursor += 10;
        if (n <= 0 || cursor + n > bytes.length) break;
        final key = const {
          'TIT2': 'title',
          'TPE1': 'artist',
          'TALB': 'album',
        }[id];
        if (key != null) result[key] = text(bytes.sublist(cursor, cursor + n));
        if (id == 'USLT' && n > 4) {
          final enc = bytes[cursor];
          var p = cursor + 4;
          if (enc == 1 || enc == 2) {
            while (p + 1 < cursor + n && (bytes[p] != 0 || bytes[p + 1] != 0)) {
              p += 2;
            }
            p += 2;
          } else {
            while (p < cursor + n && bytes[p] != 0) {
              p++;
            }
            p++;
          }
          if (p < cursor + n) {
            result['lyric'] = text([enc, ...bytes.sublist(p, cursor + n)]);
          }
        }
        cursor += n;
      }
    }
    void comments(int p) {
      if (p + 4 > bytes.length) return;
      final vendor = le(p);
      p += 4 + vendor;
      if (p + 4 > bytes.length) return;
      final count = le(p);
      p += 4;
      for (var j = 0; j < count && j < 4096 && p + 4 <= bytes.length; j++) {
        final len = le(p);
        p += 4;
        if (len < 0 || p + len > bytes.length) break;
        final field = utf8.decode(
          bytes.sublist(p, p + len),
          allowMalformed: true,
        );
        p += len;
        final split = field.indexOf('=');
        if (split < 0) continue;
        final key = const {
          'TITLE': 'title',
          'ARTIST': 'artist',
          'ALBUM': 'album',
          'LYRICS': 'lyric',
          'UNSYNCEDLYRICS': 'lyric',
        }[field.substring(0, split).toUpperCase()];
        if (key != null) result[key] = field.substring(split + 1);
      }
    }

    if (bytes.length > 4 && ascii(0, 4) == 'fLaC') {
      var p = 4;
      while (p + 4 < bytes.length) {
        final type = bytes[p] & 127;
        final last = bytes[p] & 128 != 0;
        final n = be(p + 1, 3);
        p += 4;
        if (type == 4) comments(p);
        p += n;
        if (last) break;
      }
    } else {
      for (var p = 0; p + 8 < bytes.length; p++) {
        if (ascii(p, p + 8) == 'OpusTags') {
          comments(p + 8);
          break;
        }
        if (bytes[p] == 3 && ascii(p + 1, p + 7) == 'vorbis') {
          comments(p + 7);
          break;
        }
      }
    }
    // MP4 ilst data atoms. Accept only validated atom lengths within the prefix.
    for (var p = 4; p + 20 < bytes.length; p++) {
      final key = const {
        '©nam': 'title',
        '©ART': 'artist',
        '©alb': 'album',
        '©lyr': 'lyric',
      }[ascii(p, p + 4)];
      if (key == null || ascii(p + 8, p + 12) != 'data') continue;
      final size = be(p - 4, 4), n = be(p + 4, 4);
      if (size < 24 || n < 16 || p + 4 + n > bytes.length) continue;
      result[key] = utf8
          .decode(bytes.sublist(p + 20, p + 4 + n), allowMalformed: true)
          .trim();
    }
  } catch (_) {
    /* Corrupt optional tags do not prevent importing playable audio. */
  }
  return result;
}
