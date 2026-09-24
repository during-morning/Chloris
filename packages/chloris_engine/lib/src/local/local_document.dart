import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:html/parser.dart' as html_parser;

import '../constants/constants.dart';
import '../models/book.dart';
import '../models/aux_entities.dart';
import 'epub_file.dart';
import 'text_file.dart';

/// 统一的本地文档格式，供应用层 adapter 和导出器使用。
enum LocalDocumentFormat { txt, epub, mobi, kf8, pdf }

class CanonicalChapter {
  const CanonicalChapter({
    required this.id,
    required this.title,
    required this.content,
    this.index = 0,
  });

  final String id;
  final String title;
  final String content;
  final int index;
}

/// 所有本地格式都归一为同一份只读文档模型。
class CanonicalDocument {
  CanonicalDocument({
    required this.book,
    required this.format,
    required this.chapters,
    required this.rawBytes,
    this.resources = const <String, Uint8List>{},
    this.outlines = const <String>[],
  });

  final Book book;
  final LocalDocumentFormat format;
  final List<CanonicalChapter> chapters;
  final Uint8List rawBytes;
  final Map<String, Uint8List> resources;

  /// Best-effort PDF outline labels when the source exposes literal titles.
  final List<String> outlines;

  bool get isPdf => format == LocalDocumentFormat.pdf;
  bool get isHtml =>
      format == LocalDocumentFormat.epub ||
      format == LocalDocumentFormat.mobi ||
      format == LocalDocumentFormat.kf8;

  String contentFor(String id) => chapters
      .firstWhere(
        (chapter) => chapter.id == id,
        orElse: () => chapters.isEmpty
            ? const CanonicalChapter(id: '', title: '', content: '')
            : chapters.first,
      )
      .content;
}

/// 纯 Dart 本地文档 parser。Flutter 只负责文件选择和展示。
class LocalDocumentParser {
  const LocalDocumentParser();

  CanonicalDocument parseTxt(
    Uint8List bytes, {
    String? fileName,
    String? overrideName,
    List<TxtTocRule> tocRules = const [],
  }) {
    final book = _book(fileName ?? '本地书.txt', overrideName);
    final text = TextFile(book, bytes);
    final sourceChapters = text.getChapterList(tocRules);
    final chapters = [
      for (var i = 0; i < sourceChapters.length; i++)
        CanonicalChapter(
          id: sourceChapters[i].url,
          title: sourceChapters[i].title,
          content: text.getContent(sourceChapters[i]),
          index: i,
        ),
    ];
    return CanonicalDocument(
      book: book,
      format: LocalDocumentFormat.txt,
      chapters: chapters,
      rawBytes: bytes,
    );
  }

  CanonicalDocument parseEpub(
    Uint8List bytes, {
    String? fileName,
    String? overrideName,
  }) {
    final book = _book(fileName ?? '本地书.epub', overrideName);
    final epub = EpubFile(book, bytes);
    final sourceChapters = epub.getChapterList();
    if (sourceChapters.isEmpty) throw StateError('EPUB 未找到可读章节');
    final chapters = [
      for (var i = 0; i < sourceChapters.length; i++)
        CanonicalChapter(
          id: sourceChapters[i].url,
          title: sourceChapters[i].title,
          content: _epubContent(epub, sourceChapters[i]),
          index: i,
        ),
    ];
    return CanonicalDocument(
      book: book,
      format: LocalDocumentFormat.epub,
      chapters: chapters,
      rawBytes: bytes,
    );
  }

  CanonicalDocument parseMobi(
    Uint8List bytes, {
    String? fileName,
    String? overrideName,
  }) {
    final mobi = MobiFile.parse(bytes);
    final book = _book(fileName ?? 'book.mobi', overrideName);
    if (mobi.title.isNotEmpty && overrideName == null) book.name = mobi.title;
    if (mobi.author.isNotEmpty) book.author = mobi.author;
    final format = mobi.isKf8
        ? LocalDocumentFormat.kf8
        : LocalDocumentFormat.mobi;
    final chapters = [
      for (var i = 0; i < mobi.chapters.length; i++)
        CanonicalChapter(
          id: '${book.bookUrl}#mobi$i',
          title: mobi.chapters[i].title,
          content: mobi.chapters[i].content,
          index: i,
        ),
    ];
    return CanonicalDocument(
      book: book,
      format: format,
      chapters: chapters,
      rawBytes: bytes,
    );
  }

