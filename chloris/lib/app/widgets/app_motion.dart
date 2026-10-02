import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Single source of truth for "may this widget animate?". The app already
/// folds the in-app reduce-motion setting into [MediaQuery.disableAnimations]
/// (see `app.dart`), so every motion widget only needs to ask here.
abstract final class AppMotion {
  static bool enabled(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context);

  /// Whether the Absolutely expressive layer (draw-on strokes, hover lift,
  /// staggered entrances) applies. Classic and terminal keep their motion.
  static bool expressive(BuildContext context) =>
      enabled(context) &&
      Theme.of(context).extension<AppStyleExtension>()?.style ==
          AppUiStyle.absolutely;
}

/// A small, composable entrance animation used by page chrome and empty states.
/// It automatically becomes a no-op for accessibility and e-ink modes.
class AppEntrance extends StatefulWidget {
  const AppEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppTokens.durationMed,
    this.offset = const Offset(0, .035),
    this.curve = AppTokens.curveIn,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  @override
  State<AppEntrance> createState() => _AppEntranceState();
}

class _AppEntranceState extends State<AppEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _started = false;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 0,
    );
    _curve = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _timer?.cancel();
      _started = true;
      _controller.value = 1;
      return;
    }
    if (_started) return;
    _started = true;
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = _curve;
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: widget.offset,
          end: Offset.zero,
        ).animate(curve),
        child: widget.child,
      ),
    );
  }
}

/// Staggered entrance for list and grid items: item [index] enters
/// [AppTokens.durationStagger] after the previous one. Only the Absolutely
/// style staggers; other styles enter at once, as before. Only the first
/// [AppTokens.staggerMaxItems] items animate, so rows built later by
/// scrolling a lazy list appear immediately instead of fading in late.
class AppStagger extends StatelessWidget {
  const AppStagger({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  static Duration delayFor(int index) =>
      AppTokens.durationStagger * index.clamp(0, AppTokens.staggerMaxItems);

  @override
  Widget build(BuildContext context) {
    if (index >= AppTokens.staggerMaxItems || !AppMotion.expressive(context)) {
      return child;
    }
    return AppEntrance(
      delay: delayFor(index),
      offset: const Offset(0, .06),
      child: child,
    );
  }
}

/// Subtle scale feedback for prominent actions, without changing semantics.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.lift = 1.5,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  /// Hover lift in logical pixels (Absolutely only).
  final double lift;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;
    final reduce = !AppMotion.enabled(context);
    // Absolutely: a pointer hover lifts the control by a hair — the paper
    // card nudged by a finger. No shadow; the lift is positional only.
    final lift =
        !disabled && _hovered && !_pressed && AppMotion.expressive(context);
    final feedback = Listener(
      onPointerDown: disabled || reduce
          ? null
          : (_) => setState(() => _pressed = true),
      onPointerCancel: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      onPointerUp: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? .975 : 1,
        duration: reduce ? Duration.zero : AppTokens.durationFast,
        curve: AppTokens.curveIn,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: lift ? -widget.lift : 0),
          duration: reduce ? Duration.zero : AppTokens.durationFast,
          curve: AppTokens.curveIn,
          builder: (context, dy, child) => dy == 0
              ? child!
              : Transform.translate(offset: Offset(0, dy), child: child),
          child: widget.child,
        ),
      ),
    );
    final hoverable = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: feedback,
    );
    return widget.onTap == null
        ? hoverable
        : GestureDetector(
            onTap: disabled ? null : widget.onTap,
            child: hoverable,
          );
  }
}
