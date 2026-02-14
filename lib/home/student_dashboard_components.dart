import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import '../screens/attendance_screen.dart';
import '../screens/student_scanner_screen.dart';
import 'dart:async';

class DashboardState {
  final bool isLoading;
  final String userName;
  final double attendancePercentage;
  final int totalLabs;
  final int attendedLabs;
  final int absentLabs;
  final List<Map<String, dynamic>> upcomingSessions;

  DashboardState({
    required this.isLoading,
    required this.userName,
    required this.attendancePercentage,
    required this.totalLabs,
    required this.attendedLabs,
    required this.absentLabs,
    this.upcomingSessions = const [],
  });

  DashboardState copyWith({
    bool? isLoading,
    String? userName,
    double? attendancePercentage,
    int? totalLabs,
    int? attendedLabs,
    int? absentLabs,
    List<Map<String, dynamic>>? upcomingSessions,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      userName: userName ?? this.userName,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
      totalLabs: totalLabs ?? this.totalLabs,
      attendedLabs: attendedLabs ?? this.attendedLabs,
      absentLabs: absentLabs ?? this.absentLabs,
      upcomingSessions: upcomingSessions ?? this.upcomingSessions,
    );
  }
}

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>((ref) {
      return DashboardController();
    });

class DashboardController extends StateNotifier<DashboardState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _attendanceSubscription;

  DashboardController()
    : super(
        DashboardState(
          isLoading: true,
          userName: 'Student',
          attendancePercentage: 0.0,
          totalLabs: 0,
          attendedLabs: 0,
          absentLabs: 0,
          upcomingSessions: [],
        ),
      ) {
    _initData();
  }

  Future<void> _initData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null) return;

      final String name = userData['name'] ?? 'Student';
      final String courseId = userData['courseId'];
      final int semester = userData['currentSemester'] ?? 1;

      final activeSessionQuery = await _firestore
          .collection('academic_sessions')
          .where('status', isEqualTo: 'Active')
          .limit(1)
          .get();

      if (activeSessionQuery.docs.isEmpty) {
        if (mounted) state = state.copyWith(isLoading: false, userName: name);
        return;
      }
      final String sessionId = activeSessionQuery.docs.first.id;

      _attendanceSubscription?.cancel();
      _attendanceSubscription = _firestore
          .collection('attendance')
          .where('uid', isEqualTo: user.uid)
          .snapshots()
          .listen((snapshot) async {
            await _updateDashboardStats(
              snapshot,
              name,
              courseId,
              semester,
              sessionId,
            );
          });
    } catch (e) {
      debugPrint("Dashboard Error: $e");
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _updateDashboardStats(
    QuerySnapshot attSnapshot,
    String name,
    String courseId,
    int semester,
    String sessionId,
  ) async {
    final subjectsQuery = await _firestore
        .collection('subjects')
        .where('courseId', isEqualTo: courseId)
        .where('semester', isEqualTo: semester)
        .where('sessionId', isEqualTo: sessionId)
        .get();

    int totalHappened = 0;
    int totalPresent = 0;
    List<Map<String, dynamic>> allFutureSessions = [];
    DateTime now = DateTime.now();

    final Set<String> presentKeys = {};
    for (var doc in attSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['status'] == 'Present' && data['dateKey'] != null) {
        presentKeys.add("${data['subjectId']}_${data['dateKey']}");
      }
    }

    for (var subDoc in subjectsQuery.docs) {
      final subData = subDoc.data();
      final String subjectId = subDoc.id;
      final List schedule = subData['schedule'] ?? [];

      for (var session in schedule) {
        if (session['date'] is! Timestamp) continue;

        final DateTime sessionDate = (session['date'] as Timestamp).toDate();
        final String dateKey = DateFormat('yyyy-MM-dd').format(sessionDate);
        final String startTimeStr = session['startTime'];
        final String endTimeStr = session['endTime'];

        DateTime fullStart;
        DateTime fullEnd;
        try {
          final sParts = startTimeStr.split(':');
          final eParts = endTimeStr.split(':');
          fullStart = DateTime(
            sessionDate.year,
            sessionDate.month,
            sessionDate.day,
            int.parse(sParts[0]),
            int.parse(sParts[1]),
          );
          fullEnd = DateTime(
            sessionDate.year,
            sessionDate.month,
            sessionDate.day,
            int.parse(eParts[0]),
            int.parse(eParts[1]),
          );
        } catch (e) {
          fullStart = sessionDate;
          fullEnd = sessionDate.add(const Duration(hours: 2));
        }

        if (now.isAfter(fullEnd)) {
          final sessionActiveCheck = await _firestore
              .collection('attendance')
              .where('subjectId', isEqualTo: subjectId)
              .where('dateKey', isEqualTo: dateKey)
              .limit(1)
              .get();

          if (sessionActiveCheck.docs.isNotEmpty) {
            totalHappened++;
            if (presentKeys.contains("${subjectId}_$dateKey")) {
              totalPresent++;
            }
          }
        } else if (now.isAfter(fullStart) && now.isBefore(fullEnd)) {
          if (presentKeys.contains("${subjectId}_$dateKey")) {
            totalHappened++;
            totalPresent++;
          }
        } else {
          allFutureSessions.add({
            'subject': subData['name'],
            'code': subData['code'],
            'time': "$startTimeStr - $endTimeStr",
            'rawDateTime': fullStart,
            'displayDate': DateFormat('EEE, dd MMM').format(sessionDate),
            'isToday': DateUtils.isSameDay(sessionDate, now),
            'room': 'Lab',
          });
        }
      }
    }

    allFutureSessions.sort(
      (a, b) => a['rawDateTime'].compareTo(b['rawDateTime']),
    );
    final List<Map<String, dynamic>> top3Sessions = allFutureSessions
        .take(3)
        .toList();

    int absent = totalHappened - totalPresent;
    double percentage = totalHappened == 0
        ? 0.0
        : (totalPresent / totalHappened);

    if (mounted) {
      state = state.copyWith(
        isLoading: false,
        userName: name,
        totalLabs: totalHappened,
        attendedLabs: totalPresent,
        absentLabs: absent < 0 ? 0 : absent,
        attendancePercentage: percentage,
        upcomingSessions: top3Sessions,
      );
    }
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }
}

