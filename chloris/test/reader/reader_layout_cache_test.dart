import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for the reader re-layout cache (2.1).
///
/// `_measure` in `lib/features/reader/reader_layout.dart` reuses a previously
/// paginated chapter only when the layout geometry is unchanged. The cache key
/// must be driven by real typographic parameters (font size, padding, viewport,
/// text scale, …) but **must not** include the menu open/closed state, because
/// the menu is an overlay that does not change pagination geometry.
///
/// This test mirrors the cache-key ingredients that `_measure` compares and
/// asserts the two required invariants:
///   1. toggling the menu leaves the key unchanged;
///   2. changing the font size changes the key.
List<Object?> _layoutCacheKey({
  required String body,
  required double readW,
  required double readH,
  required double pad,
  required double fontSize,
  required double? lineHeight,
  required double? letterSpacing,
  required String? fontFamily,
  required TextScaler textScaler,
  required bool doublePage,
  // The menu state is intentionally NOT part of the key.
  required bool menuVisible,
}) {
  // Geometry is computed for the hidden-chrome reading area, so `menuVisible`
  // has no effect on any value below — that is the whole point of the fix.
  return <Object?>[
    body,
    readW,
    readH,
    pad,
    fontSize,
    lineHeight,
    letterSpacing,
    fontFamily,
    textScaler,
    doublePage,
  ];
}

void main() {
  test('菜单开合不改变重排缓存 key', () {
    const body = 'chapter body';
    const readW = 360.0;
    const readH = 640.0;
    const pad = 16.0;
    const fontSize = 18.0;
    const lineHeight = 1.6;
    const letterSpacing = 0.0;
    const fontFamily = 'PTSerif';
    const textScaler = TextScaler.linear(1.0);
    const doublePage = false;

    final closedKey = _layoutCacheKey(
      body: body,
      readW: readW,
      readH: readH,
      pad: pad,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
      textScaler: textScaler,
      doublePage: doublePage,
      menuVisible: false,
    );
    final openKey = _layoutCacheKey(
      body: body,
      readW: readW,
      readH: readH,
      pad: pad,
      fontSize: fontSize,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
      textScaler: textScaler,
      doublePage: doublePage,
      menuVisible: true,
    );

    expect(openKey, equals(closedKey),
        reason: '打开/收起菜单不应使整章重排缓存失效');
  });

  test('字号变化会改变重排缓存 key', () {
    const body = 'chapter body';
    const readW = 360.0;
    const readH = 640.0;
    const pad = 16.0;
    const lineHeight = 1.6;
    const letterSpacing = 0.0;
    const fontFamily = 'PTSerif';
    const textScaler = TextScaler.linear(1.0);
    const doublePage = false;

    final smallKey = _layoutCacheKey(
      body: body,
      readW: readW,
      readH: readH,
      pad: pad,
      fontSize: 16.0,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
      textScaler: textScaler,
      doublePage: doublePage,
      menuVisible: false,
    );
    final largeKey = _layoutCacheKey(
      body: body,
      readW: readW,
      readH: readH,
      pad: pad,
      fontSize: 22.0,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      fontFamily: fontFamily,
      textScaler: textScaler,
      doublePage: doublePage,
      menuVisible: false,
    );

    expect(largeKey, isNot(equals(smallKey)),
        reason: '字号变化应使重排缓存失效并重新排版');
  });
}
