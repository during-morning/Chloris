import 'package:chloris/app/theme/app_theme.dart';
import 'package:chloris/app/theme/app_tokens.dart';
import 'package:chloris/app/widgets/meow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Claude and terminal styles lay the page out as a measured column and
/// close the title block with a hairline rule. That layout puts the header in
/// an unbounded-height Column and the body in an Expanded, so it is easy to
/// hand one of them the wrong constraints. These tests pin both.
Future<void> pumpPage(WidgetTester tester, AppUiStyle style) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(AppThemeFamily.green, style: style),
      home: Scaffold(
        body: MeowPage(
          eyebrow: '书库',
          title: '全部书籍',
          subtitle: '本地与在线来源',
          child: ListView(
            children: const [
              ListTile(title: Text('第一本书')),
              ListTile(title: Text('第二本书')),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final style in AppUiStyle.values) {
    testWidgets('MeowPage lays out without exceptions in ${style.name}', (
      tester,
    ) async {
      await pumpPage(tester, style);
      expect(tester.takeException(), isNull);
      expect(find.text('第一本书'), findsOneWidget);
      expect(find.text('第二本书'), findsOneWidget);
    });
  }

  testWidgets('the title block renders per style', (tester) async {
    await pumpPage(tester, AppUiStyle.absolutely);
    expect(find.text('全部书籍'), findsOneWidget);
    expect(find.text('书库'), findsOneWidget);
    // Claude and terminal close the header with a hairline; classic does not.
    expect(find.byType(MeowRule), findsOneWidget);

    await pumpPage(tester, AppUiStyle.terminal);
    expect(find.text('[ 全部书籍 ]'), findsOneWidget);
    expect(find.text('> 书库'), findsOneWidget);
    expect(find.byType(MeowRule), findsOneWidget);

    await pumpPage(tester, AppUiStyle.classic);
    expect(find.text('全部书籍'), findsOneWidget);
    expect(find.byType(MeowRule), findsNothing);
  });

  testWidgets('terminal selected chip keeps contrast against its white fill', (
    tester,
  ) async {
    final theme = AppTheme.light(
      AppThemeFamily.green,
      style: AppUiStyle.terminal,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: MeowChip(label: '在读', active: true),
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('在读'));
    expect(label.style?.color, theme.colorScheme.onInverseSurface);
    expect(theme.chipTheme.selectedColor, theme.colorScheme.onSurface);
  });

  testWidgets('the measured column caps width in the new styles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await pumpPage(tester, AppUiStyle.absolutely);
    final absolutelyWidth = tester.getSize(find.byType(ListView)).width;
    expect(absolutelyWidth, lessThanOrEqualTo(AppTokens.absolutelyColumn));

    await pumpPage(tester, AppUiStyle.classic);
    // Classic keeps the full-bleed layout.
    final classicWidth = tester.getSize(find.byType(ListView)).width;
    expect(classicWidth, greaterThan(AppTokens.absolutelyColumn));
  });
}
