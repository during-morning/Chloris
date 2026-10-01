import 'package:chloris/app/widgets/startup_shell.dart' show StartupShell;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('启动骨架可独立渲染且不创建会重置深链接的 Navigator', (tester) async {
    await tester.pumpWidget(const StartupShell());
    expect(find.text('正在加载 Chloris…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Navigator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
