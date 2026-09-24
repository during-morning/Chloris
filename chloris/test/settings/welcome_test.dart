import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/features/settings/welcome_screen.dart';

void main() {
  testWidgets('欢迎页渲染标题与按钮', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    expect(find.text('欢迎使用 Chloris'), findsOneWidget);
    expect(find.text('开始使用'), findsOneWidget);
  });
}
