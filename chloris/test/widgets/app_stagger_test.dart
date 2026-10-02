import 'package:chloris/app/theme/app_theme.dart';
import 'package:chloris/app/theme/app_tokens.dart';
import 'package:chloris/app/widgets/app_motion.dart';
import 'package:chloris/app/widgets/follow_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _list(AppUiStyle style, {bool reduce = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduce),
  child: MaterialApp(
    theme: AppTheme.light(AppThemeFamily.green, style: style),
    home: Scaffold(
      body: ListView(
        children: [
          for (var i = 0; i < 12; i++)
            AppStagger(index: i, child: Text('row $i')),
        ],
      ),
    ),
  ),
);

void main() {
  test('stagger delay grows per item up to the cap', () {
    expect(AppStagger.delayFor(0), Duration.zero);
    expect(AppStagger.delayFor(2), AppTokens.durationStagger * 2);
    expect(
      AppStagger.delayFor(99),
      AppTokens.durationStagger * AppTokens.staggerMaxItems,
    );
  });

  testWidgets('Absolutely staggers the first items only', (tester) async {
    await tester.pumpWidget(_list(AppUiStyle.absolutely));
    expect(
      find.ancestor(of: find.text('row 0'), matching: find.byType(AppEntrance)),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('row ${AppTokens.staggerMaxItems}'),
        matching: find.byType(AppEntrance),
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
  });

  for (final style in [AppUiStyle.classic, AppUiStyle.terminal]) {
    testWidgets('${style.name} lists do not stagger', (tester) async {
      await tester.pumpWidget(_list(style));
      expect(find.byType(AppEntrance), findsNothing);
    });
  }

  testWidgets('reduced motion disables the stagger', (tester) async {
    await tester.pumpWidget(_list(AppUiStyle.absolutely, reduce: true));
    expect(find.byType(AppEntrance), findsNothing);
  });

  group('page transitions', () {
    test('Absolutely turns pages with its own builder', () {
      final theme = AppTheme.light(
        AppThemeFamily.green,
        style: AppUiStyle.absolutely,
      );
      for (final builder in theme.pageTransitionsTheme.builders.values) {
        expect(builder, isA<AbsolutelyPageTransitionsBuilder>());
      }
    });

    test('classic and terminal keep their transitions', () {
      for (final style in [AppUiStyle.classic, AppUiStyle.terminal]) {
        final theme = AppTheme.light(AppThemeFamily.green, style: style);
        for (final builder in theme.pageTransitionsTheme.builders.values) {
          expect(builder, isNot(isA<AbsolutelyPageTransitionsBuilder>()));
        }
      }
    });

    testWidgets('FollowPageRoute animates under Absolutely', (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          theme: AppTheme.light(
            AppThemeFamily.green,
            style: AppUiStyle.absolutely,
          ),
          home: const Text('home'),
        ),
      );
      key.currentState!.push(
        FollowPageRoute<void>(builder: (_) => const Text('next')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('next'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(find.text('next'), findsOneWidget);
    });
  });
}
