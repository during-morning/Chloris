import 'package:chloris/app/theme/app_icons.dart';
import 'package:chloris/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('style ids are stable and unknown values keep classic', () {
    expect(AppUiStyle.byId('claude'), AppUiStyle.absolutely);
    expect(AppUiStyle.byId('terminal'), AppUiStyle.terminal);
    expect(AppUiStyle.byId('old-value'), AppUiStyle.classic);
    expect(AppUiStyle.absolutely.fixedThemeMode, isNull);
    expect(AppUiStyle.terminal.fixedThemeMode, ThemeMode.dark);
  });

  test('Claude theme is warm paper with editorial typography', () {
    final claude = AppTheme.light(
      AppThemeFamily.green,
      style: AppUiStyle.absolutely,
    );
    final t = claude.extension<AppStyleExtension>()!;
    expect(claude.colorScheme.surface, const Color(0xFFF0EEE6));
    expect(claude.colorScheme.primary, const Color(0xFFD97757));
    expect(claude.textTheme.headlineMedium?.fontFamily, AppTheme.absolutelySerif);
    expect(claude.textTheme.bodyMedium?.fontFamily, AppTheme.absolutelySans);
    expect(t.style, AppUiStyle.absolutely);
    expect(t.pageRadius, 16);
    expect(t.controlRadius, 8);
    expect(t.isCapsuleChip, isTrue);
    expect(t.mono, isFalse);
    expect(t.headerRule, isTrue);
    expect(t.readerFamily, AppTheme.absolutelySerif);
  });

  test('terminal theme is monochrome, monospace and fully square', () {
    final terminal = AppTheme.light(
      AppThemeFamily.green,
      style: AppUiStyle.terminal,
    );
    final t = terminal.extension<AppStyleExtension>()!;
    expect(terminal.brightness, Brightness.dark);
    expect(terminal.colorScheme.surface, const Color(0xFF0A0A0A));
    // The old GitHub-green accent is gone: primary is plain white.
    expect(terminal.colorScheme.primary, const Color(0xFFF2F2F2));
    expect(terminal.colorScheme.onPrimary, const Color(0xFF000000));
    expect(terminal.textTheme.bodyMedium?.fontFamily, AppTheme.terminalMono);
    expect(terminal.visualDensity, VisualDensity.compact);
    expect(terminal.splashFactory, NoSplash.splashFactory);
    expect(t.style, AppUiStyle.terminal);
    expect(t.pageRadius, 0);
    expect(t.controlRadius, 0);
    expect(t.chipRadius, 0);
    expect(t.compact, isTrue);
    expect(t.mono, isTrue);
    expect(t.readerFamily, AppTheme.terminalMono);
    expect(t.contentMaxWidth, greaterThan(t.pagePadding));
    expect(t.pagePadding, lessThan(32));
  });

  test('icons stay monochrome at two levels in both new styles', () {
    for (final style in [AppUiStyle.absolutely, AppUiStyle.terminal]) {
      final theme = AppTheme.light(AppThemeFamily.green, style: style);
      final cs = theme.colorScheme;
      // No icon ever takes the accent hue.
      expect(theme.iconTheme.color, cs.onSurface);
      expect(
        theme.navigationRailTheme.selectedIconTheme?.color,
        cs.onSurface,
        reason: '$style rail selection must not use the accent',
      );
      expect(
        theme.navigationRailTheme.unselectedIconTheme?.color,
        cs.onSurfaceVariant,
      );
    }
  });

  test(
    'Claude selected chips use the ink surface in light and dark themes',
    () {
      for (final theme in [
        AppTheme.light(AppThemeFamily.green, style: AppUiStyle.absolutely),
        AppTheme.dark(AppThemeFamily.green, style: AppUiStyle.absolutely),
      ]) {
        expect(
          theme.chipTheme.selectedColor,
          theme.colorScheme.surfaceContainerHigh,
        );
        expect(theme.chipTheme.selectedColor, isNot(theme.colorScheme.tertiaryContainer));
      }
    },
  );

  test('classic style is unchanged by the redesign', () {
    final classic = AppTheme.light(AppThemeFamily.green);
    final t = classic.extension<AppStyleExtension>()!;
    expect(t.style, AppUiStyle.classic);
    expect(t.headerRule, isFalse);
    expect(t.readerFamily, isNull);
    expect(t.pagePadding, 16);
  });

  test('semantic icon registry uses Cupertino glyphs', () {
    expect(AppIcons.all, isNotEmpty);
    expect(AppIcons.library.fontFamily, contains('CupertinoIcons'));
    expect(AppIcons.search.fontFamily, contains('CupertinoIcons'));
  });

  test('every nav destination has a two-level monochrome pair', () {
    expect(AppIcons.navPairs, hasLength(5));
    for (final pair in AppIcons.navPairs) {
      expect(pair.resolve(active: false), pair.outline);
      expect(pair.resolve(active: true), pair.filled);
      expect(pair.outline.fontFamily, contains('CupertinoIcons'));
    }
    expect(AppIcons.libraryPair.resolve(active: true), AppIcons.libraryFilled);
    expect(AppIcons.explorePair.resolve(active: true), AppIcons.exploreFilled);
    expect(AppIcons.explorePair.resolve(active: false), AppIcons.explore);
  });
}
