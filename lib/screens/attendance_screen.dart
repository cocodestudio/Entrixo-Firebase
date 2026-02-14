import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/geometric_loader.dart';

class AttendanceData {
  final List<Map<String, dynamic>> subjects;
  final double overallPercentage;
  final int totalClasses;
  final int totalPresent;

  AttendanceData({
    required this.subjects,
    required this.overallPercentage,
    required this.totalClasses,
    required this.totalPresent,
  });
}

final attendanceProvider = FutureProvider.autoDispose<AttendanceData>((
  ref,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception("User not logged in");

  final firestore = FirebaseFirestore.instance;
  final userDoc = await firestore.collection('users').doc(user.uid).get();
  final userData = userDoc.data();
  if (userData == null) throw Exception("User data not found");

  final String? courseId = userData['courseId'];
  final int? currentSemester = userData['currentSemester'];

  final activeSessionQuery = await firestore
      .collection('academic_sessions')
      .where('status', isEqualTo: 'Active')
      .limit(1)
      .get();

  if (activeSessionQuery.docs.isEmpty) {
    return AttendanceData(
      subjects: [],
      overallPercentage: 0,
      totalClasses: 0,
      totalPresent: 0,
    );
  }

  final String activeSessionId = activeSessionQuery.docs.first.id;

  final subjectsQuery = await firestore
      .collection('subjects')
      .where('courseId', isEqualTo: courseId)
      .where('semester', isEqualTo: currentSemester)
      .where('sessionId', isEqualTo: activeSessionId)
      .orderBy('code')
      .get();

  List<Map<String, dynamic>> finalSubjects = [];
  int globalTotal = 0;
  int globalPresent = 0;

  for (var doc in subjectsQuery.docs) {
    final data = doc.data();
    final subjectId = doc.id;

    String facultyName = "Faculty";
    if (data['createdBy'] != null && data['createdBy'].toString().isNotEmpty) {
      try {
        final facultyDoc = await firestore
            .collection('users')
            .doc(data['createdBy'])
            .get();
        facultyName = facultyDoc.data()?['name'] ?? "Admin";
      } catch (e) {
        facultyName = "Admin";
      }
    }

    // Student's own attendance for this subject
    final attendanceQuery = await firestore
        .collection('attendance')
        .where('uid', isEqualTo: user.uid)
        .where('subjectId', isEqualTo: subjectId)
        .get();

    Map<String, String> attendanceMap = {};
    for (var att in attendanceQuery.docs) {
      final date = (att['timestamp'] as Timestamp).toDate();
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      attendanceMap[dateKey] = att['status'] ?? 'Present';
    }

    final List rawSchedule = data['schedule'] ?? [];
    List<Map<String, dynamic>> fullSessionHistory = [];
    int subjectTotal = 0;
    int subjectPresent = 0;

    for (var session in rawSchedule) {
      if (session['date'] is! Timestamp) continue;
      DateTime sessionDate = (session['date'] as Timestamp).toDate();
      final dateKey = DateFormat('yyyy-MM-dd').format(sessionDate);
      final endParts = session['endTime'].split(':');
      final DateTime sessionEndFull = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      );

      String status = "Upcoming";

      if (attendanceMap.containsKey(dateKey)) {
        status = attendanceMap[dateKey]!;
      } else if (DateTime.now().isAfter(sessionEndFull)) {
        // --- OPTION 3: PEER CHECK LOGIC ---
        // Check if ANYONE in the class marked attendance for this session
        final globalCheck = await firestore
            .collection('attendance')
            .where('subjectId', isEqualTo: subjectId)
            .where('dateKey', isEqualTo: dateKey)
            .limit(1)
            .get();

        if (globalCheck.docs.isNotEmpty) {
          status = "Absent"; // Lab hui thi, par tumne mark nahi ki
        } else {
          status = "Not Marked"; // Lab hi nahi hui (Teacher absent)
        }
      }

      if (status == 'Present') subjectPresent++;
      // Stats mein sirf tabhi gino jab session actually Conduct hua ho (Present or Absent)
      if (status == 'Present' || status == 'Absent') subjectTotal++;

      fullSessionHistory.add({
        'date': sessionDate,
        'startTime': session['startTime'],
        'endTime': session['endTime'],
        'status': status,
        'topic': "Lab Session",
      });
    }

    fullSessionHistory.sort((a, b) => a['date'].compareTo(b['date']));
    globalTotal += subjectTotal;
    globalPresent += subjectPresent;

    finalSubjects.add({
      'id': subjectId,
      'name': data['name'] ?? 'Unknown Subject',
      'code': data['code'] ?? '---',
      'faculty': facultyName,
      'total': subjectTotal,
      'attended': subjectPresent,
      'sessions': fullSessionHistory,
    });
  }

  double overall = globalTotal == 0 ? 0.0 : (globalPresent / globalTotal);
  return AttendanceData(
    subjects: finalSubjects,
    overallPercentage: overall,
    totalClasses: globalTotal,
    totalPresent: globalPresent,
  );
});

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final attendanceAsync = ref.watch(attendanceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Attendance",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: attendanceAsync.when(
        loading: () =>
            Center(child: GeometricLoader(size: 50, isDarkMode: isDarkMode)),
        error: (err, stack) => Center(child: Text('Error loading data')),
        data: (data) {
          if (data.subjects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 60,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No subjects found for this session",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _OverallStatsCard(
                    percentage: data.overallPercentage,
                    total: data.totalClasses,
                    present: data.totalPresent,
                    theme: theme,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final subject = data.subjects[index];
                    return _SubjectCard(theme: theme, data: subject);
                  }, childCount: data.subjects.length),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}

