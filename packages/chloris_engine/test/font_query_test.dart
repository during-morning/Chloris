import 'dart:convert';
import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

/// Builds a minimal but structurally valid TrueType font.
///
/// [codepoints] i and [outlineSeeds] i are paired: the character maps to glyph
/// `i + 1`, and that glyph's outline is derived from the seed. Two fonts built
/// with different seed orders therefore disagree about which character a given
/// outline belongs to — exactly the situation font obfuscation creates.
Uint8List buildTtf(List<int> codepoints, List<int> outlineSeeds) {
  assert(codepoints.length == outlineSeeds.length);

  // ---- glyf + loca -------------------------------------------------------
  final glyphs = <Uint8List>[
    // .notdef: an empty glyph, so it never becomes a mapping key.
    Uint8List(0),
  ];
  for (final seed in outlineSeeds) {
    glyphs.add(_simpleGlyph(seed));
  }

  // Short loca stores offset/2, so every glyph must start at an even offset.
  final offsets = <int>[];
  var cursor = 0;
  for (final g in glyphs) {
    offsets.add(cursor);
    cursor += g.length;
    if (cursor.isOdd) cursor++;
  }
  offsets.add(cursor);

  final glyf = Uint8List(cursor);
  for (var i = 0; i < glyphs.length; i++) {
    glyf.setAll(offsets[i], glyphs[i]);
  }

  final loca = Uint8List((offsets.length) * 2);
  for (var i = 0; i < offsets.length; i++) {
    _putU16(loca, i * 2, offsets[i] ~/ 2);
  }

  // ---- head / maxp -------------------------------------------------------
  final head = Uint8List(54);
  _putU32(head, 0, 0x00010000);
  _putU16(head, 50, 0); // indexToLocFormat = short

  final maxp = Uint8List(32);
  _putU32(maxp, 0, 0x00010000);
  _putU16(maxp, 4, glyphs.length);

  // ---- cmap (format 4) ---------------------------------------------------
  final cmap = _cmapFormat4(codepoints);

  final tables = <String, Uint8List>{
    'cmap': cmap,
    'glyf': glyf,
    'head': head,
    'loca': loca,
    'maxp': maxp,
  };

  return _assemble(tables);
}

/// One on-curve square with a seed-dependent width, so each glyph's outline
/// bytes are distinct.
Uint8List _simpleGlyph(int seed) {
  final b = BytesBuilder();
  final buf = Uint8List(10 + 2 + 2 + 4 + 4 + 4);
  var at = 0;
  _putU16(buf, at, 1); // numberOfContours
  at += 2;
  _putU16(buf, at, 0); // xMin
  at += 2;
  _putU16(buf, at, 0); // yMin
  at += 2;
  _putU16(buf, at, 10 + seed); // xMax
  at += 2;
  _putU16(buf, at, 10); // yMax
  at += 2;
  _putU16(buf, at, 3); // endPtsOfContours[0]
  at += 2;
  _putU16(buf, at, 0); // instructionLength
  at += 2;
  buf[at++] = 0x01; // on-curve, 8-bit deltas
  buf[at++] = 0x01;
  buf[at++] = 0x01;
  buf[at++] = 0x01;
  buf[at++] = 0; // x deltas
  buf[at++] = 10;
  buf[at++] = 0;
  buf[at++] = 0; // y deltas
  buf[at++] = 0;
  buf[at++] = 10;
  buf[at] = 0;
  b.add(buf);
  return b.toBytes();
}

