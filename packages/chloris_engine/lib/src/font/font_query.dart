import 'dart:typed_data';

/// Parses a TrueType/OpenType font far enough to map between characters and
/// glyph outlines.
///
/// Some book sites render chapter text with a custom font whose glyphs are
/// shuffled, so the extracted characters are meaningless until each glyph is
/// matched back to its real character by *outline*. Legado does this in
/// `QueryTTF`; this is the same idea over the tables that matter:
/// `head`, `maxp`, `loca`, `glyf` and `cmap`.
///
/// Only the outlines themselves are compared, not the layout tables, so
/// `hhea`/`hmtx`/`OS/2` are ignored on purpose.
class FontQuery {
  FontQuery._(
    this._unicodeToGlyphId,
    this._unicodeToOutline,
    this._outlineToUnicode,
    this.glyphCount,
  );

  final Map<int, int> _unicodeToGlyphId;

  /// Unicode -> outline signature.
  final Map<int, String> _unicodeToOutline;

  /// Outline signature -> unicode, built once from the forward map.
  final Map<String, int> _outlineToUnicode;

  final int glyphCount;

  /// Unicode code points treated as whitespace and passed through unchanged.
  static const blankUnicodes = {
    0x0009,
    0x0020,
    0x00A0,
    0x2002,
    0x2003,
    0x2007,
    0x200A,
    0x200B,
    0x200C,
    0x200D,
    0x202F,
    0x205F,
  };

  static bool isBlankUnicode(int unicode) => blankUnicodes.contains(unicode);

  /// Returns null when the bytes are not a font this parser understands.
  static FontQuery? parse(Uint8List bytes) {
    try {
      final tables = _readTableDirectory(bytes);
      if (tables == null) return null;

      final head = tables['head'];
      final maxp = tables['maxp'];
      final loca = tables['loca'];
      final glyf = tables['glyf'];
      final cmap = tables['cmap'];
      if (head == null || maxp == null || loca == null || glyf == null) {
        return null;
      }

      final glyphCount = _u16(bytes, maxp.offset + 4);
      final longLoca = _s16(bytes, head.offset + 50) != 0;
      final offsets = _readLoca(bytes, loca, glyphCount, longLoca);

      final unicodeToGlyphId = <int, int>{};
      if (cmap != null) {
        _readCmap(bytes, cmap, unicodeToGlyphId, glyphCount);
      }

      final unicodeToOutline = <int, String>{};
      final outlineToUnicode = <String, int>{};
      for (final entry in unicodeToGlyphId.entries) {
        final id = entry.value;
        if (id <= 0 || id >= offsets.length) continue;
        final outline = _glyphOutline(bytes, glyf, offsets, id);
        if (outline == null) continue;
        unicodeToOutline[entry.key] = outline;
        // First writer wins so the mapping is stable across runs.
        outlineToUnicode.putIfAbsent(outline, () => entry.key);
      }

      return FontQuery._(
        unicodeToGlyphId,
        unicodeToOutline,
        outlineToUnicode,
        glyphCount,
      );
    } catch (_) {
      return null;
    }
  }

  /// cmap glyph id for [unicode], or 0 like Legado when absent.
  int glyphIdByUnicode(int unicode) => _unicodeToGlyphId[unicode] ?? 0;

  /// Outline signature for [unicode], or null when the glyph has no contours.
  String? glyfByUnicode(int unicode) => _unicodeToOutline[unicode];

  /// Reverse lookup: the unicode whose outline equals [outline]. 0 when none.
  int unicodeByGlyf(String? outline) {
    if (outline == null || outline.isEmpty) return 0;
    return _outlineToUnicode[outline] ?? 0;
  }

  // ------------------------------------------------------------- internals

  static int _u16(Uint8List b, int at) => (b[at] << 8) | b[at + 1];

  static int _s16(Uint8List b, int at) {
    final v = _u16(b, at);
    return v >= 0x8000 ? v - 0x10000 : v;
  }

  static int _u32(Uint8List b, int at) =>
      (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];

  static String _tag(Uint8List b, int at) =>
      String.fromCharCodes(b.sublist(at, at + 4));

  static Map<String, _Table>? _readTableDirectory(Uint8List b) {
    if (b.length < 12) return null;
    // 0x00010000 (TrueType), 'true' and 'OTTO' (CFF outlines) all use this
    // directory layout. CFF fonts simply have no glyf table and parse to null.
    final numTables = _u16(b, 4);
    if (numTables <= 0 || numTables > 512) return null;
    final out = <String, _Table>{};
    for (var i = 0; i < numTables; i++) {
      final at = 12 + i * 16;
      if (at + 16 > b.length) return null;
      out[_tag(b, at)] = _Table(_u32(b, at + 8), _u32(b, at + 12));
    }
    return out;
  }

