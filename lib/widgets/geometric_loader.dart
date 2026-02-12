import 'dart:math' as math;
import 'package:flutter/material.dart';

class GeometricLoader extends StatefulWidget {
  final double size;
  final bool isDarkMode;

  const GeometricLoader({
    super.key,
    this.size = 50.0,
    required this.isDarkMode,
  });

  @override
  State<GeometricLoader> createState() => _GeometricLoaderState();
}

class _GeometricLoaderState extends State<GeometricLoader>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _sidesAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _sidesAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 3.0,
          end: 4.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 4.0,
          end: 5.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 5.0,
          end: 6.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 6.0,
          end: 8.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 8.0,
          end: 50.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1.5,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 50.0,
          end: 3.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
    ]).animate(_mainController);

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _mainController, curve: Curves.linear));

    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(
          begin: const Color(0xFF6366F1),
          end: const Color(0xFFEC4899),
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: const Color(0xFFEC4899),
          end: const Color(0xFFF43F5E),
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: const Color(0xFFF43F5E),
          end: const Color(0xFFFB923C),
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: const Color(0xFFFB923C),
          end: const Color(0xFF22D3EE),
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ColorTween(
          begin: const Color(0xFF22D3EE),
          end: const Color(0xFF6366F1),
        ),
        weight: 20,
      ),
    ]).animate(_mainController);
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotateAnimation.value,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _MorphShapePainter(
                sides: _sidesAnimation.value,
                color: _colorAnimation.value ?? const Color(0xFF6366F1),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MorphShapePainter extends CustomPainter {
  final double sides;
  final Color color;

  _MorphShapePainter({required this.sides, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final Paint glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2;

    final Path path = Path();
    double angleStep = (2 * math.pi) / sides;

    path.moveTo(centerX + radius * math.cos(0), centerY + radius * math.sin(0));

    for (int i = 1; i <= sides.ceil(); i++) {
      double x = centerX + radius * math.cos(angleStep * i);
      double y = centerY + radius * math.sin(angleStep * i);
      path.lineTo(x, y);
    }

    path.close();

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MorphShapePainter old) {
    return old.sides != sides || old.color != color;
  }
}
