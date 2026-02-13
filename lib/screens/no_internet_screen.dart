import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const NoInternetScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color bgColor = isDarkMode ? const Color(0xFF0F172A) : Colors.white;
    Color textColor = isDarkMode ? Colors.white : const Color(0xFF1E293B);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        HapticFeedback.heavyImpact();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDarkMode
              ? Brightness.light
              : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: bgColor,
          body: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                    : [Colors.white, const Color(0xFFF1F5F9)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.8, end: 1.0),
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOutSine,
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent.withOpacity(0.1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.2 * value),
                              blurRadius: 30 * value,
                              spreadRadius: 10 * value,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.wifi_off_rounded,
                          size: 80,
                          color: Colors.redAccent.shade200,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  "No Internet Connection",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "It looks like you are offline.\nPlease check your connection and try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: 16,
                    color: textColor.withOpacity(0.6),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 50),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onRetry();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.white : Colors.black,
                      foregroundColor: isDarkMode ? Colors.black : Colors.white,
                      elevation: 10,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Try Again",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Extra Hint
                Text(
                  "CoCode Studio Internal Monitor",
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: textColor.withOpacity(0.3),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