  static List<int> _readLoca(
    Uint8List b,
    _Table loca,
    int glyphCount,
    bool longLoca,
  ) {
    final out = List<int>.filled(glyphCount + 1, 0);
    for (var i = 0; i <= glyphCount; i++) {
      final at = loca.offset + (longLoca ? i * 4 : i * 2);
      if (at + (longLoca ? 4 : 2) > b.length) break;
      out[i] = longLoca ? _u32(b, at) : _u16(b, at) * 2;
    }
    return out;
  }

  /// Returns a hex signature of the glyph's outline, or null for an empty
  /// glyph (a space has no contours and must not become a mapping key).
  static String? _glyphOutline(
    Uint8List b,
    _Table glyf,
    List<int> offsets,
    int glyphId,
  ) {
    final start = glyf.offset + offsets[glyphId];
    final end = glyf.offset + offsets[glyphId + 1];
    if (end <= start || end > b.length) return null;
    final data = b.sublist(start, end);
    final buf = StringBuffer();
    for (final byte in data) {
      buf.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buf.toString();
  }

  static void _readCmap(
    Uint8List b,
    _Table cmap,
    Map<int, int> out,
    int glyphCount,
  ) {
    final base = cmap.offset;
    final numTables = _u16(b, base + 2);
    var best = -1;
    // Prefer a full-Unicode subtable, then BMP Unicode, then anything.
    var bestRank = -1;
    for (var i = 0; i < numTables; i++) {
      final rec = base + 4 + i * 8;
      if (rec + 8 > b.length) break;
      final platform = _u16(b, rec);
      final encoding = _u16(b, rec + 2);
      final offset = base + _u32(b, rec + 4);
      if (offset + 2 > b.length) continue;
      final format = _u16(b, offset);
      final rank = switch ((platform, encoding, format)) {
        (3, 10, 12) => 4,
        (0, _, 12) => 4,
        (3, 1, 4) => 3,
        (0, _, 4) => 2,
        (_, _, 4) => 1,
        (_, _, 12) => 1,
        _ => -1,
      };
      if (rank > bestRank) {
        bestRank = rank;
        best = offset;
      }
    }
    if (best < 0) return;
    final format = _u16(b, best);
    if (format == 4) {
      _readCmapFormat4(b, best, out, glyphCount);
    } else if (format == 12) {
      _readCmapFormat12(b, best, out, glyphCount);
    }
  }

  static void _readCmapFormat4(
    Uint8List b,
    int at,
    Map<int, int> out,
    int glyphCount,
  ) {
    final segCount = _u16(b, at + 6) ~/ 2;
    if (segCount <= 0) return;
    final endBase = at + 14;
    final startBase = endBase + segCount * 2 + 2;
    final deltaBase = startBase + segCount * 2;
    final rangeBase = deltaBase + segCount * 2;
    for (var s = 0; s < segCount; s++) {
      final end = _u16(b, endBase + s * 2);
      final start = _u16(b, startBase + s * 2);
      final delta = _s16(b, deltaBase + s * 2);
      final rangeOffset = _u16(b, rangeBase + s * 2);
      if (start > end || start == 0xffff) continue;
      for (var c = start; c <= end && c != 0x10000; c++) {
        int glyph;
        if (rangeOffset == 0) {
          glyph = (c + delta) & 0xffff;
        } else {
          final idx = rangeBase + s * 2 + rangeOffset + (c - start) * 2;
          if (idx + 2 > b.length) continue;
          glyph = _u16(b, idx);
          if (glyph != 0) glyph = (glyph + delta) & 0xffff;
        }
        if (glyph > 0 && glyph < glyphCount) out[c] = glyph;
      }
    }
  }

  static void _readCmapFormat12(
    Uint8List b,
    int at,
    Map<int, int> out,
    int glyphCount,
  ) {
    final nGroups = _u32(b, at + 12);
    for (var g = 0; g < nGroups; g++) {
      final rec = at + 16 + g * 12;
      if (rec + 12 > b.length) break;
      final startChar = _u32(b, rec);
      final endChar = _u32(b, rec + 4);
      final startGlyph = _u32(b, rec + 8);
      if (endChar < startChar || endChar - startChar > 0x10FFFF) continue;
      for (var c = startChar; c <= endChar; c++) {
        final glyph = startGlyph + (c - startChar);
        if (glyph > 0 && glyph < glyphCount) out[c] = glyph;
      }
    }
  }
}

class _Table {
  const _Table(this.offset, this.length);
  final int offset;
  final int length;
}
