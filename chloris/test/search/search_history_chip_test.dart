import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chloris/app/theme/app_theme.dart';
import 'package:chloris/features/search/search_provider.dart';
import 'package:chloris/features/search/search_screen.dart';

class _SeedSearchHistory extends SearchHistoryNotifier {
  @override
  List<String> build() => const ['我的模拟'];
}

void main() {
  testWidgets('Absolutely 浅色搜索历史标签使用可读的深色文字', (tester) async {
    final theme = AppTheme.light(
      AppThemeFamily.byId('green'),
      style: AppUiStyle.absolutely,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [searchHistoryProvider.overrideWith(_SeedSearchHistory.new)],
        child: MaterialApp(theme: theme, home: const SearchScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(
      find.descendant(
        of: find.widgetWithText(ActionChip, '我的模拟'),
        matching: find.text('我的模拟'),
      ),
    );
    expect(label.style?.color, theme.colorScheme.onSurface);
    expect(label.style?.color, isNot(Colors.white));
  });
}
