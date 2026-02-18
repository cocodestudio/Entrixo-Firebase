import 'dart:async';
import 'package:entrixo/screens/student_setup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../home/dashboard_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
    _initAppFlow();
  }

  Future<void> _initAppFlow() async {
    final startTime = DateTime.now();
    Widget nextScreen = const LoginScreen();

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

      if (isFirstTime) {
        nextScreen = const OnboardingScreen();
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          nextScreen = await _determineUserDestination(user);
        } else {
          nextScreen = const LoginScreen();
        }
      }
    } catch (e) {
      nextScreen = const LoginScreen();
    } finally {
      _navigate(nextScreen, startTime);
    }
  }

  Future<Widget> _determineUserDestination(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final String role = data['role'] ?? 'student';
        final bool isSetupCompleted = data['isSetupCompleted'] ?? false;

        await prefs.setString('user_role', role);
        await prefs.setBool('setup_done', isSetupCompleted);

        if (role == 'admin') {
          return const DashboardScreen();
        }

        return isSetupCompleted
            ? const DashboardScreen()
            : const StudentSetupScreen();
      }

      return const LoginScreen();
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final bool? localSetupDone = prefs.getBool('setup_done');
      final String? localRole = prefs.getString('user_role');

      if (localSetupDone == true || localRole == 'admin') {
        return const DashboardScreen();
      }

      return const LoginScreen();
    }
  }

  void _navigate(Widget nextScreen, DateTime startTime) {
    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 2000) - elapsed;

    Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (!mounted) return;

      final route = PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curveAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.fastOutSlowIn,
            reverseCurve: Curves.fastOutSlowIn,
          );

          return FadeTransition(
            opacity: curveAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(curveAnimation),
              child: child,
            ),
          );
        },
      );

      Navigator.of(context).pushAndRemoveUntil(route, (route) => false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final ThemeData theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            children: [
              Positioned(
                top: -size.width * 0.2,
                right: -size.width * 0.2,
                child: Container(
                  width: size.width * 0.7,
                  height: size.width * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.primaryColor.withOpacity(0.04),
                  ),
                ),
              ),
              Positioned(
                bottom: size.height * 0.1,
                left: -size.width * 0.3,
                child: Container(
                  width: size.width * 0.9,
                  height: size.width * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.secondary.withOpacity(0.03),
                  ),
                ),
              ),
              Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _opacityAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Image.asset(
                          'assets/images/splash_logo.png',
                          width: size.width * 0.6,
                          fit: BoxFit.contain,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: 50.0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _opacityAnimation.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'from',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/cocode.png',
                                height: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'CoCode Studio',
                                style: TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}