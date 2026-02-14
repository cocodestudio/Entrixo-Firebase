import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminStatsGrid extends StatelessWidget {
  final ThemeData theme;
  const AdminStatsGrid({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return StreamBuilder<List<QuerySnapshot>>(
      stream: _getCombinedStreams(todayKey),
      builder: (context, snapshot) {
        String totalStudents = "...";
        String activeLabs = "...";
        String presentToday = "...";
        String absentToday = "...";

        if (snapshot.hasData && snapshot.data!.length == 3) {
          final studentsSnap = snapshot.data![0];
          final attendanceSnap = snapshot.data![1];
          final subjectsSnap = snapshot.data![2];

          totalStudents = studentsSnap.size.toString();

          int present = 0;
          int absent = 0;
          for (var doc in attendanceSnap.docs) {
            final status = doc['status'];
            if (status == 'Present') present++;
            if (status == 'Absent') absent++;
          }
          presentToday = present.toString();
          absentToday = absent.toString();

          int activeCount = 0;
          final now = DateTime.now();
          for (var doc in subjectsSnap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final schedule = data['schedule'] as List? ?? [];

            for (var session in schedule) {
              try {
                if (session['date'] is Timestamp) {
                  final date = (session['date'] as Timestamp).toDate();
                  if (date.year == now.year &&
                      date.month == now.month &&
                      date.day == now.day) {
                    final sParts = session['startTime'].toString().split(':');
                    final eParts = session['endTime'].toString().split(':');
                    final start = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      int.parse(sParts[0]),
                      int.parse(sParts[1]),
                    );
                    final end = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      int.parse(eParts[0]),
                      int.parse(eParts[1]),
                    );

                    if (now.isAfter(start) && now.isBefore(end)) {
                      activeCount++;
                    }
                  }
                }
              } catch (e) {}
            }
          }
          activeLabs = activeCount.toString();
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: [
            _buildStatCard(
              theme,
              'Total Students',
              totalStudents,
              Icons.people_outline,
              theme.primaryColor,
            ),
            _buildStatCard(
              theme,
              'Active Labs',
              activeLabs,
              Icons.computer_outlined,
              const Color(0xFF6366F1),
            ),
            _buildStatCard(
              theme,
              'Present Today',
              presentToday,
              Icons.check_circle_outline,
              const Color(0xFF00D26A),
            ),
            _buildStatCard(
              theme,
              'Absent Today',
              absentToday,
              Icons.cancel_outlined,
              const Color(0xFFFF4B4B),
            ),
          ],
        );
      },
    );
  }

  Stream<List<QuerySnapshot>> _getCombinedStreams(String todayKey) {
    final firestore = FirebaseFirestore.instance;

    return Stream.multi((controller) {
      List<QuerySnapshot?> latestData = [null, null, null];
      int updateCount = 0;

      void checkAndEmit() {
        if (latestData[0] != null &&
            latestData[1] != null &&
            latestData[2] != null) {
          controller.add(latestData.cast<QuerySnapshot>());
        }
      }

      final s1 = firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .snapshots()
          .listen((snap) {
            latestData[0] = snap;
            checkAndEmit();
          });

      final s2 = firestore
          .collection('attendance')
          .where('dateKey', isEqualTo: todayKey)
          .snapshots()
          .listen((snap) {
            latestData[1] = snap;
            checkAndEmit();
          });

      final s3 = firestore.collection('subjects').snapshots().listen((snap) {
        latestData[2] = snap;
        checkAndEmit();
      });

      controller.onCancel = () {
        s1.cancel();
        s2.cancel();
        s3.cancel();
      };
    });
  }

  Widget _buildStatCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ActiveLabsCarousel extends StatelessWidget {
  const ActiveLabsCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Active Labs Now",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              _buildLivePulseBadge(),
            ],
          ),
        ),
        SizedBox(
          height: 175,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('subjects')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildShimmerLoading();
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState("No labs running currently");
              }

              final now = DateTime.now();
              final activeSessions = <Map<String, dynamic>>[];

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final schedule = data['schedule'] as List? ?? [];

                for (var session in schedule) {
                  try {
                    if (session['date'] is Timestamp) {
                      final date = (session['date'] as Timestamp).toDate();

                      if (date.year == now.year &&
                          date.month == now.month &&
                          date.day == now.day) {
                        final sParts = session['startTime'].toString().split(
                          ':',
                        );
                        final eParts = session['endTime'].toString().split(':');

                        final start = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          int.parse(sParts[0]),
                          int.parse(sParts[1]),
                        );
                        final end = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          int.parse(eParts[0]),
                          int.parse(eParts[1]),
                        );

                        if (now.isAfter(start) && now.isBefore(end)) {
                          activeSessions.add({
                            'name': data['name'] ?? 'Unknown Lab',
                            'code': data['code'] ?? '---',
                            'courseId': data['courseId'] ?? '',
                            'semester': data['semester'] ?? 1,
                            'createdBy': data['createdBy'] ?? '',
                            'teacherFallback': data['teacherName'] ?? 'Faculty',
                            'time':
                                "${session['startTime']} - ${session['endTime']}",
                          });
                        }
                      }
                    }
                  } catch (e) {
                    continue;
                  }
                }
              }

              if (activeSessions.isEmpty) {
                return _buildEmptyState("No labs running currently");
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: activeSessions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  return _ActiveLabCard(session: activeSessions[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLivePulseBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4B4B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF4B4B).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFF4B4B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFFF4B4B),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            "LIVE NOW",
            style: TextStyle(
              color: Color(0xFFFF4B4B),
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.access_time_filled_rounded,
            color: Colors.grey[300],
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            msg,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (_, __) => Container(
        width: 280,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

class _ActiveLabCard extends StatelessWidget {
  final Map<String, dynamic> session;

  const _ActiveLabCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait([
        if (session['courseId'].toString().isNotEmpty)
          FirebaseFirestore.instance
              .collection('courses')
              .doc(session['courseId'])
              .get()
        else
          Future.value(null),
        if (session['createdBy'].toString().isNotEmpty)
          FirebaseFirestore.instance
              .collection('users')
              .doc(session['createdBy'])
              .get()
        else
          Future.value(null),
      ]),
      builder: (context, snapshot) {
        String courseName = "Course";
        String facultyName = session['teacherFallback'] ?? "Faculty";

        if (snapshot.hasData) {
          final courseSnap = snapshot.data![0];
          final userSnap = snapshot.data![1];

          if (courseSnap != null && courseSnap.exists) {
            final data = courseSnap.data() as Map<String, dynamic>;
            courseName = data['name'] ?? "Course";
          }

          if (userSnap != null && userSnap.exists) {
            final data = userSnap.data() as Map<String, dynamic>;
            facultyName = data['name'] ?? facultyName;
          }
        }

        return Container(
          width: 290,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF203A43).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(4, 8),
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
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Sem ${session['semester']}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D26A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Running",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session['name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              facultyName.isNotEmpty
                                  ? facultyName[0].toUpperCase()
                                  : "F",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Faculty",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 9,
                                  ),
                                ),
                                Text(
                                  facultyName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_filled_rounded,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          session['time'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AbsentAlertsList extends StatelessWidget {
  const AbsentAlertsList({super.key});

  @override
  Widget build(BuildContext context) {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Critical Alerts",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4B4B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFF4B4B),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      "Action Needed",
                      style: TextStyle(
                        color: Color(0xFFFF4B4B),
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .where('dateKey', isEqualTo: todayKey)
              .where('status', isEqualTo: 'Absent')
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00D26A).withOpacity(0.1),
                      const Color(0xFF00D26A).withOpacity(0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF00D26A).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D26A).withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF00D26A),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "All Clear!",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "100% Attendance recorded so far today.",
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final data =
                    snapshot.data!.docs[index].data() as Map<String, dynamic>;
                final uid = data['uid'];

                return FutureBuilder<List<dynamic>>(
                  future: Future.wait([
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .get(),
                    FirebaseFirestore.instance
                        .collection('attendance')
                        .where('uid', isEqualTo: uid)
                        .get(),
                  ]),
                  builder: (context, asyncSnapshot) {
                    String name = "Unknown Student";
                    String roll = "---";
                    String? imgUrl;
                    double percentage = 0.0;

                    if (asyncSnapshot.hasData) {
                      final userDoc =
                          asyncSnapshot.data![0] as DocumentSnapshot;
                      final attendanceDocs =
                          asyncSnapshot.data![1] as QuerySnapshot;

                      if (userDoc.exists) {
                        final userData = userDoc.data() as Map<String, dynamic>;
                        name = userData['name'] ?? name;
                        roll = userData['rollNumber'] ?? roll;
                        imgUrl = userData['profileUrl'];
                      }

                      if (attendanceDocs.docs.isNotEmpty) {
                        final total = attendanceDocs.docs.length;
                        final present = attendanceDocs.docs
                            .where((doc) => doc['status'] == 'Present')
                            .length;
                        percentage = (present / total) * 100;
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(16),
                              image: (imgUrl != null && imgUrl.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(imgUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (imgUrl == null || imgUrl.isEmpty)
                                ? Icon(Icons.person, color: Colors.grey[400])
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        roll,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: percentage < 60
                                      ? const Color(0xFFFF4B4B).withOpacity(0.1)
                                      : percentage < 75
                                      ? const Color(0xFFF59E0B).withOpacity(0.1)
                                      : const Color(
                                          0xFF10B981,
                                        ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "${percentage.toStringAsFixed(0)}%",
                                  style: TextStyle(
                                    color: percentage < 60
                                        ? const Color(0xFFFF4B4B)
                                        : percentage < 75
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF10B981),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Overall",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
