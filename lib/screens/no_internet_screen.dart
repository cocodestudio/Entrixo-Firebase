import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const NoInternetScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color primaryColor = const Color(0xFF6366F1);
    final Color bgColor = isDarkMode
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8F9FA);
    final Color textColor = isDarkMode ? Colors.white : const Color(0xFF1E293B);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        HapticFeedback.lightImpact();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDarkMode
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarColor: bgColor,
          systemNavigationBarIconBrightness: isDarkMode
              ? Brightness.light
              : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              Positioned(
                top: -100,
                right: -100,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor.withOpacity(isDarkMode ? 0.15 : 0.05),
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: -50,
                left: -50,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(
                        0xFF8B5CF6,
                      ).withOpacity(isDarkMode ? 0.15 : 0.05),
                    ),
                  ),
                ),
              ),

              // Main Content
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.8, end: 1.0),
                        duration: const Duration(seconds: 2),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: value,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryColor.withOpacity(0.1),
                                  ),
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.wifi_off_rounded,
                                  size: 32,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          );
                        },
                        onEnd: () {},
                      ),

                      const SizedBox(height: 40),

                      Text(
                        "No Internet Connection",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        "You are offline. Please check your connection\nto continue using Entrixo.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: textColor.withOpacity(0.6),
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            onRetry();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "Try Again",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text(
                        "COCODE STUDIO",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: textColor.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
