import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class UmdBookData {
  UmdBookData({this.title = '', this.author = '', required this.chapters});
  final String title;
  final String author;
  final List<UmdChapterData> chapters;
}

class UmdChapterData {
  UmdChapterData({required this.title, required this.content});
  final String title;
  final String content;
}

class _Cur {
  _Cur(this.bytes);
  final Uint8List bytes;
  int i = 0;
  ByteData get _bd => ByteData.sublistView(bytes);
  bool get eof => i >= bytes.length;
  int u8() {
    if (eof) throw StateError('UMD 意外结束');
    return bytes[i++];
  }
  int u16le() {
    final v = _bd.getUint16(i, Endian.little);
    i += 2;
    return v;
  }
  int u32le() {
    final v = _bd.getUint32(i, Endian.little);
    i += 4;
    return v;
  }
  Uint8List take(int n) {
    if (n < 0 || i + n > bytes.length) throw StateError('UMD 块越界');
    final s = bytes.sublist(i, i + n);
    i += n;
    return s;
  }
}

String _u16le(Uint8List b) {
  if (b.isEmpty) return '';
  return String.fromCharCodes(
    List<int>.generate(b.length ~/ 2, (k) {
      return b[k * 2] | (b[k * 2 + 1] << 8);
    }),
  );
}

Uint8List _inflate(Uint8List src) {
  try {
    return Uint8List.fromList(const ZLibDecoder().decodeBytes(src));
  } catch (_) {
    try {
      return Uint8List.fromList(Inflate(src).getBytes());
    } catch (e) {
      throw StateError('UMD zlib 失败');
    }
  }
}

UmdBookData parseUmdBytes(Uint8List bytes) {
  final r = _Cur(bytes);
  if (bytes.length < 8 || r.u32le() != 0xde9a9b89) {
    throw StateError('不是 UMD 文件');
  }
  var title = '';
  var author = '';
  var extraCheck = 0;
  var totalLen = 0;
  final offsets = <int>[];
  final titles = <String>[];
  final content = BytesBuilder(copy: false);
  var ch = r.u8();
  var lastType = -1;
  while (ch == 35) {
    final segType = r.u16le();
    r.u8();
    final len = r.u8() - 5;
    switch (segType) {
      case 1:
        r.u8();
        r.take(2);
        break;
      case 2:
        title = _u16le(r.take(len));
        break;
      case 3:
        author = _u16le(r.take(len));
        break;
      case 11:
        totalLen = r.u32le();
        break;
      case 12:
        r.u32le();
        break;
      case 129:
      case 131:
      case 132:
        extraCheck = r.u32le();
        break;
      case 130:
        r.u8();
        extraCheck = r.u32le();
        break;
      default:
        if (len > 0) r.take(len);
    }
    var t = segType;
    if (t == 241 || t == 10) t = lastType;
    ch = r.eof ? 0 : r.u8();
    while (ch == 36) {
      final addCheck = r.u32le();
      final length2 = r.u32le() - 9;
      switch (t) {
        case 131:
          for (var i = 0; i < length2 ~/ 4; i++) {
            offsets.add(r.u32le());
          }
          break;
        case 132:
          if (extraCheck != addCheck) {
            content.add(_inflate(r.take(length2)));
          } else {
            var left = length2;
            while (left > 0) {
              final n = r.u8();
              left--;
              titles.add(_u16le(r.take(n)));
              left -= n;
            }
          }
          break;
        default:
          if (length2 > 0) r.take(length2);
      }
      ch = r.eof ? 0 : r.u8();
    }
    lastType = segType;
  }
  final raw = content.toBytes();
  if (titles.isEmpty && raw.isEmpty) throw StateError('UMD 无正文');
  final chapters = <UmdChapterData>[];
  if (titles.isEmpty) {
    chapters.add(UmdChapterData(title: title.isEmpty ? 'UMD' : title, content: _u16le(raw)));
  } else {
    for (var i = 0; i < titles.length; i++) {
      final st = i < offsets.length ? offsets[i] : 0;
      final end = i + 1 < offsets.length
          ? offsets[i + 1]
          : (totalLen > 0 ? totalLen : raw.length);
      final slice = st < end && end <= raw.length ? raw.sublist(st, end) : Uint8List(0);
      var text = _u16le(slice).replaceAll(String.fromCharCode(0x2029), String.fromCharCode(10));
      chapters.add(UmdChapterData(title: titles[i], content: text));
    }
  }
  return UmdBookData(title: title, author: author, chapters: chapters);
}
