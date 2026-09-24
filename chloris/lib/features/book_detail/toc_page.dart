import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';

import 'chapter_toc_panel.dart';

class TocPage extends StatelessWidget {
  const TocPage({
    super.key,
    required this.book,
    required this.chapters,
    required this.onOpenChapter,
  });

  final Book book;
  final List<BookChapter> chapters;
  final ValueChanged<int> onOpenChapter;

  @override
  Widget build(BuildContext context) {
    return ChapterTocPanel(
      chapters: chapters,
      currentIndex: book.durChapterIndex,
      bookName: book.name,
      bookAuthor: book.author,
      onClose: () => Navigator.maybePop(context),
      onOpenChapter: (i) {
        onOpenChapter(i);
        Navigator.maybePop(context);
      },
    );
  }
}
