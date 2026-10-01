import 'package:flutter/material.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_icons.dart';
import 'music_artwork_image.dart';

class MusicArtwork extends StatelessWidget {
  const MusicArtwork({super.key, this.url, this.size = 48});
  final String? url;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(
      Theme.of(context).extension<AppStyleExtension>()?.controlRadius ??
          AppTokens.radius8,
    ),
    child: AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppTokens.durationMed,
      child: SizedBox.square(
        key: ValueKey(url),
        dimension: size,
        child: url?.isNotEmpty == true
            ? musicArtworkImage(url!, size)
            : CustomPaint(
                painter: _AbstractArtworkPainter(
                  Theme.of(context).colorScheme,
                ),
                child: Center(
                  child: AppIcon(
                    AppIcons.music,
                    size: size * .23,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
      ),
    ),
  );
}

class _AbstractArtworkPainter extends CustomPainter {
  _AbstractArtworkPainter(this.colors);
  final ColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final width = size.width;
    final height = size.height;
    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.primaryContainer,
          colors.tertiaryContainer,
          colors.secondaryContainer,
        ],
        stops: const [0, .58, 1],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    // Diffused color gives the placeholder the depth of an album sleeve while
    // keeping it legible when the player crops it into a circle.
    _drawGlow(
      canvas,
      Offset(width * .79, height * .2),
      size.shortestSide * .54,
      colors.tertiary,
    );
    _drawGlow(
      canvas,
      Offset(width * .12, height * .84),
      size.shortestSide * .48,
      colors.primary,
    );

    final flowingShape = Path()
      ..moveTo(-width * .14, height * .57)
      ..cubicTo(
        width * .16,
        height * .16,
        width * .38,
        height * .86,
        width * .68,
        height * .48,
      )
      ..cubicTo(
        width * .88,
        height * .22,
        width * 1.02,
        height * .38,
        width * 1.14,
        height * .24,
      )
      ..lineTo(width * 1.14, height * .78)
      ..cubicTo(
        width * .77,
        height * 1.03,
        width * .48,
        height * .64,
        width * .2,
        height * 1.08,
      )
      ..close();
    canvas.drawPath(
      flowingShape,
      Paint()..color = colors.secondary.withValues(alpha: .2),
    );

    final wave = Path()
      ..moveTo(-width * .08, height * .72)
      ..cubicTo(
        width * .22,
        height * .48,
        width * .43,
        height * .98,
        width * .72,
        height * .62,
      )
      ..cubicTo(
        width * .89,
        height * .42,
        width * 1.04,
        height * .54,
        width * 1.1,
        height * .43,
      );
    canvas.drawPath(
      wave,
      Paint()
        ..color = colors.onSecondaryContainer.withValues(alpha: .24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .018
        ..strokeCap = StrokeCap.round,
    );

    _drawSparkle(canvas, Offset(width * .2, height * .22), size.shortestSide);
    _drawSparkle(canvas, Offset(width * .8, height * .76), size.shortestSide);
  }

  @override
  bool shouldRepaint(_AbstractArtworkPainter old) => old.colors != colors;
}

void _drawGlow(Canvas canvas, Offset center, double radius, Color color) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: .42), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
}

void _drawSparkle(Canvas canvas, Offset center, double side) {
  final path = Path()
    ..moveTo(center.dx, center.dy - side * .035)
    ..quadraticBezierTo(
      center.dx + side * .008,
      center.dy - side * .008,
      center.dx + side * .035,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx + side * .008,
      center.dy + side * .008,
      center.dx,
      center.dy + side * .035,
    )
    ..quadraticBezierTo(
      center.dx - side * .008,
      center.dy + side * .008,
      center.dx - side * .035,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx - side * .008,
      center.dy - side * .008,
      center.dx,
      center.dy - side * .035,
    )
    ..close();
  canvas.drawPath(
    path,
    Paint()..color = Colors.white.withValues(alpha: .72),
  );
}