Uint8List _cmapFormat4(List<int> codepoints) {
  final sorted = [...codepoints]..sort();
  final segCount = sorted.length + 1; // + the 0xFFFF sentinel
  final subtableLen = 16 + segCount * 8;

  final sub = Uint8List(subtableLen);
  _putU16(sub, 0, 4); // format
  _putU16(sub, 2, subtableLen);
  _putU16(sub, 4, 0); // language
  _putU16(sub, 6, segCount * 2);
  _putU16(sub, 8, 0); // searchRange
  _putU16(sub, 10, 0); // entrySelector
  _putU16(sub, 12, 0); // rangeShift

  final endBase = 14;
  final startBase = endBase + segCount * 2 + 2; // + reservedPad
  final deltaBase = startBase + segCount * 2;
  final rangeBase = deltaBase + segCount * 2;

  for (var i = 0; i < sorted.length; i++) {
    final c = sorted[i];
    final glyphId = codepoints.indexOf(c) + 1;
    _putU16(sub, endBase + i * 2, c);
    _putU16(sub, startBase + i * 2, c);
    _putU16(sub, deltaBase + i * 2, (glyphId - c) & 0xffff);
    _putU16(sub, rangeBase + i * 2, 0);
  }
  // Sentinel segment.
  final s = sorted.length;
  _putU16(sub, endBase + s * 2, 0xffff);
  _putU16(sub, startBase + s * 2, 0xffff);
  _putU16(sub, deltaBase + s * 2, 1);
  _putU16(sub, rangeBase + s * 2, 0);

  // Header: version, numTables, then one encoding record.
  final out = Uint8List(4 + 8 + subtableLen);
  _putU16(out, 0, 0); // version
  _putU16(out, 2, 1); // numTables
  _putU16(out, 4, 3); // platformID = Windows
  _putU16(out, 6, 1); // encodingID = Unicode BMP
  _putU32(out, 8, 12); // subtable offset
  out.setAll(12, sub);
  return out;
}

Uint8List _assemble(Map<String, Uint8List> tables) {
  final tags = tables.keys.toList()..sort();
  final numTables = tags.length;
  var offset = 12 + numTables * 16;
  final directory = <String, int>{};
  for (final tag in tags) {
    directory[tag] = offset;
    offset += tables[tag]!.length;
    if (offset.isOdd) offset++;
  }

  final out = Uint8List(offset);
  _putU32(out, 0, 0x00010000);
  _putU16(out, 4, numTables);
  for (var i = 0; i < numTables; i++) {
    final tag = tags[i];
    final at = 12 + i * 16;
    for (var c = 0; c < 4; c++) {
      out[at + c] = tag.codeUnitAt(c);
    }
    _putU32(out, at + 4, 0); // checksum (not validated by our parser)
    _putU32(out, at + 8, directory[tag]!);
    _putU32(out, at + 12, tables[tag]!.length);
    out.setAll(directory[tag]!, tables[tag]!);
  }
  return out;
}

void _putU16(Uint8List b, int at, int v) {
  b[at] = (v >> 8) & 0xff;
  b[at + 1] = v & 0xff;
}

void _putU32(Uint8List b, int at, int v) {
  b[at] = (v >> 24) & 0xff;
  b[at + 1] = (v >> 16) & 0xff;
  b[at + 2] = (v >> 8) & 0xff;
  b[at + 3] = v & 0xff;
}

class _NoHttp implements HttpPort {
  _NoHttp({this.bytes});

  final List<int>? bytes;

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async =>
      throw UnimplementedError();

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async =>
      Uint8List.fromList(bytes ?? const []);

  @override
  void cancelInFlight() {}
}

JavaHost _host({HttpPort? http}) => JavaHost(
  http: http ?? _NoHttp(),
  cookieStore: CookieStore(),
);

const _a = 0x41;
const _b = 0x42;
const _c = 0x43;

