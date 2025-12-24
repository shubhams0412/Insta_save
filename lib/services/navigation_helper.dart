import 'package:flutter/material.dart';

enum SlideFrom { right, left, bottom, top }

Route createSlideRoute(
    Widget screen, {
      SlideFrom direction = SlideFrom.right,
      Duration duration = const Duration(milliseconds: 400),
      Curve curve = Curves.easeInOutCubic,
    }) {
  return PageRouteBuilder(
    transitionDuration: duration,
    reverseTransitionDuration: duration, // ✅ Ensures smooth closing animation
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {

      // Determine start position based on direction
      Offset begin;
      switch (direction) {
        case SlideFrom.right:
          begin = const Offset(1.0, 0.0);
          break;
        case SlideFrom.left:
          begin = const Offset(-1.0, 0.0);
          break;
        case SlideFrom.bottom:
          begin = const Offset(0.0, 1.0);
          break;
        case SlideFrom.top:
          begin = const Offset(0.0, -1.0);
          break;
      }

      // Create the animation
      var tween = Tween(begin: begin, end: Offset.zero)
          .chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}