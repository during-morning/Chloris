import 'package:flutter/services.dart';

enum ReaderKeyAction {
  prevPage,
  nextPage,
  prevChapter,
  nextChapter,
  toggleMenu,
}

/// Page mode: ↑↓ / WS page. Scroll mode: ↑↓ / WS scroll (same action).
/// ←→ / AD always change chapter.
ReaderKeyAction? readerKeyAction(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
    return ReaderKeyAction.prevChapter;
  }
  if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
    return ReaderKeyAction.nextChapter;
  }
  if (key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.keyW ||
      key == LogicalKeyboardKey.pageUp) {
    return ReaderKeyAction.prevPage;
  }
  if (key == LogicalKeyboardKey.arrowDown ||
      key == LogicalKeyboardKey.keyS ||
      key == LogicalKeyboardKey.pageDown ||
      key == LogicalKeyboardKey.space) {
    return ReaderKeyAction.nextPage;
  }
  if (key == LogicalKeyboardKey.escape) {
    return ReaderKeyAction.toggleMenu;
  }
  return null;
}

enum DoublePageMode { auto, on, off }

DoublePageMode doublePageModeById(String? value) => switch (value) {
  'on' => DoublePageMode.on,
  'off' => DoublePageMode.off,
  _ => DoublePageMode.auto,
};

extension DoublePageModeX on DoublePageMode {
  String get id => name;
  String get label => switch (this) {
    DoublePageMode.auto => '自动（宽屏双页）',
    DoublePageMode.on => '始终双页',
    DoublePageMode.off => '单页',
  };

  bool activeFor(double width, {required bool scroll}) {
    if (scroll) return false;
    return switch (this) {
      DoublePageMode.on => width >= 560,
      DoublePageMode.off => false,
      DoublePageMode.auto => width >= 900,
    };
  }
}

const readerDoublePageGutter = 16.0;
const readerDoublePageRule = 1.0;
const readerDoublePageInnerPad = 24.0;
const readerMenuTopBar = 60.0;
const readerMenuBottomBar = 72.0;

/// Top/bottom inset shared by pagination and the on-screen column.
/// The reading area follows the animated chrome visibility state.
double readerVerticalInset({
  required bool menuVisible,
  required double pagePadding,
  required double safePadding,
  required bool top,
}) {
  final pad = pagePadding.clamp(12.0, 48.0);
  // Keep a small inset above the chapter heading, but let the final lines
  // reach the viewport edge when the chrome is hidden. On devices with a
  // bottom safe area, retain only that hardware inset.
  if (!menuVisible) return top ? pad + 8.0 : safePadding;
  final bar = top ? readerMenuTopBar : readerMenuBottomBar;
  return (bar + safePadding).clamp(52.0, 160.0);
}

/// Text width shared by the paginator and each on-screen column.
double readerColumnWidth({
  required double viewportWidth,
  required double pagePadding,
  required bool doublePage,
  double maxSingle = 760,
}) {
  if (!doublePage) {
    return (viewportWidth - pagePadding * 2).clamp(120.0, maxSingle);
  }
  // [outer][text][inner][rule][inner][text][outer]
  return ((viewportWidth - readerDoublePageRule) / 2 -
          pagePadding -
          readerDoublePageInnerPad)
      .clamp(120.0, 4000.0);
}
