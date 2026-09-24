import '../constants/constants.dart';
import '../models/book.dart';
import '../net/network_utils.dart';

class MangaPage {
  MangaPage({
    required this.chapterIndex,
    required this.index,
    required this.imageUrl,
    required this.chapterName,
    this.imageCount = 0,
  });

  final int chapterIndex;
  final int index;
  final String imageUrl;
  final String chapterName;
  int imageCount;
}

class ContentBlock {
  const ContentBlock.text(this.value) : isImage = false;
  const ContentBlock.image(this.value) : isImage = true;

  final String value;
  final bool isImage;
}

String _chapterBase(BookChapter chapter) {
  return chapter.baseUrl.isEmpty ? chapter.url : chapter.baseUrl;
}

List<ContentBlock> splitContentBlocks(
  String content, {
  String? baseUrl,
}) {
  final out = <ContentBlock>[];
  var start = 0;
  for (final m in AppPattern.img.allMatches(content)) {
    final before = content.substring(start, m.start);
    if (before.trim().isNotEmpty) {
      out.add(ContentBlock.text(before));
    }
    var src = extractImgSrc(m.group(0)!) ?? '';
    src = normalizeMediaUrl(src);
    if (src.isNotEmpty) {
      out.add(
        ContentBlock.image(
          baseUrl == null || baseUrl.isEmpty ? src : getAbsoluteUrl(baseUrl, src),
        ),
      );
    }
    start = m.end;
  }
  final rest = content.substring(start);
  if (rest.trim().isNotEmpty) out.add(ContentBlock.text(rest));
  if (out.isEmpty && content.trim().isNotEmpty) {
    out.add(ContentBlock.text(content));
  }
  return out;
}

List<String> flowImages(BookChapter chapter, String content) {
  final base = _chapterBase(chapter);
  final urls = <String>[];
  final seen = <String>{};
  void add(String raw) {
    var src = normalizeMediaUrl(raw);
    if (src.isEmpty) return;
    if (!(src.startsWith('http') ||
        src.startsWith('/') ||
        src.startsWith('data:') ||
        src.startsWith('epub:'))) {
      return;
    }
    final abs = getAbsoluteUrl(base, src);
    if (seen.add(abs)) urls.add(abs);
  }

  for (final m in AppPattern.img.allMatches(content)) {
    final src = extractImgSrc(m.group(0)!);
    if (src != null) add(src);
  }
  if (urls.isEmpty) {
    for (final m in RegExp(
      r'''(?:src|data-src|data-original|data-lazy-src|data-url|data-echo)\s*=\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    ).allMatches(content)) {
      add(m.group(1)!);
    }
  }
  if (urls.isEmpty) {
    for (final m in RegExp(
      r'''srcset\s*=\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    ).allMatches(content)) {
      final first = m.group(1)!.split(',').first.trim().split(' ').first;
      add(first);
    }
  }
  if (urls.isEmpty) {
    for (final m in RegExp(
      r'''background-image\s*:\s*url\((['"]?)([^)'"]+)\1\)''',
      caseSensitive: false,
    ).allMatches(content)) {
      add(m.group(2)!);
    }
  }
  if (urls.isEmpty) {
    for (final m in RegExp(r'https?://[^\s"<>]+').allMatches(content)) {
      final t = normalizeMediaUrl(m.group(0)!);
      final lower = t.toLowerCase();
      if (RegExp(r'\.(jpe?g|png|webp|gif|bmp|avif)(\?|$)').hasMatch(lower) ||
          lower.contains('/upload') ||
          lower.contains('manga') ||
          lower.contains('comic') ||
          lower.contains('/images/') ||
          lower.contains('/img/')) {
        add(t);
      }
    }
  }
  return urls;
}

List<MangaPage> mangaPagesFor(BookChapter chapter, String content, int chapterSize) {
  final urls = flowImages(chapter, content);
  final pages = <MangaPage>[];
  for (var i = 0; i < urls.length; i++) {
    pages.add(
      MangaPage(
        chapterIndex: chapter.index,
        index: i,
        imageUrl: urls[i],
        chapterName: chapter.title,
        imageCount: urls.length,
      ),
    );
  }
  return pages;
}
