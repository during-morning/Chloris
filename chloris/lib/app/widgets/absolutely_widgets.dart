import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Signature Absolutely components: the divider grid, the centered hero block,
/// the terracotta poster banner and the paper specimen tag.
///
/// All of them are style-aware — under classic / terminal they degrade to
/// plain column / box compositions so screens can adopt them without
/// branching on [AppUiStyle].

/// Hero block (official error / capabilities page grammar):
/// centered thin-line icon → serif display title → narrow muted subtitle.
class AbsolutelyHeroBlock extends StatelessWidget {
  const AbsolutelyHeroBlock({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppTokens.space24,
      vertical: AppTokens.space48,
    ),
    this.actions,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.extension<AppStyleExtension>();
    final absolutely = style?.style == AppUiStyle.absolutely;
    final cs = theme.colorScheme;
    return Padding(
      padding: padding,
      child: Column(
        children: [
          if (icon != null) ...[
            AppIcon(
              icon!,
              size: 36,
              color: absolutely ? cs.onSurface : cs.onSurfaceVariant,
            ),
            const SizedBox(height: AppTokens.space20),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: absolutely
                ? theme.textTheme.displaySmall
                : theme.textTheme.headlineMedium,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: absolutely
                    ? AppTheme.absolutelySubtitle(theme)
                    : theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
              ),
            ),
          ],
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: AppTokens.space24),
            Wrap(
              spacing: AppTokens.space12,
              runSpacing: AppTokens.space8,
              alignment: WrapAlignment.center,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Divider grid (official "Core capabilities" grammar): children laid out in
/// [columns] with 1px hairline separators instead of card boxes.
class AbsolutelyDividerGrid extends StatelessWidget {
  const AbsolutelyDividerGrid({
    super.key,
    required this.children,
    this.columns = 3,
    this.crossAxisSpacing = AppTokens.space24,
    this.mainAxisSpacing = AppTokens.space24,
  });

  final List<Widget> children;
  final int columns;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final line = BorderSide(color: cs.outlineVariant);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = <Widget>[];
      for (var j = i; j < (i + columns) && j < children.length; j++) {
        final cell = Expanded(child: children[j]);
        cells.add(
          j > i
              ? Container(decoration: BoxDecoration(border: Border(left: line)), padding: EdgeInsets.only(left: crossAxisSpacing), child: cell)
              : cell,
        );
      }
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells));
      if (i + columns < children.length) {
        rows.add(SizedBox(height: mainAxisSpacing));
      }
    }
    return Column(children: rows);
  }
}

/// Terracotta poster banner (trailer 字卡 grammar): clay ground, cream serif
/// display, faint grid paper. Use sparingly — one per screen at most.
class AbsolutelyBannerCard extends StatelessWidget {
  const AbsolutelyBannerCard({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
    this.borderRadius = 12,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final ground = dark ? const Color(0xFF4E2617) : const Color(0xFFC96442);
    final onGround = dark ? const Color(0xFFF8D9C9) : const Color(0xFFFCF6F1);
    final gridPaint = dark
        ? onGround.withValues(alpha: 0.05)
        : onGround.withValues(alpha: 0.10);
    return Semantics(
      button: onTap != null,
      child: Material(
        color: ground,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BannerGridPainter(gridPaint),
                ),
              ),
            ),
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space24,
                  vertical: AppTokens.space24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: (theme.textTheme.headlineSmall ?? const TextStyle())
                          .copyWith(color: onGround),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: AppTokens.space8),
                      Text(
                        subtitle!,
                        style: (theme.textTheme.bodyMedium ?? const TextStyle())
                            .copyWith(color: onGround.withValues(alpha: 0.85)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerGridPainter extends CustomPainter {
  _BannerGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 24.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BannerGridPainter old) =>
      old.color != color;
}

/// Paper specimen tag (trailer 标本标签卡 grammar): small raised paper chip
/// with a hairline edge and a quiet serif label. For annotations, counters
/// and "fig." style metadata.
class AbsolutelySpecimenTag extends StatelessWidget {
  const AbsolutelySpecimenTag({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: selected ? cs.secondaryContainer : cs.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: selected ? cs.outline : cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space10,
            vertical: AppTokens.space4,
          ),
          child: Text(
            label,
            style: (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
              fontFamily: AppTheme.absolutelySerif,
              fontFamilyFallback: AppTheme.absolutelySerifFallback,
              letterSpacing: 0.4,
              color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
