import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/features/settings/about_screen.dart';

void main() {
  testWidgets('关于页的底部视口由主题纸色完整填充', (tester) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    );
    await tester.pumpWidget(
      MaterialApp(theme: theme, home: const AboutScreen()),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, theme.colorScheme.surface);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Material && widget.color == theme.colorScheme.surface,
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
}
