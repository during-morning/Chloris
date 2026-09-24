import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/book.dart';
import '../net/network_utils.dart';

class EpubFile {
  EpubFile(this.book, this.bytes) : archive = ZipDecoder().decodeBytes(bytes);

  final Book book;
  final Uint8List bytes;
  final Archive archive;

  ArchiveFile? _file(String path) {
    final normalized = path
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/'), '');
    for (final f in archive.files) {
      if (f.name.replaceAll('\\', '/') == normalized) return f;
    }
    final tail = normalized.split('/').last;
    for (final f in archive.files) {
      if (f.name.replaceAll('\\', '/').endsWith(tail)) return f;
    }
    return null;
  }

  String? _text(String path) {
    final f = _file(path);
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  String? _attrValue(String tag, String name) {
    final match = RegExp(
      "\\b${RegExp.escape(name)}\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')",
      caseSensitive: false,
    ).firstMatch(tag);
    return match?.group(1) ?? match?.group(2);
  }

  String _tagText(String xml, String name) {
    final match = RegExp(
      '<(?:[A-Za-z0-9_-]+:)?${RegExp.escape(name)}\\b[^>]*>([\\s\\S]*?)</(?:[A-Za-z0-9_-]+:)?${RegExp.escape(name)}>',
      caseSensitive: false,
    ).firstMatch(xml);
    if (match == null) return '';
    final fragment = html_parser.parseFragment(match.group(1) ?? '');
    return (fragment.text ?? '').trim();
  }

  String _opfPath() {
    final container = _text('META-INF/container.xml');
    if (container == null) {
      final guess = archive.files.firstWhere(
        (f) => f.name.endsWith('.opf'),
        orElse: () => archive.files.first,
      );
      return guess.name;
    }
    final tag = RegExp(
      r'<rootfile\b[^>]*>',
      caseSensitive: false,
    ).firstMatch(container)?.group(0);
    return tag == null
        ? 'content.opf'
        : (_attrValue(tag, 'full-path') ?? 'content.opf');
  }

  void upBookInfo() {
    final opfPath = _opfPath();
    final opf = _text(opfPath);
    if (opf == null) return;
    final t = _tagText(opf, 'title');
    if (t.isNotEmpty) book.name = t;
    final author = _tagText(opf, 'creator');
    if (author.isNotEmpty) book.author = author;
    book.type = book.type | 0x100; // local
    book.config.useReplaceRule = false;
    String? coverId;
    for (final m in RegExp(
      r'<meta\b[^>]*>',
      caseSensitive: false,
    ).allMatches(opf)) {
      final tag = m.group(0)!;
      if ((_attrValue(tag, 'name') ?? '').toLowerCase() == 'cover') {
        coverId = _attrValue(tag, 'content');
        break;
      }
    }
    String? href;
    if (coverId != null) {
      for (final m in RegExp(
        r'<item\b[^>]*>',
        caseSensitive: false,
      ).allMatches(opf)) {
        final tag = m.group(0)!;
        if (_attrValue(tag, 'id') == coverId) {
          href = _attrValue(tag, 'href');
          break;
        }
      }
    }
    if (href == null) {
      for (final m in RegExp(
        r'<item\b[^>]*>',
        caseSensitive: false,
      ).allMatches(opf)) {
        final tag = m.group(0)!;
        if ((_attrValue(tag, 'properties') ?? '')
            .split(RegExp(r'\s+'))
            .contains('cover-image')) {
          href = _attrValue(tag, 'href');
          break;
        }
      }
    }
    if (href != null) {
      book.coverUrl = _resolve(opfPath, href);
    }
  }

  List<BookChapter> getChapterList() {
    upBookInfo();
    final opfPath = _opfPath();
    final opf = _text(opfPath) ?? '';
    String? ncxHref;
    for (final m in RegExp(
      r'<item\b[^>]*>',
      caseSensitive: false,
    ).allMatches(opf)) {
      final tag = m.group(0)!;
      if ((_attrValue(tag, 'media-type') ?? '').toLowerCase() ==
          'application/x-dtbncx+xml') {
        ncxHref = _attrValue(tag, 'href');
        break;
      }
    }
    final chapters = <BookChapter>[];
    if (ncxHref != null) {
      final ncx = _text(_resolve(opfPath, ncxHref)) ?? '';
      final ncxPath = _resolve(opfPath, ncxHref);
      final navs = RegExp(
        r'<navPoint\b[\s\S]*?<text\b[^>]*>([\s\S]*?)</text>[\s\S]*?<content\b[^>]*>',
        caseSensitive: false,
      ).allMatches(ncx);
      for (final m in navs) {
        final contentTag = RegExp(
          r'<content\b[^>]*>',
          caseSensitive: false,
        ).firstMatch(m.group(0)!)?.group(0);
        final src = contentTag == null ? null : _attrValue(contentTag, 'src');
        if (src == null || src.isEmpty) continue;
        chapters.add(
          BookChapter(
            title: htmlUnescape(
              (html_parser.parseFragment(m.group(1) ?? '').text ?? '').trim(),
            ),
            url: _resolve(ncxPath, src),
            bookUrl: book.bookUrl,
          ),
        );
      }
    }
    if (chapters.isEmpty) {
      final manifest = <String, String>{};
      for (final m in RegExp(
        r'<item\b[^>]*>',
        caseSensitive: false,
      ).allMatches(opf)) {
        final tag = m.group(0)!;
        final id = _attrValue(tag, 'id');
        final href = _attrValue(tag, 'href');
        if (id != null && href != null && href.isNotEmpty) manifest[id] = href;
      }
      final items = RegExp(
        r'<itemref\b[^>]*>',
        caseSensitive: false,
      ).allMatches(opf);
      for (final m in items) {
        final id = _attrValue(m.group(0)!, 'idref');
        final href = id == null ? null : manifest[id];
        if (href == null) continue;
        chapters.add(
          BookChapter(
            title: href.split('/').last,
            url: _resolve(opfPath, href),
            bookUrl: book.bookUrl,
          ),
        );
      }
    }
    for (var i = 0; i < chapters.length; i++) {
      chapters[i].index = i;
      final current = _fragment(chapters[i].url);
      if (current != null && current.isNotEmpty) {
        chapters[i].startFragmentId = current;
      }
      if (i + 1 < chapters.length) {
        final nextUrl = chapters[i + 1].url;
        // NCX files commonly put several navPoints in one XHTML document.
        // Keep the next fragment as an exclusive boundary only when both
        // chapters point at the same resource; crossing files must never
        // cause the current chapter to be clipped.
        if (_path(chapters[i].url) == _path(nextUrl)) {
          chapters[i].endFragmentId = _fragment(nextUrl);
        }
      }
    }
    book.totalChapterNum = chapters.length;
    return chapters;
  }

  String getContent(BookChapter chapter) {
    final href = chapter.url.split('#').first;
    var html = _text(href) ?? '';
    html = html.replaceFirst(
      RegExp(r'<head[^>]*>', caseSensitive: false),
      '<head>',
    );
    final cssHrefs = RegExp(
      "<link[^>]+href=[\\\"']([^\\\"']+\\.css)[\\\"'][^>]*>",
      caseSensitive: false,
    ).allMatches(html).map((m) => m.group(1)!).toList();
    for (final cssHref in cssHrefs) {
      final css = _text(_resolve(href, cssHref));
      if (css != null) {
        html = html.replaceFirst('</head>', '<style>$css</style></head>');
      }
    }

    final doc = html_parser.parse(html);
    doc.querySelectorAll('script,style,title').forEach((e) => e.remove());
    for (final img in doc.querySelectorAll('img')) {
      final src = img.attributes['src'];
      if (src != null && !src.startsWith('http')) {
        img.attributes['src'] = 'epub://$href::${_resolve(href, src)}';
      }
    }
    final body = doc.body;
    if (body == null) return html;
    final start = chapter.startFragmentId ?? _fragment(chapter.url);
    // [endFragmentId] is already the decoded fragment identifier populated
    // by getChapterList.  Re-parsing it as a URL would turn a plain id such
    // as "two" into null and make the first chapter consume the whole file.
    final end = chapter.endFragmentId;
    return _sliceFragments(body, start, end);
  }

  /// Returns the body range beginning at [start] and ending immediately before
  /// [end].  NCX fragment targets are normally siblings (a heading or anchor),
  /// so preserving sibling outer HTML keeps markup valid while avoiding the
  /// duplicate-full-page chapters produced by the old implementation.
  String _sliceFragments(Element body, String? start, String? end) {
    if ((start == null || start.isEmpty) && (end == null || end.isEmpty)) {
      return body.innerHtml;
    }
    Element? find(String? id) {
      if (id == null || id.isEmpty) return null;
      for (final element in body.querySelectorAll('[id], [name]')) {
        if (element.id == id || element.attributes['name'] == id)
          return element;
      }
      return null;
    }

    final startNode = find(start);
    final endNode = find(end);
    final parent = startNode?.parentNode ?? endNode?.parentNode;
    if (parent == null ||
        (startNode != null && startNode.parentNode != parent) ||
        (endNode != null && endNode.parentNode != parent)) {
      // If a malformed EPUB points at nested/different parents, retaining the
      // document is safer than returning an empty chapter.
      return body.innerHtml;
    }
    final nodes = parent.nodes;
    final from = startNode == null ? 0 : nodes.indexOf(startNode);
    final to = endNode == null ? nodes.length : nodes.indexOf(endNode);
    if (from < 0 || to < from) return body.innerHtml;
    final out = StringBuffer();
    for (var i = from; i < to && i < nodes.length; i++) {
      final node = nodes[i];
      out.write(node is Element ? node.outerHtml : node.toString());
    }
    return out.toString();
  }

  static String _path(String value) => value.split('#').first;

  static String? _fragment(String? value) {
    if (value == null) return null;
    final hash = value.indexOf('#');
    if (hash < 0 || hash + 1 >= value.length) return null;
    return Uri.decodeComponent(value.substring(hash + 1));
  }

  Uint8List? getImage(String href) {
    final path = href.contains('::') ? href.split('::').last : href;
    final f = _file(path);
    if (f == null) return null;
    return Uint8List.fromList(f.content as List<int>);
  }

  String _resolve(String base, String rel) {
    if (rel.startsWith('http')) return rel;
    final baseDir = base.contains('/')
        ? base.substring(0, base.lastIndexOf('/') + 1)
        : '';
    final combined = (baseDir + rel).replaceAll('\\', '/');
    final parts = <String>[];
    for (final p in combined.split('/')) {
      if (p.isEmpty || p == '.') continue;
      if (p == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(p);
      }
    }
    return parts.join('/');
  }
}
