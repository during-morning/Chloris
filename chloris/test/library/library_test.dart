import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:chloris_engine/chloris_engine.dart';

import 'package:chloris/features/library/library_provider.dart';
import 'package:chloris/features/library/library_screen.dart';

void main() {
  testWidgets('书架可切换网格/列表视图', (tester) async {
    final sample = Book(bookUrl: 's1', name: '示例书', author: '作者');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) async => [sample]),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    // 默认网格视图：有 grid->list 切换按钮
    expect(find.byIcon(Icons.view_list_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);
  });

  testWidgets('超宽书架内容左对齐铺满且工具栏操作靠右', (tester) async {
    tester.view.physicalSize = const Size(3000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith(
            (ref) async => [
              Book(bookUrl: 'wide-book', name: '超宽视口样本', author: '作者'),
            ],
          ),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField).first;
    expect(tester.getSize(searchField).width, greaterThan(2800));
    expect(tester.getTopLeft(searchField).dx, closeTo(16, 1));
    expect(find.text('超宽视口样本'), findsOneWidget);
    final bookGrid = find.byType(GridView);
    expect(tester.getSize(bookGrid).width, greaterThan(2800));
    expect(tester.getTopLeft(bookGrid).dx, closeTo(16, 1));
    final trailingAction = tester.getRect(find.byTooltip('选择'));
    expect(trailingAction.right, greaterThan(2940));
    expect(trailingAction.right, lessThanOrEqualTo(3000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('书库空态展示 Meow 文案与导入入口', (tester) async {
    tester.view.physicalSize = const Size(1636, 781);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [booksProvider.overrideWith((ref) async => <Book>[])],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('书库'), findsWidgets);
    expect(find.text('你的阅读空间'), findsOneWidget);
    expect(find.text('导入本地书'), findsOneWidget);
    expect(find.text('寻找在线书籍'), findsOneWidget);
    expect(find.text('探索书源分类'), findsOneWidget);

    final viewportHeight = tester.view.physicalSize.height;
    expect(
      tester.getTopLeft(find.text('你的阅读空间')).dy,
      lessThan(viewportHeight * 0.55),
    );
    expect(
      tester.getBottomRight(find.text('探索书源分类')).dy,
      lessThan(viewportHeight * 0.75),
    );
    final importCenter = tester.getCenter(find.text('导入本地书')).dy;
    final searchCenter = tester.getCenter(find.text('寻找在线书籍')).dy;
    expect((importCenter - searchCenter).abs(), lessThan(24));
  });

  testWidgets('矮窗口书库空态仍能显示提示和导入入口', (tester) async {
    tester.view.physicalSize = const Size(1054, 255);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [booksProvider.overrideWith((ref) async => <Book>[])],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('你的阅读空间'), findsOneWidget);
    for (final label in ['导入本地书', '寻找在线书籍', '探索书源分类']) {
      final target = find.text(label);
      expect(target, findsOneWidget);
      expect(tester.getTopLeft(target).dy, greaterThanOrEqualTo(0));
      expect(tester.getBottomRight(target).dy, lessThanOrEqualTo(255));
    }

    // Desktop windows can be resized while this page is open. The empty state
    // must stay in a scrollable viewport at intermediate and narrow sizes too.
    for (final size in [
      const Size(640, 220),
      const Size(400, 180),
      const Size(320, 140),
      const Size(240, 100),
      const Size(180, 80),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'size: $size');
      expect(find.text('你的阅读空间'), findsOneWidget, reason: 'size: $size');
      final exploreLink = find.text('探索书源分类');
      await tester.ensureVisible(exploreLink);
      await tester.pumpAndSettle();
      final exploreRect = tester.getRect(exploreLink);
      expect(exploreRect.top, greaterThanOrEqualTo(0), reason: 'size: $size');
      expect(
        exploreRect.bottom,
        lessThanOrEqualTo(size.height),
        reason: 'size: $size',
      );
    }
  });

  testWidgets('书库空态可以打开在线找书页', (tester) async {
    final router = GoRouter(
      initialLocation: '/library',
      routes: [
        GoRoute(path: '/library', builder: (_, _) => const LibraryScreen()),
        GoRoute(path: '/search', builder: (_, _) => const Text('在线找书页')),
        GoRoute(path: '/explore', builder: (_, _) => const Text('书源分类页')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [booksProvider.overrideWith((ref) async => <Book>[])],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('寻找在线书籍'));
    await tester.pumpAndSettle();
    expect(find.text('在线找书页'), findsOneWidget);
    router.go('/library');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('书店 · 浏览在线书源'));
    await tester.pumpAndSettle();
    expect(find.text('书源分类页'), findsOneWidget);
  });
}
