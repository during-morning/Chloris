import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris/features/reader/comic_reader.dart';
import 'package:chloris/features/reader/reader_controller.dart';
import 'package:chloris/features/reader/reader_screen.dart';

void main() {
  test('paginateChapter 生成可导航的多页', () {
    final content = List.generate(2000, (i) => '第$i 行内容，用于测试分页。').join('\n');
    final pg = paginateChapter(
      content,
      width: 360,
      height: 640,
      fontSize: 19,
      lineHeight: 1.7,
    );
    expect(pg.total, greaterThan(1));
    final first = pg.pages.first;
    final last = pg.pages.last;
    expect(first.startPos, 0);
    expect(last.endPos, greaterThan(first.endPos));
  });

  test('isMangaContent 识别图片正文', () {
    expect(isMangaContent('只有文字。'), isFalse);
    expect(isMangaContent('<img src="http://x/a.jpg"/>正文'), isTrue);
  });

  testWidgets('ReaderScreen 渲染章节标题', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScreen(content: '正文内容测试', chapterTitle: '第一章'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('第一章'), findsWidgets);
  });

  testWidgets('关闭阅读设置后阅读画布仍保持可见', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScreen(content: '持续可见的正文', chapterTitle: '第一章'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('阅读设置'));
    await tester.pumpAndSettle();
    expect(find.text('阅读设置'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('第一章'), findsWidgets);
    expect(find.textContaining('持续可见的正文'), findsOneWidget);
  });

  testWidgets('滚动时只刷新阅读进度且正文继续显示', (tester) async {
    final content = List.generate(180, (i) => '正文段落 $i，保持阅读内容稳定。').join('\n\n');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScreen(
            content: content,
            chapterTitle: '滚动章节',
            pageAnimOverride: PageAnim.scroll,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('滚动 · 0%'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.textContaining('滚动 · 0%'), findsNothing);
    expect(find.textContaining('滚动 · '), findsOneWidget);
    expect(find.textContaining('正文段落 0'), findsOneWidget);
  });
}