  CanonicalDocument parsePdf(
    Uint8List bytes, {
    String? fileName,
    String? overrideName,
  }) {
    final pdf = PdfFile.parse(bytes);
    final book = _book(fileName ?? '文档.pdf', overrideName);
    if (pdf.title.isNotEmpty && overrideName == null) book.name = pdf.title;
    if (pdf.author.isNotEmpty) book.author = pdf.author;
    final count = pdf.pageCount;
    final chapters = [
      for (var i = 0; i < count; i++)
        CanonicalChapter(
          id: '${book.bookUrl}#pdf$i',
          title: count == 1 ? book.name : '第${i + 1}页',
          content: i < pdf.pageTexts.length ? pdf.pageTexts[i] : '',
          index: i,
        ),
    ];
    return CanonicalDocument(
      book: book,
      format: LocalDocumentFormat.pdf,
      chapters: chapters,
      rawBytes: bytes,
      outlines: pdf.outlines,
    );
  }

  static Book _book(String fileName, String? overrideName) => Book(
    bookUrl: 'local:${fileName}_${DateTime.now().millisecondsSinceEpoch}',
    name: overrideName ?? _stripExt(fileName),
    origin: BookType.localTag,
    originName: fileName,
    type: BookType.local | BookType.text,
  );

  static String _stripExt(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  static String _epubContent(EpubFile epub, BookChapter chapter) {
    var html = epub.getContent(chapter);
    for (final match in RegExp(r'''epub://([^"']+)''').allMatches(html)) {
      final image = epub.getImage(match.group(1)!);
      if (image == null) continue;
      final path = match.group(1)!.toLowerCase();
      final mime = path.endsWith('.png')
          ? 'image/png'
          : path.endsWith('.gif')
          ? 'image/gif'
          : path.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
      html = html.replaceFirst(
        match.group(0)!,
        'data:$mime;base64,${base64Encode(image)}',
      );
    }
    return html;
  }
}

class MobiChapterData {
  const MobiChapterData(this.title, this.content);
  final String title;
  final String content;
}

class MobiFile {
  const MobiFile({
    required this.chapters,
    this.title = '',
    this.author = '',
    this.isKf8 = false,
  });

  final List<MobiChapterData> chapters;
  final String title;
  final String author;
  final bool isKf8;

  static MobiFile parse(Uint8List bytes) {
    if (bytes.length < 90) throw StateError('MOBI 文件太短');
    final bd = ByteData.sublistView(bytes);
    final nrec = bd.getUint16(76);
    if (nrec < 2 || 78 + nrec * 8 > bytes.length) {
      throw StateError('MOBI PDB 记录表无效');
    }
    final offsets = <int>[];
    for (var i = 0; i < nrec; i++) offsets.add(bd.getUint32(78 + i * 8));
    offsets.add(bytes.length);
    final rec0 = offsets.first;
    if (rec0 + 16 > bytes.length) throw StateError('MOBI PalmDOC 头缺失');
    final compression = bd.getUint16(rec0);
    final textLength = bd.getUint32(rec0 + 4);
    final recCount = bd.getUint16(rec0 + 8);
    var version = 0;
    var encoding = 65001;
    var exthFlags = 0;
    var headerLength = 0;
    if (rec0 + 20 <= bytes.length && _ascii(bytes, rec0 + 16, 4) == 'MOBI') {
      final mobi = rec0 + 16;
      if (mobi + 0x84 + 4 > bytes.length) {
        throw StateError('KF8/MOBI header truncated');
      }
      headerLength = _u32(bytes, mobi + 4);
      version = _u32(bytes, mobi + 0x14);
      encoding = _u32(bytes, mobi + 0x0c);
      exthFlags = _u32(bytes, mobi + 0x80);
    }
    final exth = _readExth(bytes, rec0 + 16, headerLength, exthFlags);
    final raw = BytesBuilder(copy: false);
    final limit = (1 + recCount).clamp(1, nrec);
    var huffRecord = 0;
    var huffCount = 0;
    if (rec0 + 132 <= bytes.length && _ascii(bytes, rec0 + 16, 4) == 'MOBI') {
      huffRecord = _u32(bytes, rec0 + 16 + 0x70);
      huffCount = _u32(bytes, rec0 + 16 + 0x74);
    }
    for (var i = 1; i < limit; i++) {
      final start = offsets[i], end = offsets[i + 1];
      if (start >= end || end > bytes.length) continue;
      final record = Uint8List.sublistView(bytes, start, end);
      if (compression == 2) {
        raw.add(_palmdocInflate(record));
      } else if (compression == 1) {
        raw.add(record);
      } else if (compression == 17480 && huffCount > 0) {
        raw.add(_huffInflate(record, bytes, offsets, huffRecord, huffCount));
      } else {
        throw StateError('不支持的 MOBI 压缩 $compression');
      }
      if (textLength > 0 && raw.length >= textLength) break;
    }
    var data = raw.toBytes();
    if (textLength > 0 && data.length > textLength)
      data = data.sublist(0, textLength);
    var text = _decode(data, encoding);
    final isKf8 = version >= 8 || exth.boundary != null;
    // Dual MOBI/KF8 files keep the legacy PalmDOC stream before an EXTH
    // boundary and store the KF8 flow/skeleton records afterwards.  The
    // complete skeleton/fragment index is platform specific, but a number of
    // generators emit a directly readable HTML flow.  Read that flow when the
    // legacy stream is empty or clearly binary so a valid KF8 does not appear
    // as an empty book.
    if (isKf8 && exth.boundary != null) {
      final kf8Text = _extractKf8Flow(bytes, offsets, nrec, exth.boundary!);
      if (_looksLikeText(kf8Text) &&
          (!_looksLikeText(text) || text.trim().isEmpty)) {
        text = kf8Text;
      }
    }
    if (text.replaceAll('\u0000', '').trim().isEmpty) {
      throw StateError('MOBI/KF8 内容为空');
    }
    final chapters = _splitChapters(text);
    return MobiFile(
      chapters: chapters,
      title: exth.title,
      author: exth.author,
      isKf8: isKf8,
    );
  }

