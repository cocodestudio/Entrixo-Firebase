import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../screens/profile_screen.dart';

class DashboardHeader extends SliverPersistentHeaderDelegate {
  final String userName;
  final String? userImage;
  final double topPadding;

  DashboardHeader({
    required this.userName,
    this.userImage,
    required this.topPadding,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final percent = math.min(shrinkOffset / (maxExtent - minExtent), 1.0);

    final double nameSize = lerpDouble(24, 18, percent)!;
    final double avatarSize = 54.0;
    final double currentRadius = lerpDouble(32, 0, percent)!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(currentRadius),
          bottomRight: Radius.circular(currentRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(currentRadius),
          bottomRight: Radius.circular(currentRadius),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.primaryColor.withOpacity(0.06),
                    theme.primaryColor.withOpacity(0.10),
                    theme.colorScheme.secondary.withOpacity(0.05),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              top: lerpDouble(-50, -120, percent)!,
              right: lerpDouble(-40, -100, percent)!,
              child: Transform.scale(
                scale: lerpDouble(1.0, 0.7, percent)!,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.primaryColor.withOpacity(0.15),
                        theme.primaryColor.withOpacity(0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: lerpDouble(80, 20, percent)!,
              left: lerpDouble(-70, -120, percent)!,
              child: Transform.scale(
                scale: lerpDouble(1.0, 0.6, percent)!,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.secondary.withOpacity(0.12),
                        theme.colorScheme.secondary.withOpacity(0.04),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: lerpDouble(-80, -140, percent)!,
              right: lerpDouble(30, -20, percent)!,
              child: Transform.rotate(
                angle: percent * 0.6,
                child: Transform.scale(
                  scale: lerpDouble(1.0, 0.5, percent)!,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.primaryColor.withOpacity(0.08),
                          theme.primaryColor.withOpacity(0.03),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: lerpDouble(120, 50, percent)!,
              right: lerpDouble(50, 20, percent)!,
              child: Transform.rotate(
                angle: -percent * 0.4,
                child: Opacity(
                  opacity: lerpDouble(1.0, 0.0, percent)!,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.secondary.withOpacity(0.15),
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: lerpDouble(50, 10, percent)!,
              left: lerpDouble(60, 20, percent)!,
              child: Transform.rotate(
                angle: percent * 0.3,
                child: Opacity(
                  opacity: lerpDouble(0.8, 0.0, percent)!,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.secondary.withOpacity(0.1),
                          theme.colorScheme.secondary.withOpacity(0.03),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Scaffold.of(context).openDrawer();
                        },
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.primaryColor.withOpacity(0.2),
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    (userImage != null && userImage!.isNotEmpty)
                                        ? userImage!
                                        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}&background=6366F1&color=fff&size=128',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: theme.primaryColor.withOpacity(
                                          0.1,
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          color: theme.primaryColor,
                                          size: avatarSize * 0.5,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (percent < 0.5)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  'Welcome Back,',
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    color: theme.primaryColor.withOpacity(0.65),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFF1A1A1A),
                                fontSize: nameSize,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.95),
                          border: Border.all(
                            color: theme.primaryColor.withOpacity(0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {},
                            borderRadius: BorderRadius.circular(22),
                            child: Icon(
                              Icons.notifications_none_rounded,
                              color: theme.primaryColor.withOpacity(0.85),
                              size: 22,
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
      ),
    );
  }

  @override
  double get maxExtent => 150.0 + topPadding;

  @override
  double get minExtent => kToolbarHeight + topPadding;

  @override
  bool shouldRebuild(covariant DashboardHeader oldDelegate) =>
      userName != oldDelegate.userName || userImage != oldDelegate.userImage;
}

class StatsGlassCard extends StatelessWidget {
  final ThemeData theme;
  final Size size;

  const StatsGlassCard({super.key, required this.theme, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.5),
                ],
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: ProgressRingPainter(
                          progress: 0.85,
                          activeColor: theme.colorScheme.secondary,
                          backgroundColor: theme.colorScheme.secondary
                              .withOpacity(0.15),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '85%',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 22,
                                color: const Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Attendance',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF666666),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatColumn(
                            theme: theme,
                            label: 'Total',
                            value: '42',
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 20),
                          Container(
                            width: 1,
                            height: 30,
                            color: const Color(0xFFE5E7EB),
                          ),
                          const SizedBox(width: 20),
                          _StatColumn(
                            theme: theme,
                            label: 'Attended',
                            value: '36',
                            color: theme.colorScheme.secondary,
                          ),
                        ],
                      ),
                    ],
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

class _StatColumn extends StatelessWidget {
  final ThemeData theme;
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.theme,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 24,
            color: color,
            height: 1.1,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            color: const Color(0xFFAAAAAA),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class PrimaryActionButton extends StatelessWidget {
  final ThemeData theme;

  const PrimaryActionButton({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Scan QR for Attendance',
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecentActivitySection extends StatelessWidget {
  final ThemeData theme;

  const RecentActivitySection({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Labs',
              style: theme.textTheme.titleLarge?.copyWith(
                color: const Color(0xFF1A1A1A),
                fontSize: 20,
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.secondary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View All',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ActivityTile(
          theme: theme,
          subject: 'Advanced Database Systems',
          room: 'Lab 402',
          date: 'Today, 10:30 AM',
          status: 'Present',
          isRecent: true,
        ),
        const SizedBox(height: 12),
        ActivityTile(
          theme: theme,
          subject: 'Artificial Intelligence',
          room: 'Lab 301',
          date: 'Yesterday, 02:00 PM',
          status: 'Present',
          isRecent: false,
        ),
        const SizedBox(height: 12),
        ActivityTile(
          theme: theme,
          subject: 'Computer Networks',
          room: 'Lab 105',
          date: '10 Feb, 09:00 AM',
          status: 'Absent',
          isRecent: false,
        ),
      ],
    );
  }
}

class ActivityTile extends StatelessWidget {
  final ThemeData theme;
  final String subject;
  final String room;
  final String date;
  final String status;
  final bool isRecent;

  const ActivityTile({
    super.key,
    required this.theme,
    required this.subject,
    required this.room,
    required this.date,
    required this.status,
    required this.isRecent,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPresent = status == 'Present';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecent
              ? theme.primaryColor.withOpacity(0.2)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isRecent
                  ? theme.primaryColor.withOpacity(0.1)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.computer_rounded,
              color: isRecent ? theme.primaryColor : const Color(0xFF9CA3AF),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF1A1A1A),
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      room,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF666666),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD1D5DB),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF9CA3AF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isPresent
                  ? const Color(0xFF00D26A).withOpacity(0.1)
                  : const Color(0xFFFF4B4B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontFamily: 'Quicksand',
                color: isPresent
                    ? const Color(0xFF00D26A)
                    : const Color(0xFFFF4B4B),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color backgroundColor;

  ProgressRingPainter({
    required this.progress,
    required this.activeColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 6;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
