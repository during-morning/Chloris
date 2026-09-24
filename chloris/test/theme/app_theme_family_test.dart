import 'package:chloris/app/theme/app_theme.dart';
import 'package:chloris/features/reader/reader_palette.dart';
import 'package:chloris/features/reader/reader_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text theme does not install CJK fallback that steals icon glyphs', () {
    final t = AppTheme.dark(AppThemeFamily.green);
    expect(t.textTheme.bodyMedium?.fontFamilyFallback, isNull);
    expect(t.textTheme.titleMedium?.fontFamilyFallback, isNull);
    expect(t.iconTheme.color, isNotNull);
  });

  test('eink theme is black on white with no splash', () {
    final t = AppTheme.light(AppThemeFamily.green, eink: true);
    expect(t.colorScheme.surface, const Color(0xFFFFFFFF));
    expect(t.colorScheme.onSurface, const Color(0xFF000000));
    expect(t.splashFactory, NoSplash.splashFactory);
  });

  test('search bar uses restrained web-safe surface treatment', () {
    final light = AppTheme.light(AppThemeFamily.green);
    expect(light.searchBarTheme.elevation?.resolve(const {}), 0);
    expect(
      light.searchBarTheme.backgroundColor?.resolve(const {}),
      light.colorScheme.surfaceContainerLow,
    );
    expect(
      light.searchBarTheme.shadowColor?.resolve(const {}),
      Colors.transparent,
    );
    final eink = AppTheme.light(AppThemeFamily.green, eink: true);
    expect(eink.searchBarTheme.elevation?.resolve(const {}), 0);
    expect(eink.searchBarTheme.shadowColor?.resolve(const {})?.a, 0);
  });

  test('md families produce distinct seeds', () {
    expect(AppThemeFamily.byId('blue').seed, AppThemeFamily.blue.seed);
    expect(AppThemeFamily.byId('md-green').id, 'green');
    expect(AppThemeFamily.all.length, greaterThanOrEqualTo(8));
  });

  test('reader follow paper matches the named family', () {
    const settings = ReaderSettings();
    expect(settings.paletteId, 'follow');
    expect(settings.palette.followApp, isTrue);
    expect(ReaderPalette.byId('paper').followApp, isTrue);
    expect(ReaderPalette.byId('md-green').followApp, isTrue);
    expect(ReaderPalette.byId('sepia').followApp, isFalse);
    expect(ReaderPalette.byId('night').id, 'night');
    const family = AppThemeFamily.purple;
    const scheme = ColorScheme.light();
    expect(ReaderPalette.follow.label, isNot('阅读绿'));
    expect(ReaderPalette.follow.labelFor(family), family.label);
    expect(ReaderPalette.follow.labelFor(AppThemeFamily.green), '阅读绿');
    expect(ReaderPalette.sepia.labelFor(family), ReaderPalette.sepia.label);
    expect(
      ReaderPalette.follow.bgColor(scheme, family: family),
      scheme.surface,
    );
    expect(
      ReaderPalette.follow.fgColor(scheme, family: family),
      scheme.onSurface,
    );
    const night = ColorScheme.dark();
    expect(ReaderPalette.follow.bgColor(night, family: family), night.surface);
    expect(
      ReaderPalette.follow.fgColor(night, family: family),
      night.onSurface,
    );
    final migrated = ReaderSettings.fromJson({'paletteId': 'paper'});
    expect(migrated.palette.followApp, isTrue);
  });

  test('family papers stay light washes, not dye floods', () {
    for (final f in AppThemeFamily.all) {
      final c = Color(f.paperBg);
      expect(c.computeLuminance(), greaterThan(0.80), reason: f.label);
      expect(c.computeLuminance(), lessThan(0.97), reason: f.label);
    }
    expect(
      Color(AppThemeFamily.lime.paperBg).toARGB32(),
      isNot(Color(AppThemeFamily.blue.paperBg).toARGB32()),
    );
  });

  test('high contrast actually changes the color scheme', () {
    final normal = AppTheme.light(AppThemeFamily.green);
    final hc = AppTheme.light(AppThemeFamily.green, highContrast: true);
    expect(hc.colorScheme.surface, isNot(normal.colorScheme.surface));
    expect(
      hc.colorScheme.onSurface.computeLuminance(),
      lessThan(normal.colorScheme.onSurface.computeLuminance() + 0.01),
    );
    expect(
      hc.colorScheme.outline.computeLuminance(),
      lessThan(normal.colorScheme.outline.computeLuminance()),
    );
  });
}