// --- 4. MAIN DASHBOARD UI ---
class StudentDashboardContent extends ConsumerWidget {
  final ThemeData theme;
  final Size size;

  const StudentDashboardContent({
    super.key,
    required this.theme,
    required this.size,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            StatsGlassCard(
              theme: theme,
              percentage: state.attendancePercentage,
              total: state.totalLabs,
              present: state.attendedLabs,
              absent: state.absentLabs,
            ),
            const SizedBox(height: 32),
            PrimaryActionButton(theme: theme),
            const SizedBox(height: 32),
            QuickActionsSection(theme: theme),
            const SizedBox(height: 32),

            NextSessionSection(theme: theme, sessions: state.upcomingSessions),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class NextSessionSection extends StatelessWidget {
  final ThemeData theme;
  final List<Map<String, dynamic>> sessions;

  const NextSessionSection({
    super.key,
    required this.theme,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Sessions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${sessions.length} Pending",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 155,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final bool isToday = session['isToday'] ?? false;

              return Container(
                width: 280,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(5, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF10B981)
                                : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isToday ? "TODAY" : session['displayDate'],
                            style: TextStyle(
                              color: isToday ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ],
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['subject'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session['code'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.access_time_filled_rounded,
                          session['time'],
                        ),
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          Icons.location_on_rounded,
                          session['room'],
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
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 40,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            "No Upcoming Classes",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "You're all caught up for the next 3 days!",
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class LiveAttendanceCard extends ConsumerWidget {
  final ThemeData theme;

  const LiveAttendanceCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(attendanceProvider);

    return attendanceAsync.when(
      data: (data) {
        final int absent = data.totalClasses - data.totalPresent;
        return StatsGlassCard(
          theme: theme,
          percentage: data.overallPercentage,
          total: data.totalClasses,
          present: data.totalPresent,
          absent: absent < 0 ? 0 : absent,
        );
      },
      loading: () => _buildLoadingState(theme),
      error: (err, stack) => StatsGlassCard(
        theme: theme,
        percentage: 0.0,
        total: 0,
        present: 0,
        absent: 0,
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class StatsGlassCard extends StatelessWidget {
  final ThemeData theme;
  final double percentage;
  final int total;
  final int present;
  final int absent;

  const StatsGlassCard({
    super.key,
    required this.theme,
    required this.percentage,
    required this.total,
    required this.present,
    required this.absent,
  });

  String _getMotivationalText(double p) {
    if (p >= 0.75) return "Excellent! You are doing great.";
    if (p >= 0.60) return "Good job! Keep maintaining it.";
    if (p >= 0.40) return "Warning! You need to attend more labs.";
    return "Critical! Your attendance is very low.";
  }

  Color _getColorForPercentage(double p) {
    if (p >= 0.75) return const Color(0xFF10B981);
    if (p >= 0.60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getColorForPercentage(percentage);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1.5,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.6),
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 85,
                      height: 85,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            painter: _ProgressRingPainter(
                              progress: percentage,
                              activeColor: statusColor,
                              backgroundColor: const Color(0xFFE5E7EB),
                            ),
                          ),
                          Center(
                            child: Text(
                              '${(percentage * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Overall Attendance',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getMotivationalText(percentage),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: statusColor.withOpacity(0.8),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF3F4F6)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatColumn(
                        label: 'Total',
                        value: total.toString(),
                        color: const Color(0xFF6366F1),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: const Color(0xFFE5E7EB),
                      ),
                      _StatColumn(
                        label: 'Present',
                        value: present.toString(),
                        color: const Color(0xFF10B981),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: const Color(0xFFE5E7EB),
                      ),
                      _StatColumn(
                        label: 'Absent',
                        value: absent.toString(),
                        color: const Color(0xFFEF4444),
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
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF9CA3AF),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color backgroundColor;

  _ProgressRingPainter({
    required this.progress,
    required this.activeColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 8.0;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -3.14159 / 2,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PrimaryActionButton extends StatelessWidget {
  final ThemeData theme;

  const PrimaryActionButton({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StudentScannerScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.primaryColor, const Color(0xFF4F46E5)],
          ),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.4),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 100,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Scan QR Attendance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActionsSection extends StatelessWidget {
  final ThemeData theme;

  const QuickActionsSection({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickActionItem(
              icon: Icons.calendar_month_rounded,
              label: 'Attendance',
              color: const Color(0xFF6366F1),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AttendanceScreen(),
                  ),
                );
              },
            ),
            _QuickActionItem(
              icon: Icons.assignment_rounded,
              label: 'Assignments',
              color: const Color(0xFFF59E0B),
              onTap: () {},
            ),
            _QuickActionItem(
              icon: Icons.menu_book_rounded,
              label: 'Resources',
              color: const Color(0xFF10B981),
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 48 - 32) / 3;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: width,
            height: width,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9CA3AF).withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: onTap,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}
