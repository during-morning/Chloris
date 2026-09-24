import 'package:chloris_engine/chloris_engine.dart';

/// 对单章正文分页。纯 Dart，便于单测与跨平台。
class PaginatedChapter {
  PaginatedChapter({
    required this.content,
    required this.pages,
    required this.totalChars,
    this.consumedChars = 0,
  });

  final String content;
  final List<TextPage> pages;
  final int totalChars;

  /// 本次分页实际消费到的正文字符位置（增量续排用）。
  /// 预览分页只消费前缀（maxChars 截断），续排从该位置继续。
  final int consumedChars;

  int get total => pages.length;
}

PaginatedChapter paginateChapter(
  String content, {
  required double width,
  required double height,
  int fontSize = 19,
  double lineHeight = 1.7,
  double paragraphSpacing = 8,
}) {
  final layout = TextChapterLayout(
    width: width,
    height: height,
    fontSize: fontSize.toDouble(),
    lineHeight: lineHeight,
    paragraphSpacing: paragraphSpacing,
  );
  final pages = layout.layout(content);
  return PaginatedChapter(
    content: content,
    pages: pages,
    totalChars: content.length,
  );
}

/// 页缓存 key：内容 + 四舍五入尺寸 + 字体设置。
class PageCacheKey {
  const PageCacheKey(this.content, this.width, this.height, this.fontSize, this.lineHeight);

  final String content;
  final double width;
  final double height;
  final int fontSize;
  final double lineHeight;

  @override
  bool operator ==(Object other) =>
      other is PageCacheKey &&
      other.content == content &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      (other.width - width).abs() < 2 &&
      (other.height - height).abs() < 2;

  @override
  int get hashCode => Object.hash(content, fontSize, lineHeight, width.round(), height.round());
}

class PageCache {
  final Map<PageCacheKey, PaginatedChapter> _map = {};

  PaginatedChapter get(
    String content, {
    required double width,
    required double height,
    int fontSize = 19,
    double lineHeight = 1.7,
    double paragraphSpacing = 8,
  }) {
    final key = PageCacheKey(content, width, height, fontSize, lineHeight);
    return _map.putIfAbsent(
      key,
      () => paginateChapter(
        content,
        width: width,
        height: height,
        fontSize: fontSize,
        lineHeight: lineHeight,
        paragraphSpacing: paragraphSpacing,
      ),
    );
  }

  void clear() => _map.clear();
}
