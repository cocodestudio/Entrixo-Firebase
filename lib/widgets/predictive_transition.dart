import 'dart:ui';
import 'package:flutter/material.dart';

class PredictiveBackTransitionBuilder extends PageTransitionsBuilder {
  const PredictiveBackTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _PredictiveBackTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class _PredictiveBackTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _PredictiveBackTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Animation<Offset> slideInAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return SlideTransition(
      position: slideInAnimation,
      child: AnimatedBuilder(
        animation: secondaryAnimation,
        builder: (context, child) {
          final double progress = secondaryAnimation.value;

          if (progress == 0) {
            return child!;
          }

          final double scale = 1.0 - (0.08 * progress);
          final double radius = 28.0 * progress;
          final double brightnessProgress = 1.0 - (0.15 * progress);

          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  if (progress > 0)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2 * progress),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(-5, 0),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.matrix([
                        brightnessProgress,
                        0,
                        0,
                        0,
                        0,
                        0,
                        brightnessProgress,
                        0,
                        0,
                        0,
                        0,
                        0,
                        brightnessProgress,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                      child: child!,
                    ),
                    if (progress > 0)
                      IgnorePointer(
                        child: Container(
                          color: Colors.black.withOpacity(0.08 * progress),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        child: child,
      ),
    );
  }
}
