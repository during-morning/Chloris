import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/features/reader/read_pager.dart';

void main() {
  testWidgets('快滑也只会翻到相邻页', (tester) async {
    var index = 5;
    await tester.binding.setSurfaceSize(const Size(400, 700));
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setSt) {
            return Scaffold(
              body: ReadPager(
                pages: List<String>.generate(30, (i) => 'PAGE-' + i.toString()),
                index: index,
                onIndex: (i) => setSt(() => index = i),
                pageBuilder: (context, text, i) => Text(text),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final center = tester.getCenter(find.byType(ReadPager));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();
    expect((index - 5).abs(), lessThanOrEqualTo(1));
    expect(index, anyOf(5, 6));
  });

  testWidgets('点控 next 只 +1', (tester) async {
    var index = 2;
    final c = ReadPagerController();
    await tester.binding.setSurfaceSize(const Size(400, 700));
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setSt) {
            return Scaffold(
              body: ReadPager(
                controller: c,
                pages: const ['a', 'b', 'c', 'd', 'e'],
                index: index,
                onIndex: (i) => setSt(() => index = i),
                pageBuilder: (context, text, i) => Text(text),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    c.next();
    await tester.pumpAndSettle();
    expect(index, 3);
    c.next();
    await tester.pumpAndSettle();
    expect(index, 4);
  });

  testWidgets('点击左右三分之一会回调', (tester) async {
    var side = '';
    await tester.binding.setSurfaceSize(const Size(400, 700));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadPager(
            pages: const ['a', 'b', 'c'],
            index: 1,
            onIndex: (_) {},
            onTap: (local, size) {
              if (local.dx < size.width / 3) {
                side = 'left';
              } else if (local.dx > size.width * 2 / 3) {
                side = 'right';
              } else {
                side = 'mid';
              }
            },
            pageBuilder: (context, text, i) => Text(text),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(40, 350));
    await tester.pumpAndSettle();
    expect(side, 'left');
    await tester.tapAt(const Offset(360, 350));
    await tester.pumpAndSettle();
    expect(side, 'right');
  });

  testWidgets('跨章后同页数的正文重新落回可视区域', (tester) async {
    var chapter = 0;
    final controller = ReadPagerController();
    await tester.binding.setSurfaceSize(const Size(400, 700));
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setSt) {
            final text = chapter == 0 ? '第一章正文' : '第二章正文';
            return Scaffold(
              body: ReadPager(
                controller: controller,
                pages: [text],
                index: 0,
                contentKey: chapter,
                onIndex: (_) {},
                onNextChapter: () => setSt(() => chapter = 1),
                pageBuilder: (context, value, _) => Text(value),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.next();
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.text('第二章正文'));
    expect(rect.left, closeTo(0, 1));
    expect(rect.right, greaterThan(0));
  });
}
