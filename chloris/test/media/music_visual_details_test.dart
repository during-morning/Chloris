import 'package:chloris/app/theme/app_theme.dart';
import 'package:chloris/app/theme/app_icons.dart';
import 'package:chloris/app/widgets/app_motion.dart';
import 'package:chloris/features/media/lyrics.dart';
import 'package:chloris/features/media/lyrics_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('三行双语歌词在文字放大时无溢出，点击按偏移跳转', (tester) async {
    Duration? seek;
    final document = LyricDocument([
      const LyricLine(
        text: '你听风从远方带来新的故事与声音',
        translation: 'The wind brings new stories and sounds from afar',
        romanization: 'ni ting feng cong yuan fang',
        time: Duration(seconds: 1),
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(280, 650),
              textScaler: TextScaler.linear(2),
            ),
            child: SizedBox(
              width: 280,
              height: 650,
              child: LyricsView(
                document: document,
                position: const Duration(seconds: 2),
                offset: const Duration(milliseconds: 500),
                onSeek: (p) => seek = p,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('lyric-0')));
    expect(seek, const Duration(milliseconds: 1500));
  });
  testWidgets('按压动效不抢按钮点击，减少动画禁用缩放', (tester) async {
    var clicks = 0;
    for (final reduce in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: Center(
              child: AppPressable(
                child: FilledButton(
                  onPressed: () => clicks++,
                  child: const Text('播放'),
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('播放')),
      );
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        reduce ? 1 : .975,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(clicks, 2);
  });
  testWidgets('默认主题 AppIcon 使用细线图标，终端文字保持对比度', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(
          AppThemeFamily.green,
          style: AppUiStyle.absolutely,
        ),
        home: const AppIcon(AppIcons.music),
      ),
    );
    final icon = tester.widget<Icon>(find.byType(Icon).last);
    expect(icon.icon?.fontFamily, contains('Lucide'));
    final terminal = AppTheme.light(
      AppThemeFamily.green,
      style: AppUiStyle.terminal,
    );
    expect(terminal.colorScheme.onPrimary, isNot(terminal.colorScheme.primary));
  });
}
