import 'dart:io';

import 'package:chloris/app/illustration/sketch.dart';
import 'package:chloris/app/illustration/svg_art.dart';
import 'package:chloris/app/theme/app_theme.dart';
import 'package:chloris/app/widgets/meow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SvgArtPainter _painterOf(WidgetTester tester, Finder of) =>
    tester
            .widget<CustomPaint>(
              find.descendant(of: of, matching: find.byType(CustomPaint)),
            )
            .painter!
        as SvgArtPainter;

void main() {
  group('path data', () {
    test('absolute and relative commands land on the same points', () {
      final a = parseSvgPathData('M10 10 L30 10 L30 30 Z');
      final b = parseSvgPathData('m10 10 l20 0 l0 20 z');
      expect(a.getBounds(), b.getBounds());
    });

    test('H, V, smooth curves and arcs are understood', () {
      final p = parseSvgPathData(
        'M0 0 H20 V20 C20 30 10 30 10 20 S0 10 0 20 Q5 30 10 30 T20 30 '
        'A5 5 0 0 1 30 30',
      );
      final b = p.getBounds();
      expect(b.left, 0);
      expect(b.top, 0);
      expect(b.right, closeTo(30, .01));
    });
  });

  test('every artwork file parses with its declared box', () {
    for (final art in SketchArt.values) {
      final svg = SvgArt.parse(File(art.asset).readAsStringSync());
      expect(svg.shapes, isNotEmpty, reason: art.name);
      expect(svg.viewBox.size, art.box, reason: art.name);
    }
    expect(SketchArt.nav, hasLength(4));
  });

  test('transforms and inherited styles apply', () {
    final svg = SvgArt.parse('''
<svg viewBox="0 0 100 100" stroke="#191919" stroke-width="2">
  <g transform="translate(10 0)" opacity="0.5">
    <rect x="0" y="0" width="10" height="10" fill="#D97757"/>
  </g>
</svg>''');
    final shape = svg.shapes.single;
    expect(shape.path.getBounds().left, 10);
    expect(shape.fill, const Color(0xFFD97757));
    expect(shape.fillOpacity, .5);
    expect(shape.stroke, const Color(0xFF191919));
    expect(shape.strokeWidth, 2);
  });

  test('palette maps authored colours onto the theme', () {
    final light = AppTheme.light(
      AppThemeFamily.green,
      style: AppUiStyle.absolutely,
    ).colorScheme;
    final dark = AppTheme.dark(
      AppThemeFamily.green,
      style: AppUiStyle.absolutely,
    ).colorScheme;
    const ink = Color(ArtPalette.ink);
    const clay = Color(ArtPalette.clay);
    expect(ArtPalette.of(light).resolve(ink), light.onSurface);
    expect(ArtPalette.of(dark).resolve(ink), dark.onSurface);
    expect(ArtPalette.of(dark).resolve(clay), dark.primary);
    const other = Color(0xFF123456);
    expect(ArtPalette.of(light).resolve(other), other);
    const cream = Color(0xFFFCF6F1);
    expect(const ArtPalette.mono(cream).resolve(clay), cream);
  });

  testWidgets('illustration draws itself in, then holds', (tester) async {
    await tester.runAsync(SketchArt.preloadAll);
    await tester.pumpWidget(
      const MaterialApp(
        home: SketchIllustration(SketchArt.library, width: 160),
      ),
    );
    final painter = _painterOf(tester, find.byType(SketchIllustration));
    expect(painter.progress.value, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(painter.progress.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(painter.progress.value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('idle illustrations float once drawn, not with reduced motion', (
    tester,
  ) async {
    await tester.runAsync(SketchArt.preloadAll);
    await tester.pumpWidget(
      const MaterialApp(
        home: SketchIllustration(SketchArt.library, width: 160, idle: true),
      ),
    );
    Finder floating() => find.descendant(
      of: find.byType(SketchIllustration),
      matching: find.byType(AnimatedBuilder),
    );
    expect(floating(), findsNothing);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(floating(), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: SketchIllustration(SketchArt.library, width: 160, idle: true),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('illustration is complete at once with reduced motion', (
    tester,
  ) async {
    await tester.runAsync(SketchArt.preloadAll);
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: SketchIllustration(SketchArt.library, width: 160),
        ),
      ),
    );
    expect(
      _painterOf(tester, find.byType(SketchIllustration)).progress.value,
      1,
    );
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('loader loops, and stands still with reduced motion', (
    tester,
  ) async {
    await tester.runAsync(SketchArt.preloadAll);
    await tester.pumpWidget(const MaterialApp(home: SketchLoader()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: SketchLoader()),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('style gating', () {
    Future<void> pumpEmpty(WidgetTester tester, AppUiStyle style) async {
      await tester.runAsync(SketchArt.preloadAll);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeFamily.green, style: style),
          home: const Scaffold(
            body: MeowEmpty(
              title: '暂无命中',
              body: '换个关键词。',
              illustration: SketchArt.search,
            ),
          ),
        ),
      );
      // Absolutely empty states keep floating, so never settle: pump past
      // the draw-on and the text cascade instead.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('Absolutely empty states carry an illustration', (
      tester,
    ) async {
      await pumpEmpty(tester, AppUiStyle.absolutely);
      expect(find.byType(SketchIllustration), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final style in [AppUiStyle.classic, AppUiStyle.terminal]) {
      testWidgets('${style.name} empty states stay unillustrated', (
        tester,
      ) async {
        await pumpEmpty(tester, style);
        expect(find.byType(SketchIllustration), findsNothing);
      });
    }

    testWidgets('only Absolutely uses the hand-drawn loader', (tester) async {
      for (final style in AppUiStyle.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(AppThemeFamily.green, style: style),
            home: const Scaffold(body: MeowLoading(label: '加载中')),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final absolutely = style == AppUiStyle.absolutely;
        expect(
          find.byType(SketchLoader),
          absolutely ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(CircularProgressIndicator),
          absolutely ? findsNothing : findsOneWidget,
        );
      }
    });
  });
}
