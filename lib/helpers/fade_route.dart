import 'package:flutter/material.dart';

class FadeRoute<T> extends PageRoute<T> {
  FadeRoute({
    required this.builder,
    this.duration = const Duration(milliseconds: 300),
    super.settings,
  });

  final WidgetBuilder builder;
  final Duration duration;

  @override
  bool get opaque => true;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }
}