void main() {
  group('FontQuery parsing', () {
    test('reads the cmap so characters resolve to glyph ids', () {
      final font = FontQuery.parse(buildTtf([_a, _b, _c], [1, 2, 3]))!;
      expect(font.glyphCount, 4); // .notdef + 3
      expect(font.glyphIdByUnicode(_a), 1);
      expect(font.glyphIdByUnicode(_b), 2);
      expect(font.glyphIdByUnicode(_c), 3);
      expect(font.glyphIdByUnicode(0x5a), 0); // unmapped
    });

    test('distinct glyphs get distinct outline signatures', () {
      final font = FontQuery.parse(buildTtf([_a, _b, _c], [1, 2, 3]))!;
      final oa = font.glyfByUnicode(_a);
      final ob = font.glyfByUnicode(_b);
      expect(oa, isNotNull);
      expect(ob, isNotNull);
      expect(oa, isNot(ob));
    });

    test('identical outlines map back to the same character', () {
      final font = FontQuery.parse(buildTtf([_a, _b], [7, 7]))!;
      expect(font.glyfByUnicode(_a), font.glyfByUnicode(_b));
    });

    test('reverse lookup finds the character behind an outline', () {
      final font = FontQuery.parse(buildTtf([_a, _b, _c], [1, 2, 3]))!;
      expect(font.unicodeByGlyf(font.glyfByUnicode(_b)), _b);
      expect(font.unicodeByGlyf(null), 0);
      expect(font.unicodeByGlyf('deadbeef'), 0);
    });

    test('bytes that are not a font parse to null', () {
      expect(FontQuery.parse(Uint8List.fromList([1, 2, 3])), isNull);
      expect(FontQuery.parse(Uint8List(64)), isNull);
    });

    test('blank unicode set matches the Legado list', () {
      for (final c in const [0x09, 0x20, 0xA0, 0x2002, 0x200B, 0x202F, 0x205F]) {
        expect(FontQuery.isBlankUnicode(c), isTrue, reason: '$c');
      }
      expect(FontQuery.isBlankUnicode(_a), isFalse);
    });
  });

  group('replaceFont undoes a shuffled font', () {
    test('characters are recovered by outline, not by code point', () async {
      final host = _host();
      // The "correct" font is the honest one.
      final correct = await host.queryTTF(
        buildTtf([_a, _b, _c], [1, 2, 3]),
      );
      // The obfuscated font swaps the outlines of A and B.
      final error = await host.queryTTF(buildTtf([_a, _b, _c], [2, 1, 3]));

      expect(host.replaceFont('AB', error, correct), 'BA');
      expect(host.replaceFont('C', error, correct), 'C');
    });

    test('whitespace and punctuation-free text passes through unchanged',
        () async {
      final host = _host();
      final correct = await host.queryTTF(buildTtf([_a, _b], [1, 2]));
      final error = await host.queryTTF(buildTtf([_a, _b], [2, 1]));
      // Space is blank, so it is preserved rather than remapped.
      expect(host.replaceFont('A B', error, correct), 'B A');
    });

    test('filter drops characters the error font has no glyph for', () async {
      final host = _host();
      final correct = await host.queryTTF(buildTtf([_a, _b], [1, 2]));
      final error = await host.queryTTF(buildTtf([_a, _b], [2, 1]));

      // 'Z' is unmapped in the error font.
      expect(host.replaceFont('AZB', error, correct, false), contains('Z'));
      expect(host.replaceFont('AZB', error, correct, true), 'BA');
    });

    test('an unknown handle leaves the text alone instead of blanking it',
        () async {
      final host = _host();
      final correct = await host.queryTTF(buildTtf([_a], [1]));
      expect(host.replaceFont('AB', 'bogus', correct), 'AB');
      expect(host.replaceFont('AB', correct, 'bogus'), 'AB');
    });
  });

  group('queryTTF input handling', () {
    test('accepts raw bytes', () async {
      final handle = await _host().queryTTF(buildTtf([_a], [1]));
      expect(handle, isNotEmpty);
    });

    test('accepts base64', () async {
      final font = buildTtf([_a], [1]);
      final handle = await _host().queryTTF(base64Encode(font));
      expect(handle, isNotEmpty);
    });

    test('fetches a url through the http port', () async {
      final font = buildTtf([_a], [1]);
      final handle = await _host(
        http: _NoHttp(bytes: font),
      ).queryTTF('https://cdn.test/font.ttf');
      expect(handle, isNotEmpty);
    });

    test('empty or unreadable data fails loudly', () async {
      await expectLater(_host().queryTTF(null), throwsA(isA<DomainError>()));
      await expectLater(_host().queryTTF(''), throwsA(isA<DomainError>()));
    });

    test('non-font bytes fail loudly rather than yielding a wrong mapping',
        () async {
      await expectLater(
        _host().queryTTF(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<DomainError>()),
      );
    });

    test('queryBase64TTF behaves like queryTTF', () async {
      final font = buildTtf([_a], [1]);
      final handle = await _host().queryBase64TTF(base64Encode(font));
      expect(handle, isNotEmpty);
    });
  });

  group('bridge wiring', () {
    test('font calls ride the async two-pass cycle', () {
      for (final name in const ['queryTTF', 'queryBase64TTF']) {
        expect(JsHostSession.isNetwork(name), isTrue, reason: name);
      }
    });

    test('the prelude wraps the handle so scripts keep the Legado shape', () {
      final prelude = JsHostBridge.prelude(vars: const {});
      for (final name in const ['queryTTF', 'queryBase64TTF', 'replaceFont']) {
        expect(prelude, contains('$name:'), reason: name);
      }
      // `replaceFont` passes handles through, not whole objects.
      expect(prelude, contains('errorQueryTTF ? errorQueryTTF.id : null'));
    });
  });
}
