import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../home/dashboard_screen.dart';
import '../screens/student_setup_screen.dart';
import '../utils/custom_toast.dart';
import '../utils/nav_utils.dart';
import '../widgets/geometric_loader.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  late AnimationController _animationController;
  String _verificationId = "";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _phoneFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _otpFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _onGetOtpPressed() {
    FocusScope.of(context).unfocus();
    String phone = _phoneController.text.trim();

    if (phone.isEmpty || phone.length != 10) {
      CustomToast.show(
        context,
        "Please enter a valid 10-digit phone number",
        isError: true,
      );
      return;
    }

    ref.read(authControllerProvider.notifier).sendOTP(context, phone, (verId) {
      _verificationId = verId;
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) FocusScope.of(context).requestFocus(_otpFocusNode);
      });
    });
  }

  void _onVerifyOtpPressed() {
    FocusScope.of(context).unfocus();
    String otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      CustomToast.show(
        context,
        "Please enter a valid 6-digit OTP",
        isError: true,
      );
      return;
    }

    ref.read(authControllerProvider.notifier).verifyAndLogin(
      context,
      _verificationId,
      otp,
      "student",
      (bool isSetupDone) {
        if (isSetupDone) {
          NavUtils.pushReplacement(context, const DashboardScreen());
        } else {
          NavUtils.pushReplacement(context, const StudentSetupScreen());
        }
      },
    );
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    _otpController.clear();
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height * (isKeyboardVisible ? 0.25 : 0.45),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: SecurityIllustrationPainter(
                      progress: _animationController.value,
                      primaryColor: theme.primaryColor,
                      accentColor: theme.colorScheme.secondary,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: size.height * (isKeyboardVisible ? 0.22 : 0.4),
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.08),
                      blurRadius: 30,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildPhoneSection(
                      theme,
                      size,
                      isKeyboardVisible,
                      isLoading,
                    ),
                    _buildOtpSection(theme, size, isKeyboardVisible, isLoading),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneSection(
    ThemeData theme,
    Size size,
    bool isKeyboardVisible,
    bool isLoading,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back',
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your phone number to securely access your portal.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF666666),
              height: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 40),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: _phoneFocusNode.hasFocus
                  ? Colors.white
                  : const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _phoneFocusNode.hasFocus
                    ? theme.primaryColor.withOpacity(0.6)
                    : const Color(0xFFE5E7EB),
                width: _phoneFocusNode.hasFocus ? 2.0 : 1.5,
              ),
              boxShadow: _phoneFocusNode.hasFocus
                  ? [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Text(
                  '+91',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: _phoneFocusNode.hasFocus
                        ? theme.primaryColor
                        : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      fontSize: 18,
                      color: const Color(0xFF1A1A1A),
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: 'Phone Number',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFAAAAAA),
                        letterSpacing: 0.5,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : _onGetOtpPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                disabledBackgroundColor: theme.colorScheme.secondary
                    .withOpacity(0.6),
                elevation: isLoading ? 0 : 4,
                shadowColor: theme.colorScheme.secondary.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const GeometricLoader(size: 28, isDarkMode: false)
                  : Text(
                      'Get OTP',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
          SizedBox(height: isKeyboardVisible ? size.height * 0.4 : 20),
        ],
      ),
    );
  }

  Widget _buildOtpSection(
    ThemeData theme,
    Size size,
    bool isKeyboardVisible,
    bool isLoading,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _goBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: theme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Verify OTP',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 28,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF666666),
                height: 1.5,
                fontSize: 15,
              ),
              children: [
                const TextSpan(text: 'Enter the 6-digit code sent to '),
                TextSpan(
                  text: '+91 ${_phoneController.text}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 64,
            child: Stack(
              children: [
                Opacity(
                  opacity: 0.0,
                  child: TextField(
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (value) {
                      setState(() {});
                      if (value.length == 6) {
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                ),
                IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      String char = '';
                      if (_otpController.text.length > index) {
                        char = _otpController.text[index];
                      }
                      bool isCurrent =
                          _otpController.text.length == index &&
                          _otpFocusNode.hasFocus;
                      bool isFilled = char.isNotEmpty;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: (size.width - 64 - 50) / 6,
                        height: 64,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent || isFilled
                              ? Colors.white
                              : const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCurrent
                                ? theme.primaryColor
                                : isFilled
                                ? theme.primaryColor.withOpacity(0.3)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                          boxShadow: isCurrent || isFilled
                              ? [
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          char,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: theme.primaryColor,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : _onVerifyOtpPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                elevation: isLoading ? 0 : 4,
                shadowColor: theme.colorScheme.secondary.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const GeometricLoader(size: 28, isDarkMode: false)
                  : Text(
                      'Verify & Proceed',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(foregroundColor: theme.primaryColor),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  children: [
                    const TextSpan(text: "Didn't receive code? "),
                    TextSpan(
                      text: "Resend",
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: isKeyboardVisible ? size.height * 0.4 : 20),
        ],
      ),
    );
  }
}

class SecurityIllustrationPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color accentColor;

  SecurityIllustrationPainter({
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2.2);
    final maxRadius = math.min(size.width, size.height) * 0.32;

    final bgGradient = RadialGradient(
      colors: [
        accentColor.withOpacity(0.12),
        accentColor.withOpacity(0.04),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4, 1.0],
    );

    final bgPaint = Paint()
      ..shader = bgGradient.createShader(
        Rect.fromCircle(center: center, radius: maxRadius * 2),
      );

    canvas.drawCircle(center, maxRadius * 2, bgPaint);

    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final paintGlow = Paint()
      ..color = accentColor.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);

    _drawSecurityField(
      canvas,
      center,
      maxRadius,
      progress,
      primaryColor,
      accentColor,
    );

    for (int i = 1; i <= 4; i++) {
      final radius = maxRadius * (i / 4.2);
      final pulse = math.sin(progress * math.pi * 2 + i * 0.7) * 3;
      final opacity = 0.02 + (i * 0.012);

      canvas.drawCircle(
        center,
        radius + pulse,
        Paint()
          ..color = primaryColor.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      if (i == 2 || i == 3) {
        canvas.drawCircle(
          center,
          radius + pulse,
          Paint()
            ..color = accentColor.withOpacity(0.06)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
        );
      }
    }

    final lockSize = maxRadius * 0.48;
    final lockTop = center.dy - lockSize * 0.5;
    final lockBottom = center.dy + lockSize * 0.52;
    final lockLeft = center.dx - lockSize * 0.42;
    final lockRight = center.dx + lockSize * 0.42;

    final lockBodyPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            lockLeft,
            center.dy - lockSize * 0.08,
            lockRight,
            lockBottom,
          ),
          const Radius.circular(14),
        ),
      );

    final shacklePath = Path();
    shacklePath.moveTo(lockLeft + lockSize * 0.16, center.dy - lockSize * 0.08);
    shacklePath.lineTo(lockLeft + lockSize * 0.16, lockTop + lockSize * 0.32);
    shacklePath.arcToPoint(
      Offset(lockRight - lockSize * 0.16, lockTop + lockSize * 0.32),
      radius: Radius.circular(lockSize * 0.26),
      clockwise: true,
    );
    shacklePath.lineTo(
      lockRight - lockSize * 0.16,
      center.dy - lockSize * 0.08,
    );

    final lockBodyRect = Rect.fromLTRB(
      lockLeft,
      center.dy - lockSize * 0.08,
      lockRight,
      lockBottom,
    );
    final lockGradient = RadialGradient(
      center: Alignment.topCenter,
      colors: [
        primaryColor.withOpacity(0.15),
        primaryColor.withOpacity(0.08),
        primaryColor.withOpacity(0.05),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    canvas.drawPath(
      lockBodyPath,
      Paint()..shader = lockGradient.createShader(lockBodyRect),
    );

    canvas.drawPath(
      lockBodyPath,
      Paint()
        ..color = accentColor.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawPath(
      lockBodyPath,
      Paint()
        ..color = primaryColor.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawPath(
      shacklePath,
      Paint()
        ..color = primaryColor.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawPath(
      shacklePath,
      Paint()
        ..color = accentColor.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final keyholeSize = lockSize * 0.12;
    final keyholePath = Path();
    keyholePath.addOval(
      Rect.fromCircle(
        center: Offset(center.dx, center.dy + lockSize * 0.08),
        radius: keyholeSize * 0.5,
      ),
    );
    keyholePath.moveTo(
      center.dx - keyholeSize * 0.15,
      center.dy + lockSize * 0.08,
    );
    keyholePath.lineTo(
      center.dx - keyholeSize * 0.22,
      center.dy + lockSize * 0.25,
    );
    keyholePath.lineTo(
      center.dx + keyholeSize * 0.22,
      center.dy + lockSize * 0.25,
    );
    keyholePath.lineTo(
      center.dx + keyholeSize * 0.15,
      center.dy + lockSize * 0.08,
    );
    keyholePath.close();

    canvas.drawPath(
      keyholePath,
      Paint()
        ..color = accentColor.withOpacity(0.4)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      keyholePath,
      Paint()
        ..color = accentColor.withOpacity(0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    final nodesCount = 6;
    final angleStep = (2 * math.pi) / nodesCount;
    final currentRotation = progress * math.pi * 0.8;

    for (int i = 0; i < nodesCount; i++) {
      final angle = (i * angleStep) + currentRotation;
      final pulse = math.sin(progress * math.pi * 3 + i * 0.8) * 4;
      final dynamicRadius = maxRadius * 0.9 + pulse;

      final x = center.dx + dynamicRadius * math.cos(angle);
      final y = center.dy + dynamicRadius * math.sin(angle);
      final nodeCenter = Offset(x, y);

      final linePaint = Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            primaryColor.withOpacity(0.2),
            primaryColor.withOpacity(0.05),
          ],
        ).createShader(Rect.fromPoints(center, nodeCenter));

      canvas.drawLine(center, nodeCenter, linePaint);

      if (i % 2 == 0) {
        canvas.drawCircle(nodeCenter, 14, paintGlow);

        canvas.drawCircle(
          nodeCenter,
          8,
          Paint()
            ..color = accentColor.withOpacity(0.1)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );

        final nodePaint = Paint()
          ..shader = RadialGradient(
            colors: [accentColor.withOpacity(0.95), accentColor],
          ).createShader(Rect.fromCircle(center: nodeCenter, radius: 6));

        canvas.drawCircle(nodeCenter, 6, nodePaint);

        final ringPulse = math.sin(progress * math.pi * 6 + i) * 1.2;
        canvas.drawCircle(
          nodeCenter,
          10 + ringPulse,
          Paint()
            ..color = accentColor.withOpacity(0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );

        canvas.drawCircle(
          nodeCenter,
          2,
          Paint()..color = Colors.white.withOpacity(0.7),
        );
      } else {
        canvas.drawCircle(
          nodeCenter,
          6,
          Paint()
            ..color = primaryColor.withOpacity(0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );

        final regularNodePaint = Paint()
          ..shader = RadialGradient(
            colors: [
              primaryColor.withOpacity(0.8),
              primaryColor.withOpacity(0.6),
            ],
          ).createShader(Rect.fromCircle(center: nodeCenter, radius: 4.5));

        canvas.drawCircle(nodeCenter, 4.5, regularNodePaint);

        canvas.drawCircle(
          nodeCenter,
          7,
          Paint()
            ..color = primaryColor.withOpacity(0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }

    final scanLineYBase = center.dy + lockSize * 0.18;
    final scanProgress = math.sin(progress * math.pi * 3.5);
    final scanLineY = scanLineYBase + (scanProgress * lockSize * 0.18);
    final scanLineWidth = lockSize * 0.55;

    final scanGradient = LinearGradient(
      colors: [
        accentColor.withOpacity(0),
        accentColor.withOpacity(0.3),
        accentColor.withOpacity(0.8),
        accentColor,
        accentColor.withOpacity(0.8),
        accentColor.withOpacity(0.3),
        accentColor.withOpacity(0),
      ],
      stops: const [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0],
    );

    canvas.drawLine(
      Offset(center.dx - scanLineWidth / 2, scanLineY),
      Offset(center.dx + scanLineWidth / 2, scanLineY),
      Paint()
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..shader = scanGradient.createShader(
          Rect.fromLTWH(
            center.dx - scanLineWidth / 2,
            scanLineY - 1,
            scanLineWidth,
            2,
          ),
        ),
    );

    canvas.drawLine(
      Offset(center.dx - scanLineWidth / 2, scanLineY),
      Offset(center.dx + scanLineWidth / 2, scanLineY),
      Paint()
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = scanGradient.createShader(
          Rect.fromLTWH(
            center.dx - scanLineWidth / 2,
            scanLineY - 2,
            scanLineWidth,
            4,
          ),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final scanDotSpacing = lockSize * 0.08;
    for (int i = -2; i <= 2; i++) {
      final dotX = center.dx + (i * scanDotSpacing);
      final dotOpacity = 1.0 - (i.abs() * 0.2);

      canvas.drawCircle(
        Offset(dotX, scanLineY),
        1.5,
        Paint()
          ..color = accentColor.withOpacity(dotOpacity * 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  void _drawSecurityField(
    Canvas canvas,
    Offset center,
    double maxRadius,
    double progress,
    Color primaryColor,
    Color accentColor,
  ) {
    final particleCount = 16;

    for (int i = 0; i < particleCount; i++) {
      final angle =
          (i / particleCount) * math.pi * 2 + (progress * math.pi * 0.3);
      final distance =
          maxRadius * 1.15 + (math.sin(progress * math.pi * 2.5 + i) * 12);
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);

      final opacity = (math.sin(progress * math.pi * 3 + i) * 0.12 + 0.15)
          .clamp(0.0, 0.25);
      final particlePaint = Paint()
        ..color = (i % 4 == 0 ? accentColor : primaryColor).withOpacity(opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      final size = i % 4 == 0 ? 2.5 : 1.5;
      canvas.drawCircle(Offset(x, y), size, particlePaint);
    }

    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * math.pi * 2 + (progress * math.pi * -0.5);
      final distance = maxRadius * 0.6;
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);

      final innerOpacity =
          (math.sin(progress * math.pi * 4 + i * 1.5) * 0.08 + 0.1).clamp(
            0.0,
            0.18,
          );

      canvas.drawCircle(
        Offset(x, y),
        1.8,
        Paint()
          ..color = accentColor.withOpacity(innerOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SecurityIllustrationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
