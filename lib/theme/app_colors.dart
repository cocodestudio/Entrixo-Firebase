import 'package:flutter/material.dart';

class AppColors {
  static const Color deepPurple = Color(0xFF2E1B5C);
  static const Color royalPurple = Color(0xFF5B3A9D);
  static const Color vibrantOrange = Color(0xFFFF6B35);
  static const Color coralRed = Color(0xFFE74C3C);
  static const Color darkText = Color(0xFF1A1A1A);
  static const Color mediumGray = Color(0xFF666666);
  static const Color lightGray = Color(0xFFE5E5E5);
  static const Color offWhite = Color(0xFFF5F5F7);
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);
  static const Color present = Color(0xFF27AE60);
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [royalPurple, vibrantOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