  static String _extractKf8Flow(
    Uint8List bytes,
    List<int> offsets,
    int nrec,
    int boundary,
  ) {
    if (boundary < 0 || boundary >= nrec) return '';
    final headerStart = offsets[boundary];
    if (headerStart + 20 > bytes.length) return '';
    final compression = ByteData.sublistView(bytes).getUint16(headerStart);
    final textLength = ByteData.sublistView(bytes).getUint32(headerStart + 4);
    final recCount = ByteData.sublistView(bytes).getUint16(headerStart + 8);
    var encoding = 65001;
    var huffRecord = 0;
    var huffCount = 0;
    final mobiStart = headerStart + 16;
    if (mobiStart + 0x84 <= bytes.length &&
        _ascii(bytes, mobiStart, 4) == 'MOBI') {
      encoding = _u32(bytes, mobiStart + 0x0c);
      if (mobiStart + 0x78 <= bytes.length) {
        huffRecord = _u32(bytes, mobiStart + 0x70);
        huffCount = _u32(bytes, mobiStart + 0x74);
      }
    }
    final start = boundary + 1;
    final end = recCount > 0
        ? (start + recCount > nrec ? nrec : start + recCount)
        : nrec;
    final out = StringBuffer();
    for (var i = start; i < end; i++) {
      final recordStart = offsets[i], recordEnd = offsets[i + 1];
      if (recordStart >= recordEnd || recordEnd > bytes.length) continue;
      final record = Uint8List.sublistView(bytes, recordStart, recordEnd);
      Uint8List expanded;
      try {
        if (compression == 1) {
          expanded = record;
        } else if (compression == 2) {
          expanded = _palmdocInflate(record);
        } else if (compression == 17480 && huffCount > 0) {
          expanded = _huffInflate(
            record,
            bytes,
            offsets,
            huffRecord,
            huffCount,
          );
        } else {
          continue;
        }
      } catch (_) {
        continue;
      }
      final candidate = _decode(expanded, encoding);
      if (!_looksLikeText(candidate)) continue;
      out.write(candidate);
      if (textLength > 0 && out.length >= textLength) break;
    }
    return out.toString();
  }

  static bool _looksLikeText(String value) {
    final text = value.replaceAll('\u0000', '').trim();
    if (text.isEmpty) return false;
    final sample = text.length > 4096 ? text.substring(0, 4096) : text;
    var printable = 0;
    for (final code in sample.runes) {
      if (code == 9 ||
          code == 10 ||
          code == 13 ||
          (code >= 0x20 && code != 0x7f)) {
        printable++;
      }
    }
    final ratio = printable / sample.runes.length.clamp(1, 1 << 30);
    return ratio >= 0.72 &&
        (text.contains('<') || text.contains('>') || ratio >= 0.88);
  }

