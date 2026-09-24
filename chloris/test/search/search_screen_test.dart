import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chloris/features/search/search_screen.dart';

void main() {
  testWidgets('寻找页空态', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('寻找书籍'), findsOneWidget);
    expect(find.text('从多个书源并发搜索'), findsOneWidget);
  });
}
