import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/features/reader/reading_settings_sheet.dart';

void main() {
  testWidgets('阅读设置 sheet 可打开', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showReadingSettingsSheet(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('阅读设置'), findsOneWidget);
    expect(find.text('阅读绿'), findsWidgets);
    expect(find.text('跟随应用'), findsOneWidget);
    expect(find.text('羊皮'), findsOneWidget);
    expect(find.text('夜间'), findsOneWidget);
  });
}
