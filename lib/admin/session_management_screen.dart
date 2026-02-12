import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/geometric_loader.dart';
import '../utils/custom_toast.dart';

class SessionManagementScreen extends StatefulWidget {
  const SessionManagementScreen({super.key});

  @override
  State<SessionManagementScreen> createState() =>
      _SessionManagementScreenState();
}

class _SessionManagementScreenState extends State<SessionManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  // Selection State
  String _selectedCourseId = 'ALL';
  String _selectedCourseName = 'All Courses (Global)';
  String _selectedSemester = 'ALL';
  int _currentCourseDuration = 0; // 0 means not applicable (Global)

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _createSession() async {
    if (_nameController.text.trim().isEmpty ||
        _startDate == null ||
        _endDate == null) {
      CustomToast.show(
        context,
        "Please fill all required fields",
        isError: true,
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      CustomToast.show(
        context,
        "End date cannot be before start date",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Deactivate old active sessions
      final activeSessions = await _firestore
          .collection('academic_sessions')
          .where('status', isEqualTo: 'Active')
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in activeSessions.docs) {
        batch.update(doc.reference, {'status': 'Inactive'});
      }

      DocumentReference newSession = _firestore
          .collection('academic_sessions')
          .doc();

      String targetDescription;
      if (_selectedCourseId == 'ALL') {
        targetDescription = "Global Session (All Courses)";
      } else {
        targetDescription = _selectedSemester == 'ALL'
            ? "$_selectedCourseName • All Semesters"
            : "$_selectedCourseName • Semester $_selectedSemester";
      }

      batch.set(newSession, {
        'sessionName': _nameController.text.trim(),
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'courseId': _selectedCourseId,
        'courseName': _selectedCourseName,
        'targetSemester': _selectedSemester,
        'description': targetDescription,
        'status': 'Active',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _nameController.clear();
      setState(() {
        _startDate = null;
        _endDate = null;
        _selectedCourseId = 'ALL';
        _selectedCourseName = 'All Courses (Global)';
        _selectedSemester = 'ALL';
      });

      if (mounted) Navigator.pop(context);
      CustomToast.show(context, "Session Activated Successfully!");
    } catch (e) {
      CustomToast.show(context, "Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SELECTION SHEETS (Replaces Dropdowns) ---

  void _showCourseSelector(StateSetter setSheetState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Select Course",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('courses').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final courses = snapshot.data!.docs;

                return Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Global Option
                      _buildSelectionItem(
                        title: "All Courses (Global)",
                        isSelected: _selectedCourseId == 'ALL',
                        onTap: () {
                          setSheetState(() {
                            _selectedCourseId = 'ALL';
                            _selectedCourseName = 'All Courses (Global)';
                            _currentCourseDuration = 0;
                            _selectedSemester = 'ALL'; // Reset sem
                          });
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(height: 1),
                      // Dynamic Courses
                      ...courses.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildSelectionItem(
                          title: data['name'],
                          subtitle: "${data['durationYears']} Years Duration",
                          isSelected: _selectedCourseId == doc.id,
                          onTap: () {
                            setSheetState(() {
                              _selectedCourseId = doc.id;
                              _selectedCourseName = data['name'];
                              _currentCourseDuration = data['durationYears'];
                              _selectedSemester = 'ALL'; // Reset sem
                            });
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSemesterSelector(StateSetter setSheetState) {
    if (_selectedCourseId == 'ALL') {
      CustomToast.show(
        context,
        "Select a specific course to filter by semester",
        isError: true,
      );
      return;
    }

    final int maxSemesters = _currentCourseDuration * 2;
    final List<String> semesterOptions = ['ALL'];
    for (int i = 1; i <= maxSemesters; i++) {
      semesterOptions.add(i.toString());
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Select Semester",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: semesterOptions.length,
                itemBuilder: (context, index) {
                  final sem = semesterOptions[index];
                  final label = sem == 'ALL'
                      ? "All Semesters"
                      : "Semester $sem";
                  return _buildSelectionItem(
                    title: label,
                    isSelected: _selectedSemester == sem,
                    onTap: () {
                      setSheetState(() => _selectedSemester = sem);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionItem({
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: isSelected
            ? Theme.of(context).primaryColor.withOpacity(0.05)
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.black87,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  void _showAddSessionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "New Academic Session",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Define the active period for attendance.",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 32),

              // Name Input
              TextField(
                controller: _nameController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "Session Name",
                  hintText: "e.g. Even Sem 2026",
                  prefixIcon: const Icon(Icons.edit_calendar_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                ),
              ),
              const SizedBox(height: 16),

              // Date Pickers
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await _selectDate(context, true);
                        setSheetState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 20,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _startDate == null
                                  ? "Start Date"
                                  : DateFormat('dd MMM').format(_startDate!),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _startDate == null
                                    ? Colors.grey
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await _selectDate(context, false);
                        setSheetState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_rounded,
                              size: 20,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _endDate == null
                                  ? "End Date"
                                  : DateFormat('dd MMM').format(_endDate!),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _endDate == null
                                    ? Colors.grey
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              const Text(
                "Applicability",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),

              // Custom Course Selector
              GestureDetector(
                onTap: () => _showCourseSelector(setSheetState),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        color: Colors.grey[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedCourseName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Custom Semester Selector
              Opacity(
                opacity: _selectedCourseId == 'ALL' ? 0.5 : 1.0,
                child: GestureDetector(
                  onTap: _selectedCourseId == 'ALL'
                      ? null
                      : () => _showSemesterSelector(setSheetState),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.layers_outlined,
                          color: Colors.grey[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedCourseId == 'ALL'
                                ? "All Semesters (Global)"
                                : (_selectedSemester == 'ALL'
                                      ? "All Semesters"
                                      : "Semester $_selectedSemester"),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (_selectedCourseId != 'ALL')
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? GeometricLoader(
                          size: 24,
                          isDarkMode:
                              Theme.of(context).brightness == Brightness.dark,
                        )
                      : const Text(
                          "Activate Session",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
          "Academic Sessions",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding > 0 ? 0 : 20),
        child: FloatingActionButton.extended(
          onPressed: _showAddSessionSheet,
          backgroundColor: theme.primaryColor,
          elevation: 2,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            "New Session",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('academic_sessions')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: GeometricLoader(size: 40, isDarkMode: false));
          }

          final sessions = snapshot.data!.docs;

          if (sessions.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding + 100),
            physics: const BouncingScrollPhysics(),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final data = sessions[index];
              final bool isActive = data['status'] == 'Active';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: isActive
                      ? Border.all(color: theme.primaryColor, width: 2)
                      : Border.all(color: Colors.transparent),
                  boxShadow: [
                    BoxShadow(
                      color: isActive
                          ? theme.primaryColor.withOpacity(0.15)
                          : Colors.black.withOpacity(0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isActive
                                ? theme.primaryColor.withOpacity(0.1)
                                : Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isActive
                                ? Icons.verified_rounded
                                : Icons.history_rounded,
                            color: isActive
                                ? theme.primaryColor
                                : Colors.grey[400],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['sessionName'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.date_range_rounded,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${DateFormat('MMM yy').format(data['startDate'].toDate())} - ${DateFormat('MMM yy').format(data['endDate'].toDate())}",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
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
                            color: isActive
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isActive ? "ACTIVE" : "ENDED",
                            style: TextStyle(
                              color: isActive ? Colors.green : Colors.grey[500],
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.hub_outlined,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              data['description'] ??
                                  (data['courseId'] == 'ALL'
                                      ? "Global Session"
                                      : "Specific Course Session"),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                size: 60,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Academic Sessions",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Create a session to start tracking\nattendance and activities.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