  static List<MobiChapterData> _splitChapters(String input) {
    final normalized = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final pageParts = normalized.split(
      RegExp(r'<mbp:pagebreak\b[^>]*>', caseSensitive: false),
    );
    final parts = pageParts.length > 1 ? pageParts : _headingParts(normalized);
    final out = <MobiChapterData>[];
    for (var i = 0; i < parts.length; i++) {
      final content = parts[i].trim();
      if (content.isEmpty) continue;
      final title = _title(content, i);
      out.add(MobiChapterData(title, content));
    }
    return out.isEmpty ? [MobiChapterData('第1章', normalized)] : out;
  }

  static List<String> _headingParts(String text) {
    final matches = RegExp(
      r'<h[1-6]\b[^>]*>',
      caseSensitive: false,
    ).allMatches(text).toList();
    if (matches.length < 2) return [text];
    return [
      for (var i = 0; i < matches.length; i++)
        text.substring(
          matches[i].start,
          i + 1 < matches.length ? matches[i + 1].start : text.length,
        ),
    ];
  }

  static String _title(String content, int index) {
    final heading = RegExp(
      r'<h[1-6]\b[^>]*>([\s\S]*?)</h[1-6]>',
      caseSensitive: false,
    ).firstMatch(content);
    if (heading != null) {
      final text =
          html_parser.parseFragment(heading.group(1) ?? '').text?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    final line = content
        .split('\n')
        .first
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
    return line.isEmpty || line.length > 80 ? '第${index + 1}章' : line;
  }

  static String _decode(Uint8List data, int encoding) {
    if (data.isEmpty) return '';
    // PalmDOC/KF8 files occasionally carry a BOM even when the MOBI
    // encoding field is stale. Honour it first; otherwise Chinese books
    // labelled 936/GBK were previously decoded as Latin-1 and looked empty.
    if (data.length >= 2 && data[0] == 0xff && data[1] == 0xfe) {
      return _decodeUtf16(data.sublist(2), littleEndian: true);
    }
    if (data.length >= 2 && data[0] == 0xfe && data[1] == 0xff) {
      return _decodeUtf16(data.sublist(2), littleEndian: false);
    }
    if (encoding == 1200 || encoding == 12000) {
      return _decodeUtf16(data, littleEndian: true);
    }
    if (encoding == 1201 || encoding == 12001) {
      return _decodeUtf16(data, littleEndian: false);
    }
    if (encoding == 65001 || encoding == 0) {
      return utf8.decode(data, allowMalformed: true);
    }
    if (encoding == 950) {
      return const Big5Codec(allowInvalid: true).decode(data);
    }
    if (encoding == 936 || encoding == 54936) {
      return const GbkCodec(allowInvalid: true).decode(data);
    }
    return latin1.decode(data, allowInvalid: true);
  }

  static String _decodeUtf16(List<int> bytes, {required bool littleEndian}) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final unit = littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1];
      units.add(unit);
    }
    return String.fromCharCodes(units);
  }

  static _ExthData _readExth(
    Uint8List file,
    int mobiStart,
    int headerLength,
    int flags,
  ) {
    if (headerLength <= 0 || (flags & 0x40) == 0) return const _ExthData();
    final start = mobiStart + headerLength;
    if (start + 12 > file.length || _ascii(file, start, 4) != 'EXTH')
      return const _ExthData();
    final count = _u32(file, start + 8);
    var pos = start + 12;
    var title = '', author = '';
    int? boundary;
    for (var i = 0; i < count && pos + 8 <= file.length; i++) {
      final type = _u32(file, pos), len = _u32(file, pos + 4);
      if (len < 8 || pos + len > file.length) break;
      final value = Uint8List.sublistView(file, pos + 8, pos + len);
      final decoded = utf8.decode(value, allowMalformed: true).trim();
      if (type == 503) title = decoded;
      if (type == 100) author = decoded;
      if (type == 121 && value.length >= 4)
        boundary = ByteData.sublistView(value).getUint32(0);
      pos += len;
    }
    return _ExthData(title: title, author: author, boundary: boundary);
  }

  static Uint8List _palmdocInflate(Uint8List src) {
    final out = <int>[];
    var i = 0;
    while (i < src.length) {
      final c = src[i++];
      if (c >= 1 && c <= 8) {
        for (var k = 0; k < c && i < src.length; k++) out.add(src[i++]);
      } else if (c >= 0x80 && c <= 0xbf && i < src.length) {
        final c2 = src[i++];
        final dist = ((c << 8 | c2) >> 3) & 0x7ff;
        final len = (c2 & 7) + 3;
        if (dist == 0 || dist > out.length) continue;
        for (var k = 0; k < len; k++) out.add(out[out.length - dist]);
      } else if (c >= 0xc0) {
        out
          ..add(0x20)
          ..add(c ^ 0x80);
      } else {
        out.add(c);
      }
    }
    return Uint8List.fromList(out);
  }

  static Uint8List _huffInflate(
    Uint8List src,
    Uint8List file,
    List<int> offsets,
    int huffRecord,
    int huffCount,
  ) {
    if (huffRecord <= 0 || huffRecord + huffCount >= offsets.length)
      throw StateError('HUFF/CDIC 记录无效');
    final huff = Uint8List.sublistView(
      file,
      offsets[huffRecord],
      offsets[huffRecord + 1],
    );
    if (_ascii(huff, 0, 4) != 'HUFF' || huff.length < 16)
      throw StateError('HUFF 头无效');
    final offset1 = _u32(huff, 8), offset2 = _u32(huff, 12);
    if (offset1 + 1024 > huff.length || offset2 + 256 > huff.length)
      throw StateError('HUFF 表越界');
    final table1 = List<int>.generate(256, (i) => _u32(huff, offset1 + i * 4));
    final mincodes = List<int>.filled(33, 0),
        maxcodes = List<int>.filled(33, 0);
    for (var i = 1; i <= 32; i++) {
      final min = _u32(huff, offset2 + (i - 1) * 8);
      final max = _u32(huff, offset2 + (i - 1) * 8 + 4);
      mincodes[i] = min << (32 - i);
      maxcodes[i] = (((max + 1) << (32 - i)) - 1) & 0xffffffff;
    }
    final dict = <Uint8List>[];
    for (var n = 1; n < huffCount; n++) {
      final index = huffRecord + n;
      final record = Uint8List.sublistView(
        file,
        offsets[index],
        offsets[index + 1],
      );
      if (_ascii(record, 0, 4) != 'CDIC' || record.length < 16)
        throw StateError('CDIC 头无效');
      final length = _u32(record, 4),
          count = _u32(record, 8),
          codeLength = _u32(record, 12);
      if (codeLength > 20 || length + count * 2 > record.length)
        throw StateError('CDIC 表越界');
      final take = (1 << codeLength).clamp(0, count);
      for (var j = 0; j < take; j++) {
        final entryOffset = _u16(record, length + j * 2);
        final packed = _u16(record, entryOffset);
        final len = packed & 0x7fff;
        if (entryOffset + 2 + len > record.length)
          throw StateError('CDIC 内容越界');
        dict.add(
          Uint8List.sublistView(record, entryOffset + 2, entryOffset + 2 + len),
        );
      }
    }
    if (dict.isEmpty) throw StateError('CDIC 词典为空');
    final out = BytesBuilder(copy: false);
    var bit = 0;
    int peek() {
      var value = 0;
      for (var i = 0; i < 32; i++)
        value =
            (value << 1) |
            (bit + i < src.length * 8
                ? ((src[(bit + i) >> 3] >> (7 - ((bit + i) & 7))) & 1)
                : 0);
      return value;
    }

    while (bit < src.length * 8) {
      final code = peek();
      final t = table1[(code >> 24) & 255];
      var len = t & 31;
      if (len < 1 || len > 32) throw StateError('HUFF 编码长度无效');
      var max = ((((t >> 8) + 1) << (32 - len)) - 1) & 0xffffffff;
      if ((t & 0x80) == 0) {
        while (len < 32 && code < mincodes[len]) len++;
        max = maxcodes[len];
      }
      if (bit + len > src.length * 8) break;
      bit += len;
      final index = (max - code) >> (32 - len);
      if (index < 0 || index >= dict.length) throw StateError('HUFF 词典索引无效');
      out.add(dict[index]);
    }
    return out.toBytes();
  }

  static String _ascii(Uint8List b, int start, int length) =>
      String.fromCharCodes(b.sublist(start, start + length));
  static int _u16(Uint8List b, int at) => (b[at] << 8) | b[at + 1];
  static int _u32(Uint8List b, int at) =>
      (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];
}

