import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS-style follow-finger page: the incoming page tracks the drag,
/// and a second drag interrupts the settle animation.
class FollowPageRoute<T> extends PageRoute<T> {
  FollowPageRoute({
    required this.builder,
    super.settings,
    this.duration = const Duration(milliseconds: 320),
  });

  final WidgetBuilder builder;
  final Duration duration;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Theme.of(context).pageTransitionsTheme.builders[Theme.of(context).platform]
        is! CupertinoPageTransitionsBuilder) {
      // eink / instant
      return child;
    }
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: false,
      child: child,
    );
  }
}

/// Follow-finger modal sheet. Drag the handle / body to dismiss; a second
/// drag interrupts the close animation.
Future<T?> showFollowSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final reduce = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: true,
    enableDrag: true,
    useSafeArea: true,
    transitionAnimationController: reduce ? null : null,
    builder: builder,
  );
}
