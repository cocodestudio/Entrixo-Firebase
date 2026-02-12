import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/legacy.dart';

class DashboardState {
  final bool isLoading;
  final String error;
  final String userName;
  final double attendancePercentage;
  final int totalLabs;
  final int attendedLabs;
  final List<Map<String, dynamic>> recentLabs;

  DashboardState({
    required this.isLoading,
    required this.error,
    required this.userName,
    required this.attendancePercentage,
    required this.totalLabs,
    required this.attendedLabs,
    required this.recentLabs,
  });

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    String? userName,
    double? attendancePercentage,
    int? totalLabs,
    int? attendedLabs,
    List<Map<String, dynamic>>? recentLabs,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      userName: userName ?? this.userName,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
      totalLabs: totalLabs ?? this.totalLabs,
      attendedLabs: attendedLabs ?? this.attendedLabs,
      recentLabs: recentLabs ?? this.recentLabs,
    );
  }
}

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>((ref) {
      return DashboardController(
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
      );
    });

class DashboardController extends StateNotifier<DashboardState> {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  DashboardController({required this.auth, required this.firestore})
    : super(
        DashboardState(
          isLoading: true,
          error: '',
          userName: 'Loading...',
          attendancePercentage: 0.0,
          totalLabs: 0,
          attendedLabs: 0,
          recentLabs: [],
        ),
      ) {
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    try {
      final user = auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final String name = userData != null && userData.containsKey('name')
          ? userData['name']
          : 'Student';

      final attendanceQuery = await firestore
          .collection('attendance')
          .where('uid', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      int total = 42;
      int attended = attendanceQuery.docs.length;

      List<Map<String, dynamic>> recent = attendanceQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'subject': data['subject'] ?? 'Lab Session',
          'room': data['room'] ?? 'Lab',
          'date': _formatDate((data['timestamp'] as Timestamp).toDate()),
          'status': data['status'] ?? 'Present',
        };
      }).toList();

      if (recent.isEmpty) {
        recent = [
          {
            'subject': 'Advanced Database Systems',
            'room': 'Lab 402',
            'date': 'Today, 10:30 AM',
            'status': 'Present',
          },
          {
            'subject': 'Artificial Intelligence',
            'room': 'Lab 301',
            'date': 'Yesterday, 02:00 PM',
            'status': 'Present',
          },
          {
            'subject': 'Computer Networks',
            'room': 'Lab 105',
            'date': '10 Feb, 09:00 AM',
            'status': 'Absent',
          },
        ];
        attended = 36;
      }

      double percentage = total == 0 ? 0.0 : (attended / total);

      state = state.copyWith(
        isLoading: false,
        userName: name,
        totalLabs: total,
        attendedLabs: attended,
        attendancePercentage: percentage,
        recentLabs: recent,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }
}