class _ExthData {
  const _ExthData({this.title = '', this.author = '', this.boundary});
  final String title;
  final String author;
  final int? boundary;
}

class PdfFile {
  const PdfFile({
    required this.pageCount,
    this.title = '',
    this.author = '',
    this.pageTexts = const <String>[],
    this.outlines = const <String>[],
  });
  final int pageCount;
  final String title;
  final String author;

  /// Best-effort text extracted from uncompressed page content streams.
  /// Compressed streams remain delegated to the platform PDF viewer.
  final List<String> pageTexts;
  final List<String> outlines;

  static PdfFile parse(Uint8List bytes) {
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw StateError('PDF 文件头无效');
    }
    final text = latin1.decode(bytes, allowInvalid: true);
    final pages = RegExp(r'/Type\s*/Page\b').allMatches(text).length;
    final title = _info(text, 'Title');
    final author = _info(text, 'Author');
    final pageTexts = _pageTexts(text);
    final outlines = [
      for (final match in RegExp(r'/Title\s*\(([^)]*)\)').allMatches(text))
        _decodePdfString(match.group(1) ?? ''),
    ];
    return PdfFile(
      pageCount: pages == 0 ? 1 : pages,
      title: title,
      author: author,
      pageTexts: pageTexts,
      outlines: outlines,
    );
  }

  static String _info(String text, String key) {
    final m = RegExp('/$key\\s*\\(([^)]*)\\)').firstMatch(text);
    return _decodePdfString(m?.group(1) ?? '');
  }

  static List<String> _pageTexts(String source) {
    final objects = <int, String>{};
    final objectRe = RegExp(r'(\d+)\s+\d+\s+obj\b([\s\S]*?)endobj');
    for (final match in objectRe.allMatches(source)) {
      final id = int.tryParse(match.group(1) ?? '');
      if (id != null) objects[id] = match.group(2) ?? '';
    }
    final streams = <int, String>{};
    for (final entry in objects.entries) {
      final body = entry.value;
      final stream = RegExp(
        r'stream\r?\n([\s\S]*?)\r?\nendstream',
      ).firstMatch(body);
      if (stream == null) continue;
      final payload = latin1.encode(stream.group(1) ?? '');
      final decoded = _decodePdfStream(payload, body);
      if (decoded == null) continue;
      streams[entry.key] = latin1.decode(decoded, allowInvalid: true);
    }
    final pages = <String>[];
    for (final body in objects.values) {
      if (!RegExp(r'/Type\s*/Page\b').hasMatch(body)) continue;
      final refs = RegExp(
        r'/Contents\s+(?:\[([^]]+)\]|(\d+)\s+\d+\s+R)',
      ).firstMatch(body);
      if (refs == null) {
        pages.add('');
        continue;
      }
      final ids = <int>[];
      final list = refs.group(1);
      if (list != null) {
        for (final ref in RegExp(r'(\d+)\s+\d+\s+R').allMatches(list)) {
          final id = int.tryParse(ref.group(1) ?? '');
          if (id != null) ids.add(id);
        }
      } else {
        final id = int.tryParse(refs.group(2) ?? '');
        if (id != null) ids.add(id);
      }
      pages.add(ids.map((id) => _extractText(streams[id] ?? '')).join('\n'));
    }
    return pages;
  }

  static String _extractText(String stream) {
    if (stream.isEmpty) return '';
    final parts = <String>[];
    // Both literal `(text)` and hexadecimal `<FEFF...>` strings occur in
    // real PDFs. Keep the scanner permissive because content streams can
    // contain nested escaped parentheses and arbitrary spacing.
    final tokenRe = RegExp(
      r'(?:\((?:\\.|[^\\)])*\)|<[0-9A-Fa-f\\s]+>)\s*Tj|\[(?:[^\]]|\\.)*\]\s*TJ',
    );
    for (final match in tokenRe.allMatches(stream)) {
      final token = match.group(0) ?? '';
      if (token.startsWith('[')) {
        final arrayRe = RegExp(r'\((?:\\.|[^\\)])*\)|<[0-9A-Fa-f\\s]+>');
        for (final string in arrayRe.allMatches(token)) {
          final raw = string.group(0)!;
          parts.add(
            raw.startsWith('<')
                ? _decodePdfHexString(raw)
                : _decodePdfString(raw.substring(1, raw.length - 1)),
          );
        }
      } else {
        final raw = token.trimLeft();
        if (raw.startsWith('<')) {
          final end = raw.indexOf('>');
          if (end > 0)
            parts.add(_decodePdfHexString(raw.substring(0, end + 1)));
        } else {
          final end = raw.lastIndexOf(')');
          if (end > 0) parts.add(_decodePdfString(raw.substring(1, end)));
        }
      }
    }
    return parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Uint8List? _decodePdfStream(Uint8List payload, String dictionary) {
    final filters = _pdfFilters(dictionary);
    var data = payload;
    for (final filter in filters) {
      try {
        switch (filter) {
          case 'FlateDecode':
          case 'Fl':
            try {
              data = Uint8List.fromList(ZLibDecoder().decodeBytes(data));
            } catch (_) {
              data = Uint8List.fromList(
                ZLibDecoder().decodeBytes(data, raw: true),
              );
            }
          case 'ASCIIHexDecode':
          case 'AHx':
            data = _asciiHexDecode(data);
          case 'ASCII85Decode':
          case 'A85':
            data = _ascii85Decode(data);
          case 'LZWDecode':
          case 'LZW':
            data = _lzwDecode(data, _lzwEarlyChange(dictionary));
          case 'Identity':
            break;
          default:
            return null;
        }
      } catch (_) {
        return null;
      }
    }
    return data;
  }

  static List<String> _pdfFilters(String dictionary) {
    final array = RegExp(
      r'/Filter\s*\[([^\]]+)\]',
      dotAll: true,
    ).firstMatch(dictionary)?.group(1);
    if (array != null) {
      return [
        for (final m in RegExp(r'/([A-Za-z0-9]+)').allMatches(array))
          m.group(1)!,
      ];
    }
    final one = RegExp(r'/Filter\s*/([A-Za-z0-9]+)').firstMatch(dictionary);
    return one == null ? const ['Identity'] : [one.group(1)!];
  }

  static int _lzwEarlyChange(String dictionary) {
    final m = RegExp(r'/EarlyChange\s+(\d+)').firstMatch(dictionary);
    return m == null ? 1 : (int.tryParse(m.group(1)!) ?? 1).clamp(0, 1);
  }

  static Uint8List _asciiHexDecode(List<int> input) {
    final out = <int>[];
    var high = -1;
    for (final byte in input) {
      if (byte == 0x3e) break; // `>` EOD marker
      final c = String.fromCharCode(byte);
      if (RegExp(r'\s').hasMatch(c)) continue;
      final value = int.tryParse(c, radix: 16);
      if (value == null) continue;
      if (high < 0) {
        high = value;
      } else {
        out.add((high << 4) | value);
        high = -1;
      }
    }
    if (high >= 0) out.add(high << 4);
    return Uint8List.fromList(out);
  }

  static Uint8List _ascii85Decode(List<int> input) {
    final out = <int>[];
    final group = <int>[];
    var i = 0;
    if (input.length >= 2 && input[0] == 0x3c && input[1] == 0x7e) {
      i = 2; // Adobe `<~ ... ~>` framing
    }
    while (i < input.length) {
      final b = input[i++];
      if (b == 0x7e) {
        // `~>` marks end of data; the trailing `>` is consumed if present.
        if (i < input.length && input[i] == 0x3e) i++;
        break;
      }
      if (b <= 0x20) continue;
      if (b == 0x7a && group.isEmpty) {
        out.addAll(const [0, 0, 0, 0]);
        continue;
      }
      if (b < 0x21 || b > 0x75) continue;
      group.add(b - 0x21);
      if (group.length == 5) {
        var value = 0;
        for (final digit in group) value = value * 85 + digit;
        out.add((value >> 24) & 0xff);
        out.add((value >> 16) & 0xff);
        out.add((value >> 8) & 0xff);
        out.add(value & 0xff);
        group.clear();
      }
    }
    if (group.isNotEmpty) {
      final count = group.length;
      while (group.length < 5) group.add(84);
      var value = 0;
      for (final digit in group) value = value * 85 + digit;
      for (var j = 0; j < count - 1; j++) {
        out.add((value >> (24 - j * 8)) & 0xff);
      }
    }
    return Uint8List.fromList(out);
  }

  static Uint8List _lzwDecode(List<int> input, int earlyChange) {
    var bit = 0;
    int readCode(int width) {
      if (bit + width > input.length * 8) return -1;
      var value = 0;
      for (var i = 0; i < width; i++) {
        value =
            (value << 1) |
            ((input[(bit + i) >> 3] >> (7 - ((bit + i) & 7))) & 1);
      }
      bit += width;
      return value;
    }

    final out = <int>[];
    // Keep slots 256/257 reserved for CLEAR/EOD so dictionary indexes line up
    // with the PDF specification.
    var table = <List<int>?>[
      for (var i = 0; i < 256; i++) [i],
      null,
      null,
    ];
    const clear = 256, eod = 257;
    var width = 9;
    var nextCode = 258;
    List<int>? previous;
    while (true) {
      final code = readCode(width);
      if (code < 0 || code == eod) break;
      if (code == clear) {
        table = <List<int>?>[
          for (var i = 0; i < 256; i++) [i],
          null,
          null,
        ];
        width = 9;
        nextCode = 258;
        previous = null;
        continue;
      }
      List<int>? entry;
      if (code >= 0 && code < table.length) {
        entry = table[code];
      } else if (code == nextCode && previous != null) {
        entry = [...previous, previous.first];
      } else {
        break;
      }
      final decodedEntry = entry;
      if (decodedEntry == null || decodedEntry.isEmpty) break;
      out.addAll(decodedEntry);
      final prev = previous;
      if (prev != null && nextCode < 4096) {
        table.add([...prev, decodedEntry.first]);
        nextCode++;
        final threshold = (1 << width) - earlyChange;
        if (nextCode >= threshold && width < 12) width++;
      }
      previous = entry;
    }
    return Uint8List.fromList(out);
  }

  static String _decodePdfHexString(String raw) {
    final body = raw
        .substring(1, raw.lastIndexOf('>'))
        .replaceAll(RegExp(r'\s+'), '');
    final bytes = <int>[];
    for (var i = 0; i < body.length; i += 2) {
      final pair = i + 1 < body.length
          ? body.substring(i, i + 2)
          : '${body[i]}0';
      bytes.add(int.tryParse(pair, radix: 16) ?? 0);
    }
    if (bytes.length >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        units.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(units);
    }
    // Some generators omit the UTF-16 BOM but still emit a zero high byte
    // for ASCII glyphs. Detect that conservative pattern before Latin-1.
    if (bytes.length >= 2 && bytes.length.isEven) {
      final beZeros = [
        for (var i = 0; i < bytes.length; i += 2) bytes[i] == 0,
      ].where((v) => v).length;
      final leZeros = [
        for (var i = 1; i < bytes.length; i += 2) bytes[i] == 0,
      ].where((v) => v).length;
      if (beZeros >= bytes.length ~/ 2) {
        return String.fromCharCodes([
          for (var i = 0; i + 1 < bytes.length; i += 2)
            (bytes[i] << 8) | bytes[i + 1],
        ]);
      }
      if (leZeros >= bytes.length ~/ 2) {
        return String.fromCharCodes([
          for (var i = 0; i + 1 < bytes.length; i += 2)
            bytes[i] | (bytes[i + 1] << 8),
        ]);
      }
    }
    return latin1.decode(bytes, allowInvalid: true);
  }

  static String _decodePdfString(String value) {
    final out = <int>[];
    for (var i = 0; i < value.length; i++) {
      final c = value.codeUnitAt(i);
      if (c != 0x5c) {
        out.add(c);
        continue;
      }
      if (i + 1 >= value.length) break;
      final next = value.codeUnitAt(++i);
      switch (next) {
        case 0x6e:
          out.add(10);
        case 0x72:
          out.add(13);
        case 0x74:
          out.add(9);
        case 0x62:
          out.add(8);
        case 0x66:
          out.add(12);
        case 0x28:
        case 0x29:
        case 0x5c:
          out.add(next);
        default:
          if (next >= 0x30 && next <= 0x37) {
            var octal = next - 0x30;
            for (var j = 0; j < 2 && i + 1 < value.length; j++) {
              final digit = value.codeUnitAt(i + 1);
              if (digit < 0x30 || digit > 0x37) break;
              i++;
              octal = octal * 8 + digit - 0x30;
            }
            out.add(octal);
          } else {
            out.add(next);
          }
      }
    }
    if (out.length >= 2 && out[0] == 0xfe && out[1] == 0xff) {
      final units = <int>[];
      for (var i = 2; i + 1 < out.length; i += 2) {
        units.add((out[i] << 8) | out[i + 1]);
      }
      return String.fromCharCodes(units);
    }
    return latin1.decode(out, allowInvalid: true);
  }
}
