import 'package:chloris/features/reader/reader_keys.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('arrows and WASD map to page vs chapter', () {
    expect(readerKeyAction(LogicalKeyboardKey.arrowUp), ReaderKeyAction.prevPage);
    expect(readerKeyAction(LogicalKeyboardKey.keyW), ReaderKeyAction.prevPage);
    expect(readerKeyAction(LogicalKeyboardKey.arrowDown), ReaderKeyAction.nextPage);
    expect(readerKeyAction(LogicalKeyboardKey.keyS), ReaderKeyAction.nextPage);
    expect(readerKeyAction(LogicalKeyboardKey.arrowLeft), ReaderKeyAction.prevChapter);
    expect(readerKeyAction(LogicalKeyboardKey.keyA), ReaderKeyAction.prevChapter);
    expect(readerKeyAction(LogicalKeyboardKey.arrowRight), ReaderKeyAction.nextChapter);
    expect(readerKeyAction(LogicalKeyboardKey.keyD), ReaderKeyAction.nextChapter);
    expect(readerKeyAction(LogicalKeyboardKey.escape), ReaderKeyAction.toggleMenu);
  });

  test('auto dual-page only on a wide canvas', () {
    expect(DoublePageMode.auto.activeFor(500, scroll: false), isFalse);
    expect(DoublePageMode.auto.activeFor(960, scroll: false), isTrue);
    expect(DoublePageMode.on.activeFor(640, scroll: false), isTrue);
    expect(DoublePageMode.on.activeFor(960, scroll: true), isFalse);
    expect(DoublePageMode.off.activeFor(1200, scroll: false), isFalse);
  });

  test('double-page column width uses the full half-page minus pads', () {
    // [24][text][24][1][24][text][24] on a 1000-wide canvas
    // text = (1000 - 1) / 2 - 24 - 24 = 451.5
    expect(
      readerColumnWidth(
        viewportWidth: 1000,
        pagePadding: 24,
        doublePage: true,
      ),
      451.5,
    );
    expect(
      readerColumnWidth(
        viewportWidth: 760,
        pagePadding: 24,
        doublePage: false,
      ),
      712,
    );
  });

  test('hidden chrome uses page pad so text can refill the column', () {
    expect(
      readerVerticalInset(
        menuVisible: false,
        pagePadding: 24,
        safePadding: 0,
        top: true,
      ),
      28,
    );
    expect(
      readerVerticalInset(
        menuVisible: true,
        pagePadding: 24,
        safePadding: 0,
        top: true,
      ),
      readerMenuTopBar,
    );
    expect(
      readerVerticalInset(
        menuVisible: true,
        pagePadding: 24,
        safePadding: 20,
        top: false,
      ),
      readerMenuBottomBar + 20,
    );
  });
}
