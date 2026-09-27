import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/features/settings/welcome_screen.dart';

void main() {
  testWidgets('欢迎页保留免责声明确认，不显示年龄确认行', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    expect(find.text('欢迎使用 Chloris'), findsOneWidget);
    expect(find.text('开始使用'), findsOneWidget);
    expect(find.textContaining('已满 18 周岁'), findsNothing);
    expect(find.textContaining('已阅读免责声明'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
