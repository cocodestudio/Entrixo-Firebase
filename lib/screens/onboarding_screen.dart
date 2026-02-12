import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../auth/login_screen.dart';
import '../utils/nav_utils.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingData = [
    {
      "title": "Smart Lab Management",
      "description":
          "Experience the next generation of university lab infrastructure with automated tracking and seamless integration.",
    },
    {
      "title": "Secure & Offline First",
      "description":
          "Military-grade encryption with offline QR scanning ensures your attendance is always recorded accurately without bypass.",
    },
    {
      "title": "Real-time Analytics",
      "description":
          "Empower faculty with live dashboards, instant student counts, and effortless event management across all departments.",
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      NavUtils.navigate(context, const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          Expanded(
            flex: 13,
            child: SafeArea(
              bottom: false,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return SizedBox(
                    width: double.infinity,
                    child: CustomPaint(
                      painter: TechIllustrationPainter(
                        progress: _animationController.value,
                        pageIndex: _currentPage,
                        primaryColor: theme.primaryColor,
                        accentColor: theme.colorScheme.secondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 11,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.05),
                    blurRadius: 25,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _onboardingData.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOutBack,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 6,
                          width: _currentPage == index ? 28 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? theme.colorScheme.secondary
                                : const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (value) {
                          setState(() {
                            _currentPage = value;
                          });
                        },
                        itemCount: _onboardingData.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  _onboardingData[index]["title"]!,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontSize: 26,
                                    height: 1.2,
                                    color: const Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _onboardingData[index]["description"]!,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: const Color(0xFF666666),
                                    height: 1.6,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _currentPage == 2
                                  ? theme.colorScheme.secondary.withOpacity(0.3)
                                  : Colors.transparent,
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentPage == 2
                                ? theme.colorScheme.secondary
                                : theme.primaryColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _currentPage == 0
                                  ? 'Welcome'
                                  : _currentPage == 1
                                  ? 'Learn More'
                                  : 'Get Started',
                              key: ValueKey<int>(_currentPage),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TechIllustrationPainter extends CustomPainter {
  final double progress;
  final int pageIndex;
  final Color primaryColor;
  final Color accentColor;

  TechIllustrationPainter({
    required this.progress,
    required this.pageIndex,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2.2);
    final maxRadius = math.min(size.width, size.height) * 0.38;

    final bgGradient = RadialGradient(
      colors: [
        accentColor.withOpacity(0.08),
        accentColor.withOpacity(0.02),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final bgPaint = Paint()
      ..shader = bgGradient.createShader(
        Rect.fromCircle(center: center, radius: maxRadius * 1.5),
      );

    canvas.drawCircle(center, maxRadius * 1.5, bgPaint);

    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final paintGlow = Paint()
      ..color = accentColor.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);

    final paintNode = Paint()
      ..color = primaryColor.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final paintAccentNode = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    _drawFloatingParticles(
      canvas,
      center,
      maxRadius,
      progress,
      primaryColor,
      accentColor,
    );

    for (int i = 1; i <= 4; i++) {
      final radius = maxRadius * (i / 4);
      final orbitProgress = i % 2 == 0 ? progress : -progress;
      final sweepAngle = math.pi * 1.6;
      final opacity = 0.04 + (i * 0.015);

      paintLine.color = primaryColor.withOpacity(opacity);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        orbitProgress * math.pi * 2,
        sweepAngle,
        false,
        paintLine,
      );

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = primaryColor.withOpacity(0.015)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      if (i == 2 || i == 3) {
        final glowArc = Paint()
          ..color = accentColor.withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          orbitProgress * math.pi * 2,
          math.pi * 0.3,
          false,
          glowArc,
        );
      }
    }

    final nodesCount = 8;
    final angleStep = (2 * math.pi) / nodesCount;
    final targetRotation = pageIndex * (math.pi / 2);
    final currentRotation = (progress * math.pi * 2) + targetRotation;

    for (int i = 0; i < nodesCount; i++) {
      final angle = (i * angleStep) + currentRotation;
      final pulse = math.sin((progress * math.pi * 6) + (i * 0.5)) * 6;
      final dynamicRadius = maxRadius * 0.85 + pulse;

      final x = center.dx + dynamicRadius * math.cos(angle);
      final y = center.dy + dynamicRadius * math.sin(angle);
      final nodeCenter = Offset(x, y);
      final linePaint = Paint()
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            primaryColor.withOpacity(0.15),
            primaryColor.withOpacity(0.03),
          ],
        ).createShader(Rect.fromPoints(center, nodeCenter));

      canvas.drawLine(center, nodeCenter, linePaint);

      if (i % 2 == 0) {
        final innerAngle = angle + math.pi / 4;
        final innerX =
            center.dx + (dynamicRadius * 0.45) * math.cos(innerAngle);
        final innerY =
            center.dy + (dynamicRadius * 0.45) * math.sin(innerAngle);

        final innerLinePaint = Paint()
          ..color = primaryColor.withOpacity(0.08)
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(nodeCenter, Offset(innerX, innerY), innerLinePaint);
      }

      final isAccentNode =
          i == pageIndex * 2 || i == (pageIndex * 2 + 3) % nodesCount;

      if (isAccentNode) {
        canvas.drawCircle(nodeCenter, 28, paintGlow);
        canvas.drawCircle(
          nodeCenter,
          18,
          Paint()
            ..color = accentColor.withOpacity(0.1)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );

        final nodePaint = Paint()
          ..shader = RadialGradient(
            colors: [accentColor.withOpacity(0.9), accentColor],
          ).createShader(Rect.fromCircle(center: nodeCenter, radius: 7));

        canvas.drawCircle(nodeCenter, 7, nodePaint);

        final ringPulse = math.sin(progress * math.pi * 8) * 1.5;
        canvas.drawCircle(
          nodeCenter,
          13 + ringPulse,
          Paint()
            ..color = accentColor.withOpacity(0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );

        canvas.drawCircle(
          nodeCenter,
          2.5,
          Paint()..color = Colors.white.withOpacity(0.6),
        );
      } else {
        final regularNodePaint = Paint()
          ..shader = RadialGradient(
            colors: [
              primaryColor.withOpacity(0.9),
              primaryColor.withOpacity(0.7),
            ],
          ).createShader(Rect.fromCircle(center: nodeCenter, radius: 4.5));

        canvas.drawCircle(nodeCenter, 4.5, regularNodePaint);
        canvas.drawCircle(
          nodeCenter,
          7.5,
          Paint()
            ..color = primaryColor.withOpacity(0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    final corePulse = math.sin(progress * math.pi * 3) * 2.5;
    final coreRadius = 24.0 + corePulse;
    canvas.drawCircle(center, coreRadius * 2.2, paintGlow);
    canvas.drawCircle(
      center,
      coreRadius * 1.5,
      Paint()
        ..color = accentColor.withOpacity(0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.95),
          primaryColor.withOpacity(0.85),
          primaryColor.withOpacity(0.7),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));

    canvas.drawCircle(center, coreRadius, corePaint);

    canvas.drawCircle(
      center,
      coreRadius * 0.7,
      Paint()
        ..color = accentColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final centerPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.8), accentColor],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius * 0.4));

    canvas.drawCircle(center, coreRadius * 0.4, centerPaint);
    canvas.drawCircle(
      center,
      coreRadius * 0.15,
      Paint()..color = Colors.white.withOpacity(0.9),
    );
  }

  void _drawFloatingParticles(
    Canvas canvas,
    Offset center,
    double maxRadius,
    double progress,
    Color primaryColor,
    Color accentColor,
  ) {
    final particleCount = 12;

    for (int i = 0; i < particleCount; i++) {
      final angle =
          (i / particleCount) * math.pi * 2 + (progress * math.pi * 0.5);
      final distance =
          maxRadius * 1.2 + (math.sin(progress * math.pi * 3 + i) * 15);
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);

      final opacity = (math.sin(progress * math.pi * 4 + i) * 0.15 + 0.15)
          .clamp(0.0, 0.3);
      final particlePaint = Paint()
        ..color = (i % 3 == 0 ? accentColor : primaryColor).withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final size = i % 3 == 0 ? 3.5 : 2.0;
      canvas.drawCircle(Offset(x, y), size, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant TechIllustrationPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pageIndex != pageIndex;
  }
}
