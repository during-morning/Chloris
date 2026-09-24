import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('书库空态展示 Meow 文案与导入入口', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) async => <Book>[]),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('书库'), findsWidgets);
    expect(find.text('你的阅读空间'), findsOneWidget);
    expect(find.text('导入本地书'), findsOneWidget);
  });
}
