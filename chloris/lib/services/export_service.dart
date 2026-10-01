import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../features/local/local_book_service.dart';
import 'export_filename.dart';

/// Builds downloadable book representations without platform dependencies.
class ExportService {
  const ExportService();

  String buildTxt(LocalBookBundle bundle) {
    final sb = StringBuffer();
    sb.writeln(bundle.book.name);
    sb.writeln();
    for (final ch in bundle.chapters) {
      sb.writeln(ch.title);
      final text = bundle.content(ch);
      if (text.isNotEmpty) {
        sb.writeln(text);
        sb.writeln();
      }
    }
    return sb.toString();
  }

  Uint8List buildTxtBytes(LocalBookBundle bundle) =>
      Uint8List.fromList(utf8.encode(buildTxt(bundle)));

  /// 按导出文件名模板生成文件名（不含扩展名）。
  ///
  /// 默认模板见 [kDefaultExportFileNameTemplate]（`{书名}{-作者}`）。
  String exportBaseName(
    LocalBookBundle bundle, {
    String template = kDefaultExportFileNameTemplate,
  }  ) =>
      applyExportTemplate(template, bundle.book.name, bundle.book.author);

  Uint8List buildEpub(LocalBookBundle bundle) {
    final archive = Archive();
    final mime = utf8.encode('application/epub+zip');
    archive.addFile(ArchiveFile('mimetype', mime.length, mime));
    final container = utf8.encode(_containerXml);
    archive.addFile(
      ArchiveFile('META-INF/container.xml', container.length, container),
    );
    final manifest = StringBuffer();
    final spine = StringBuffer();
    final nav = StringBuffer();
    for (var i = 0; i < bundle.chapters.length; i++) {
      final id = 'chapter$i';
      final file = 'chapter$i.xhtml';
      manifest.writeln(
        '<item id="$id" href="$file" media-type="application/xhtml+xml"/>',
      );
      spine.writeln('<itemref idref="$id"/>');
      nav.writeln(
        '<li><a href="$file">${_escape(bundle.chapters[i].title)}</a></li>',
      );
      final data = utf8.encode(
        _chapterXhtml(
          bundle.chapters[i].title,
          bundle.content(bundle.chapters[i]),
        ),
      );
      archive.addFile(ArchiveFile('OEBPS/$file', data.length, data));
    }
    final opf = utf8.encode(
      _opf(bundle.book.name, manifest.toString(), spine.toString()),
    );
    archive.addFile(ArchiveFile('OEBPS/content.opf', opf.length, opf));
    final navDoc = utf8.encode(_navXhtml(bundle.book.name, nav.toString()));
    archive.addFile(ArchiveFile('OEBPS/nav.xhtml', navDoc.length, navDoc));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _chapterXhtml(String title, String content) {
    final value = content.trim();
    final body = RegExp(r'<[a-zA-Z][^>]*>').hasMatch(value)
        ? value
        : value
              .split(RegExp(r'\n\s*\n'))
              .map((p) => '<p>${_escape(p).replaceAll('\n', '<br/>')}</p>')
              .join();
    return '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>${_escape(title)}</title></head><body><h1>${_escape(title)}</h1>$body</body></html>';
  }

  static String _opf(String title, String manifest, String spine) =>
      '<?xml version="1.0" encoding="utf-8"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="bookid">chloris-book</dc:identifier><dc:title>${_escape(title)}</dc:title><dc:creator>Cholris</dc:creator><dc:language>zh</dc:language></metadata><manifest><item id="nav" href="nav.xhtml" properties="nav" media-type="application/xhtml+xml"/>$manifest</manifest><spine>$spine</spine></package>';
  static String _navXhtml(String title, String items) =>
      '<?xml version="1.0" encoding="utf-8"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>${_escape(title)}</title></head><body><nav epub:type="toc"><h1>${_escape(title)}</h1><ol>$items</ol></nav></body></html>';
  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  static const _containerXml =
      '<?xml version="1.0" encoding="UTF-8"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>';
}
