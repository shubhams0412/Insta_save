import 'package:flutter/material.dart';

Route createSlideRoute(Widget screen, {SlideFrom direction = SlideFrom.right}) {
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
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(
        begin: begin,
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeInOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

enum SlideFrom { right, left, bottom, top }
