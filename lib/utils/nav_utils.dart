import 'package:flutter/material.dart';
import '../widgets/predictive_transition.dart';

class NavUtils {
  static void navigate(BuildContext context, Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return const PredictiveBackTransitionBuilder().buildTransitions(
            ModalRoute.of(context) as PageRoute,
            context,
            animation,
            secondaryAnimation,
            child,
          );
        },
      ),
    );
  }

  static void pushReplacement(BuildContext context, Widget page) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return const PredictiveBackTransitionBuilder().buildTransitions(
            ModalRoute.of(context) as PageRoute,
            context,
            animation,
            secondaryAnimation,
            child,
          );
        },
      ),
    );
  }
}