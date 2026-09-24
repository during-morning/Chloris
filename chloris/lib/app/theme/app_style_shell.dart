import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Style-specific chrome that sits above Material widgets.
///
/// Absolutely paints a warm paper canvas; terminal paints a monochrome console
/// with status rails. The classic style keeps the plain scaffold.
class AppStyleShell extends StatelessWidget {
  const AppStyleShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).extension<AppStyleExtension>()?.style;
    return switch (style) {
      AppUiStyle.absolutely => _AbsolutelyShell(child: child),
      AppUiStyle.terminal => _TerminalShell(child: child),
      _ => child,
    };
  }
}

/// Warm editorial canvas: a paper-white top edge settling into a deeper
/// cream at the fold. No texture — the Cowork look is clean stock, not grain.
class _AbsolutelyShell extends StatelessWidget {
  const _AbsolutelyShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [
                  cs.surfaceBright.withValues(alpha: 0.35),
                  cs.surface,
                  cs.surfaceDim,
                ]
              : const [
                  Color(0xFFF5F3EC),
                  Color(0xFFF0EEE6),
                  Color(0xFFE9E6DC),
                ],
          stops: const [0, .45, 1],
        ),
      ),
      child: child,
    );
  }
}

/// 终端外观的外壳：只保留底色与极淡的网格，**不再画状态栏**。
///
/// 原先上下各有一条 `_TerminalBar`（`chloris@read:~$` / `~/chloris` /
/// `wasd · arrows · esc`），属于纯装饰文字，还引入了一个常驻的光标闪烁动画
/// （光栅线程每 900ms 被迫重绘一次）。用户反馈这些文字多余，已整体移除 ——
/// 这同时消掉了那个动画，切主题/滚动时的渲染负担也随之少了一份。
class _TerminalShell extends StatelessWidget {
  const _TerminalShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: CustomPaint(painter: _TerminalGridPainter(cs.onSurface)),
          ),
          // 静态状态语义：上下各一条发丝线框定终端视口。刻意不用动画——
          // 光标闪烁此前已被移除（光栅线程周期重绘），这里只保留恒定的
          // 「视口即终端」边界感。
          IgnorePointer(
            child: Column(
              children: [
                Container(height: 1, color: cs.onSurface.withValues(alpha: 0.10)),
                const Spacer(),
                Container(height: 1, color: cs.onSurface.withValues(alpha: 0.10)),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _TerminalGridPainter extends CustomPainter {
  _TerminalGridPainter(this.line);

  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line.withValues(alpha: 0.018)
      ..strokeWidth = 1;
    const step = 32.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TerminalGridPainter oldDelegate) =>
      oldDelegate.line != line;
}
