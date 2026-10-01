import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A small, composable entrance animation used by page chrome and empty states.
/// It automatically becomes a no-op for accessibility and e-ink modes.
class AppEntrance extends StatefulWidget {
  const AppEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppTokens.durationMed,
    this.offset = const Offset(0, .035),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

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
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
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

/// Subtle scale feedback for prominent actions, without changing semantics.
class AppPressable extends StatefulWidget {
  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled;
    final reduce = MediaQuery.disableAnimationsOf(context);
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
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
    return widget.onTap == null
        ? feedback
        : GestureDetector(
            onTap: disabled ? null : widget.onTap,
            child: feedback,
          );
  }
}
