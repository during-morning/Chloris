class TextPage {
  TextPage({
    required this.index,
    required this.lines,
    required this.startPos,
    required this.endPos,
  });

  final int index;
  final List<String> lines;
  final int startPos;
  final int endPos;

  String get text => lines.join('\n');
}

class TextChapterLayout {
  TextChapterLayout({
    required this.width,
    required this.height,
    this.fontSize = 18,
    this.lineHeight = 1.6,
    this.paragraphSpacing = 8,
  });

  final double width;
  final double height;
  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;

  int get charsPerLine {
    final w = width <= 0 ? 360 : width;
    final charW = fontSize * 1.05;
    return (w / charW).floor().clamp(8, 100);
  }

  int get linesPerPage {
    final h = height <= 0 ? 640 : height;
    final lh = fontSize * lineHeight + 2;
    return (h / lh).floor().clamp(6, 80);
  }

  List<TextPage> layout(String content) {
    final wrapped = <String>[];
    final paras = content.split('\n');
    for (final para in paras) {
      if (para.trim().isEmpty) {
        wrapped.add('');
        continue;
      }
      var rest = para;
      while (rest.isNotEmpty) {
        if (rest.length <= charsPerLine) {
          wrapped.add(rest);
          break;
        }
        wrapped.add(rest.substring(0, charsPerLine));
        rest = rest.substring(charsPerLine);
      }
    }
    final pages = <TextPage>[];
    var pos = 0;
    for (var i = 0; i < wrapped.length; i += linesPerPage) {
      final slice = wrapped.sublist(
        i,
        (i + linesPerPage).clamp(0, wrapped.length),
      );
      final start = pos;
      final joined = slice.join('\n');
      pos += joined.length + 1;
      pages.add(
        TextPage(
          index: pages.length,
          lines: slice,
          startPos: start,
          endPos: pos,
        ),
      );
    }
    if (pages.isEmpty) {
      pages.add(TextPage(index: 0, lines: const [''], startPos: 0, endPos: 0));
    }
    return pages;
  }

  int pageIndexForPos(List<TextPage> pages, int pos) {
    for (var i = 0; i < pages.length; i++) {
      if (pos < pages[i].endPos) return i;
    }
    return pages.length - 1;
  }
}
