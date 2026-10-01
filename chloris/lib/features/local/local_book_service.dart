import 'dart:typed_data';

import 'package:chloris_engine/chloris_engine.dart';

import 'umd_file.dart';

/// 应用层只保留兼容旧 UI 的 adapter；格式解析已经全部下沉到 engine。
class LocalBookBundle {
  LocalBookBundle({
    required this.book,
    required this.chapters,
    required this.document,
    this.txt,
    this.epub,
    this.rawBytes,
    this.isPdf = false,
    this.umdTexts,
    this.htmlContent,
    this.chapterContent,
    this.format,
    this.htmlDocument = false,
    this.isUmd = false,
  });

  final Book book;
  final List<BookChapter> chapters;
  final CanonicalDocument? document;
  final TextFile? txt;
  final EpubFile? epub;
  final Uint8List? rawBytes;
  final bool isPdf;
  final List<String>? umdTexts;

  /// 兼容旧 UI 的 HTML 标志；正文实际按当前章节从 canonical document 读取。
  final String? htmlContent;
  final Map<String, String>? chapterContent;
  final LocalDocumentFormat? format;
  final bool htmlDocument;
  final bool isUmd;

  bool get isHtml => document?.isHtml ?? (htmlDocument || htmlContent != null);

  String content(BookChapter chapter) {
    final canonical = document;
    if (canonical != null) return canonical.contentFor(chapter.url);
    final stored = chapterContent?[chapter.url];
    if (stored != null) return stored;
    if (umdTexts != null) {
      final i = chapters.indexWhere((c) => c.url == chapter.url);
      if (i >= 0 && i < umdTexts!.length) return umdTexts![i];
    }
    return '';
  }
}

class LocalBookService {
  LocalBookService({this.tocRules = const []});

  final List<TxtTocRule> tocRules;
  final LocalDocumentParser _parser = const LocalDocumentParser();

  LocalBookBundle parseTxt(
    Uint8List bytes, {
    String? fileName,
    String? overrideName,
  }) {
    final document = _parser.parseTxt(
      bytes,
      fileName: fileName,
      overrideName: overrideName,
      tocRules: tocRules,
    );
    return _fromDocument(document, txt: TextFile(document.book, bytes));
  }

  LocalBookBundle parseEpub(
    Uint8List bytes, {
    String? fileName,
    String? overrideName,
  }) {
    final document = _parser.parseEpub(
      bytes,
      fileName: fileName,
      overrideName: overrideName,
    );
    return _fromDocument(document, epub: EpubFile(document.book, bytes));
  }

  LocalBookBundle parseMobi(
    Uint8List bytes, {
    String? fileName,
    String? overrideName,
  }) {
    final document = _parser.parseMobi(
      bytes,
      fileName: fileName,
      overrideName: overrideName,
    );
    final html = document.isHtml && document.chapters.length == 1
        ? document.chapters.first.content
        : null;
    return _fromDocument(document, htmlContent: html);
  }

  LocalBookBundle parsePdf(
    Uint8List bytes, {
    String? fileName,
    String? overrideName,
  }) {
    final document = _parser.parsePdf(
      bytes,
      fileName: fileName,
      overrideName: overrideName,
    );
    return _fromDocument(document, isPdf: true);
  }

  LocalBookBundle parseUmd(
    Uint8List bytes, {
    String? fileName,
    String? overrideName,
  }) {
    final umd = parseUmdBytes(bytes);
    final name =
        overrideName ??
        (umd.title.isNotEmpty ? umd.title : _stripExt(fileName ?? 'book.umd'));
    final book = Book(
      bookUrl:
          'local:${fileName ?? 'book.umd'}_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      origin: BookType.localTag,
      originName: fileName ?? 'book.umd',
      type: BookType.local | BookType.text,
    )..author = umd.author;
    final chapters = <BookChapter>[];
    final texts = <String>[];
    for (var i = 0; i < umd.chapters.length; i++) {
      final chapter = umd.chapters[i];
      chapters.add(
        BookChapter(
          url: '${book.bookUrl}#umd$i',
          title: chapter.title.isEmpty ? '第${i + 1}章' : chapter.title,
          bookUrl: book.bookUrl,
          index: i,
        ),
      );
      texts.add(chapter.content);
    }
    book.totalChapterNum = chapters.length;
    return LocalBookBundle(
      book: book,
      chapters: chapters,
      document: null,
      rawBytes: bytes,
      umdTexts: texts,
      isUmd: true,
    );
  }

  LocalBookBundle _fromDocument(
    CanonicalDocument document, {
    TextFile? txt,
    EpubFile? epub,
    bool isPdf = false,
    String? htmlContent,
  }) {
    final chapters = [
      for (final chapter in document.chapters)
        BookChapter(
          url: chapter.id,
          title: chapter.title,
          bookUrl: document.book.bookUrl,
          index: chapter.index,
        ),
    ];
    document.book.totalChapterNum = chapters.length;
    return LocalBookBundle(
      book: document.book,
      chapters: chapters,
      document: document,
      txt: txt,
      epub: epub,
      rawBytes: document.rawBytes,
      isPdf: isPdf || document.isPdf,
      htmlContent: htmlContent,
      format: document.format,
      htmlDocument: document.isHtml,
    );
  }

  static String _stripExt(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}

/// Isolate entry point used for file import and legacy shelf migration. Only
/// JSON-safe metadata and chapter strings cross back to the UI isolate.
Map<String, Object?> parseLocalDocumentWorker(Map<String, Object?> args) {
  final kind = args['kind']?.toString() ?? 'txt';
  final fileName = args['fileName']?.toString() ?? 'book.txt';
  final overrideName = args['name']?.toString();
  final bytes = args['bytes'] as Uint8List;
  final rawRules = args['tocRules'];
  final rules = rawRules is List
      ? rawRules
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .map(TxtTocRule.fromJson)
            .toList(growable: false)
      : const <TxtTocRule>[];
  final service = LocalBookService(tocRules: rules);
  final LocalBookBundle bundle = switch (kind) {
    'epub' => service.parseEpub(
      bytes,
      fileName: fileName,
      overrideName: overrideName,
    ),
    'pdf' => service.parsePdf(
      bytes,
      fileName: fileName,
      overrideName: overrideName,
    ),
    'mobi' => service.parseMobi(
      bytes,
      fileName: fileName,
      overrideName: overrideName,
    ),
    'umd' => service.parseUmd(
      bytes,
      fileName: fileName,
      overrideName: overrideName,
    ),
    _ => service.parseTxt(
      bytes,
      fileName: fileName,
      overrideName: overrideName,
    ),
  };
  final bookUrl = args['bookUrl']?.toString();
  if (bookUrl != null && bookUrl.isNotEmpty) {
    bundle.book.bookUrl = bookUrl;
    for (final chapter in bundle.chapters) {
      chapter.bookUrl = bookUrl;
      if (kind == 'umd') chapter.url = '$bookUrl#umd${chapter.index}';
    }
  }
  return {
    'book': bundle.book.toJson(),
    'kind': kind,
    'isPdf': bundle.isPdf,
    'isHtml': bundle.isHtml,
    'chapters': [for (final chapter in bundle.chapters) chapter.toJson()],
    'contents': {
      for (final chapter in bundle.chapters)
        chapter.url: bundle.content(chapter),
    },
  };
}