class _OverallStatsCard extends StatelessWidget {
  final double percentage;
  final int total;
  final int present;
  final ThemeData theme;

  const _OverallStatsCard({
    required this.percentage,
    required this.total,
    required this.present,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF1A1A1A), const Color(0xFF2C2C2C)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  color: _getColor(percentage),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    "${(percentage * 100).toInt()}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
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
                const Text(
                  "Overall Attendance",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Total Classes: $total",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  "Present: $present",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(double p) {
    if (p >= 0.75) return const Color(0xFF10B981);
    if (p >= 0.60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class _SubjectCard extends StatelessWidget {
  final ThemeData theme;
  final Map<String, dynamic> data;

  const _SubjectCard({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    final double percentage = data['total'] == 0
        ? 0.0
        : data['attended'] / data['total'];
    final int percentInt = (percentage * 100).toInt();
    final Color statusColor = _getColor(percentage);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectDetailScreen(data: data, theme: theme),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        data['code'].split('-').last,
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'title_${data['id']}',
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              data['name'],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['faculty'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$percentInt%",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniStat(label: 'Total', value: '${data['total']}'),
                  _MiniStat(
                    label: 'Present',
                    value: '${data['attended']}',
                    color: const Color(0xFF10B981),
                  ),
                  _MiniStat(
                    label: 'Absent',
                    value: '${data['total'] - data['attended']}',
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColor(double p) {
    if (p >= 0.75) return const Color(0xFF10B981);
    if (p >= 0.60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

// --- DETAIL SCREEN ---

class SubjectDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final ThemeData theme;

  const SubjectDetailScreen({
    super.key,
    required this.data,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final List sessions = data['sessions'] ?? [];
    final double percentage = data['total'] == 0
        ? 0.0
        : data['attended'] / data['total'];
    final int percentInt = (percentage * 100).toInt();

    // Status colors logic
    Color getStatusColor(String status) {
      if (status == 'Present') return const Color(0xFF10B981);
      if (status == 'Absent') return const Color(0xFFEF4444);
      if (status == 'Upcoming') return Colors.blue;
      return Colors.orange; // Not Marked
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFF7F8FA),
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.black,
                  size: 18,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.primaryColor.withOpacity(0.05),
                      const Color(0xFFF7F8FA),
                    ],
                  ),
                ),
                child: Center(
                  child: Hero(
                    tag: 'progress_${data['id']}',
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: percentage,
                            strokeWidth: 8,
                            backgroundColor: Colors.white,
                            color: const Color(
                              0xFF1A1A1A,
                            ), // Black color for progress
                            strokeCap: StrokeCap.round,
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$percentInt%',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(
                                      0xFF1A1A1A,
                                    ), // Black color text
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const Text(
                                  "Attendance",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.black,
                                    decoration: TextDecoration.none,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Hero(
                    tag: 'title_${data['id']}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        data['name'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Text(
                      "${data['code']} • ${data['faculty']}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      "Session History",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          if (sessions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text("No schedule found")),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final session = sessions[index];
                  final String status = session['status'];
                  final DateTime dateObj = session['date'];

                  final date = DateFormat('dd MMM').format(dateObj);
                  final day = DateFormat('EEE').format(dateObj);

                  final color = getStatusColor(status);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              Text(
                                day,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: color.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session['topic'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${session['startTime']} - ${session['endTime']}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }, childCount: sessions.length),
              ),
            ),
        ],
      ),
    );
  }
}
