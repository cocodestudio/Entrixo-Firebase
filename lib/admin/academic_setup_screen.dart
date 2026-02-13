import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/custom_toast.dart';
import '../widgets/geometric_loader.dart';

class AcademicSetupScreen extends StatefulWidget {
  const AcademicSetupScreen({super.key});

  @override
  State<AcademicSetupScreen> createState() => _AcademicSetupScreenState();
}

class _AcademicSetupScreenState extends State<AcademicSetupScreen> {
  String? _selectedCourseId;
  String _selectedCourseName = '';
  int _selectedCourseDuration = 4;
  int _selectedSemester = 1;
  bool _isLoading = false;

  String? _viewingSessionId;
  String? _activeSessionId;
  String _viewingSessionName = "Loading...";

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _addCourse(String name, int years) async {
    if (name.trim().isEmpty) {
      _showSnack("Please enter a course name", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final existing = await _firestore
          .collection('courses')
          .where('name', isEqualTo: name.trim())
          .get();

      if (existing.docs.isNotEmpty) {
        throw "Course already exists!";
      }

      await _firestore.collection('courses').add({
        'name': name.trim(),
        'durationYears': years,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
      _showSnack("Course added successfully!");
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSubject(
    String name,
    String code,
    List<Map<String, dynamic>> schedule,
  ) async {
    if (name.trim().isEmpty || code.trim().isEmpty) {
      _showSnack("Please fill all fields", isError: true);
      return;
    }
    if (_selectedCourseId == null) {
      _showSnack("No course selected", isError: true);
      return;
    }
    if (_activeSessionId == null) {
      _showSnack("No Active Session Found!", isError: true);
      return;
    }
    if (schedule.isEmpty) {
      _showSnack("Please generate a schedule first", isError: true);
      return;
    }

    try {
      final existing = await _firestore
          .collection('subjects')
          .where('courseId', isEqualTo: _selectedCourseId)
          .where('code', isEqualTo: code.trim().toUpperCase())
          .where('sessionId', isEqualTo: _activeSessionId)
          .get();

      if (existing.docs.isNotEmpty) {
        throw "Subject code '${code.trim().toUpperCase()}' already exists in this session!";
      }

      await _firestore.collection('subjects').add({
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'courseId': _selectedCourseId,
        'semester': _selectedSemester,
        'sessionId': _activeSessionId,
        'schedule': schedule,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
      _showSnack("Lab & Schedule added successfully!");
    } catch (e) {
      _showSnack(e.toString(), isError: true);
      rethrow;
    }
  }

  Future<void> _deleteSubject(String subjectId) async {
    setState(() => _isLoading = true);
    try {
      await _firestore.collection('subjects').doc(subjectId).delete();
      _showSnack("Lab removed");
    } catch (e) {
      _showSnack("Failed to delete: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    CustomToast.show(context, msg, isError: isError);
  }

  void _showViewScheduleSheet(List<dynamic> schedule, String labName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            "${schedule.length} Active Sessions",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: schedule.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = schedule[index];
                    final DateTime date = (item['date'] as Timestamp).toDate();
                    final dateStr = "${date.day}/${date.month}/${date.year}";

                    const days = [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ];
                    final dayName = days[date.weekday - 1];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  dayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 12,
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
                                  dateStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 12,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${item['startTime']} - ${item['endTime']}",
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

  void _showSessionSelector(List<QueryDocumentSnapshot> sessions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Select Academic Session",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final data = sessions[index].data() as Map<String, dynamic>;
                  final id = sessions[index].id;
                  final isSelected = _viewingSessionId == id;
                  final isActive = data['status'] == 'Active';

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _viewingSessionId = id;
                        _viewingSessionName = data['sessionName'];
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.05)
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            isActive
                                ? Icons.verified_rounded
                                : Icons.history_rounded,
                            color: isActive ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              data['sessionName'],
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.black87,
                              ),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCourseSheet() {
    final TextEditingController nameController = TextEditingController();
    int selectedYears = 3;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
              const Text(
                "New Course Setup",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: nameController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "Course Name",
                  hintText: "e.g. B.Tech CS",
                  prefixIcon: const Icon(Icons.school_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Course Duration",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final years = index + 1;
                    final isSelected = selectedYears == years;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedYears = years),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "$years Years",
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[800],
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _addCourse(nameController.text, selectedYears),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? GeometricLoader(size: 24, isDarkMode: isDarkMode)
                      : const Text(
                          "Create Course",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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

  void _showAddSubjectSheet() {
    if (_selectedCourseId == null) {
      _showSnack("Please select a course first", isError: true);
      return;
    }

    final TextEditingController nameController = TextEditingController();
    final TextEditingController codeController = TextEditingController();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    DateTime? startDate;
    DateTime? endDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    List<int> selectedWeekdays = [];
    List<Map<String, dynamic>> generatedSchedule = [];

    bool isGenerating = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> generateSchedule() async {
            if (startDate == null ||
                endDate == null ||
                startTime == null ||
                endTime == null ||
                selectedWeekdays.isEmpty) {
              CustomToast.show(
                context,
                "Please select dates, time & weekdays",
                isError: true,
              );
              return;
            }

            if (endDate!.isBefore(startDate!)) {
              CustomToast.show(
                context,
                "End date cannot be before start date",
                isError: true,
              );
              return;
            }

            setSheetState(() => isGenerating = true);
            await Future.delayed(const Duration(milliseconds: 800));

            List<Map<String, dynamic>> tempSchedule = [];
            DateTime current = startDate!;

            while (current.isBefore(endDate!) ||
                current.isAtSameMomentAs(endDate!)) {
              if (selectedWeekdays.contains(current.weekday)) {
                tempSchedule.add({
                  'date': Timestamp.fromDate(current),
                  'startTime':
                      "${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}",
                  'endTime':
                      "${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}",
                });
              }
              current = current.add(const Duration(days: 1));
            }

            setSheetState(() {
              generatedSchedule = tempSchedule;
              isGenerating = false;
            });

            if (context.mounted) {
              CustomToast.show(
                context,
                "Generated ${tempSchedule.length} sessions!",
              );
            }
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 32,
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
            height: MediaQuery.of(context).size.height * 0.9,
            child: Column(
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
                const Text(
                  "Add New Lab",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 24),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: nameController,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: "Lab Name",
                            hintText: "e.g. Java Lab",
                            prefixIcon: const Icon(Icons.class_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF7F8FA),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: codeController,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: "Subject Code",
                            hintText: "e.g. CS-301",
                            prefixIcon: const Icon(Icons.qr_code_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF7F8FA),
                          ),
                        ),

                        const SizedBox(height: 32),
                        _buildSectionTitle("Schedule Generator"),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePickerBox(
                                context,
                                label: startDate == null
                                    ? "Start Date"
                                    : "${startDate!.day}/${startDate!.month}/${startDate!.year}",
                                icon: Icons.calendar_today_rounded,
                                isSelected: startDate != null,
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                  );
                                  if (picked != null)
                                    setSheetState(() => startDate = picked);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDatePickerBox(
                                context,
                                label: endDate == null
                                    ? "End Date"
                                    : "${endDate!.day}/${endDate!.month}/${endDate!.year}",
                                icon: Icons.event_rounded,
                                isSelected: endDate != null,
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: startDate ?? DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                  );
                                  if (picked != null)
                                    setSheetState(() => endDate = picked);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePickerBox(
                                context,
                                label: startTime == null
                                    ? "Start Time"
                                    : "${startTime!.hour}:${startTime!.minute.toString().padLeft(2, '0')}",
                                icon: Icons.schedule_rounded,
                                isSelected: startTime != null,
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: const TimeOfDay(
                                      hour: 9,
                                      minute: 0,
                                    ),
                                  );
                                  if (picked != null)
                                    setSheetState(() => startTime = picked);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDatePickerBox(
                                context,
                                label: endTime == null
                                    ? "End Time"
                                    : "${endTime!.hour}:${endTime!.minute.toString().padLeft(2, '0')}",
                                icon: Icons.schedule_rounded,
                                isSelected: endTime != null,
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime:
                                        startTime ??
                                        const TimeOfDay(hour: 10, minute: 0),
                                  );
                                  if (picked != null)
                                    setSheetState(() => endTime = picked);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          "Repeats On",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (index) {
                            final dayIndex = index + 1;
                            final isSelected = selectedWeekdays.contains(
                              dayIndex,
                            );
                            final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

                            return GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  isSelected
                                      ? selectedWeekdays.remove(dayIndex)
                                      : selectedWeekdays.add(dayIndex);
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? theme.primaryColor
                                      : Colors.grey[100],
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    days[index],
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isGenerating ? null : generateSchedule,
                            icon: isGenerating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 18,
                                    color: theme.primaryColor,
                                  ),
                            label: Text(
                              isGenerating
                                  ? "Generating..."
                                  : "Generate Schedule",
                              style: TextStyle(color: theme.primaryColor),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: theme.primaryColor.withOpacity(0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),

                        if (generatedSchedule.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "✅ ${generatedSchedule.length} Sessions Ready to Save",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        (isSaving || isGenerating || generatedSchedule.isEmpty)
                        ? null
                        : () async {
                            setSheetState(() => isSaving = true);
                            try {
                              await _addSubject(
                                nameController.text,
                                codeController.text,
                                generatedSchedule,
                              );
                            } catch (e) {
                              if (mounted)
                                setSheetState(() => isSaving = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                    ),
                    child: isSaving
                        ? GeometricLoader(size: 24, isDarkMode: isDarkMode)
                        : const Text(
                            "Save Lab Configuration",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDatePickerBox(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.05)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.layers_clear_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No Labs Configured",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Tap '+ Add Lab' to setup subjects",
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectTile(
    Map<String, dynamic> data,
    String id,
    ThemeData theme,
    bool isReadOnly,
  ) {
    final name = data['name'] ?? 'Unknown';
    final code = data['code'] ?? '---';
    final schedule = data['schedule'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor.withOpacity(0.15),
                  theme.primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              code.split('-').last,
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () => _showViewScheduleSheet(schedule, name),
            icon: Icon(
              Icons.calendar_month_outlined,
              color: theme.primaryColor.withOpacity(0.7),
              size: 22,
            ),
            tooltip: "View Schedule",
          ),

          if (!isReadOnly)
            IconButton(
              onPressed: () => _deleteSubject(id),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red[200],
                size: 20,
              ),
              splashRadius: 24,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDarkMode = theme.brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('academic_sessions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, sessionSnap) {
        List<QueryDocumentSnapshot> sessions = [];
        if (sessionSnap.hasData) {
          sessions = sessionSnap.data!.docs;

          // Determine Active Session
          try {
            final activeSession = sessions.firstWhere(
              (s) => s['status'] == 'Active',
            );
            _activeSessionId = activeSession.id;

            // Set initial view to active session if not set
            if (_viewingSessionId == null) {
              _viewingSessionId = activeSession.id;
              _viewingSessionName = activeSession['sessionName'];
            }
          } catch (e) {
            _activeSessionId = null; // No active session
            if (_viewingSessionId == null && sessions.isNotEmpty) {
              _viewingSessionId = sessions.first.id;
              _viewingSessionName = sessions.first['sessionName'];
            }
          }
        }

        final bool isReadOnly = _viewingSessionId != _activeSessionId;

        return Stack(
          children: [
            Scaffold(
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
                  "Academic Setup",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),

              // Only Show FAB if we are in ACTIVE session mode and an active session exists
              floatingActionButton: (_activeSessionId != null && !isReadOnly)
                  ? Padding(
                      padding: EdgeInsets.only(
                        bottom: bottomPadding > 0 ? 0 : 20,
                      ),
                      child: FloatingActionButton.extended(
                        onPressed: _showAddSubjectSheet,
                        backgroundColor: theme.primaryColor,
                        elevation: 2,
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Add Lab",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : null,

              body: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // --- Session Selector ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GestureDetector(
                        onTap: () => _showSessionSelector(sessions),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.primaryColor.withOpacity(0.3),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Academic Session",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _viewingSessionName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: theme.primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle("Department Course"),
                          // Only allow adding courses if in active mode (optional, but safe)
                          IconButton(
                            onPressed: _showAddCourseSheet,
                            icon: Icon(
                              Icons.add_circle,
                              color: theme.primaryColor,
                            ),
                            tooltip: "New Course",
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      height: 60,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('courses')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return Center(
                              child: GeometricLoader(
                                size: 30,
                                isDarkMode: isDarkMode,
                              ),
                            );
                          final courses = snapshot.data!.docs;

                          if (_selectedCourseId == null && courses.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted)
                                setState(() {
                                  _selectedCourseId = courses.first.id;
                                  _selectedCourseName = courses.first['name'];
                                  _selectedCourseDuration =
                                      courses.first['durationYears'];
                                  _selectedSemester = 1;
                                });
                            });
                          }

                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 4,
                            ),
                            clipBehavior: Clip.none,
                            itemCount: courses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final doc = courses[index];
                              final isSelected = _selectedCourseId == doc.id;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedCourseId = doc.id;
                                  _selectedCourseName = doc['name'];
                                  _selectedCourseDuration =
                                      doc['durationYears'];
                                  _selectedSemester = 1;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.primaryColor
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected
                                            ? theme.primaryColor.withOpacity(
                                                0.3,
                                              )
                                            : Colors.grey.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      doc['name'],
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[700],
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildSectionTitle("Semester"),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        clipBehavior: Clip.none,
                        itemCount: _selectedCourseDuration * 2,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final sem = index + 1;
                          final isSelected = _selectedSemester == sem;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedSemester = sem),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? theme.colorScheme.secondary
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.transparent
                                      : Colors.grey.withOpacity(0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? theme.colorScheme.secondary
                                              .withOpacity(0.4)
                                        : Colors.grey.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  "$sem",
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey[700],
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),
                    // --- SUBJECT LIST (FILTERED BY SESSION) ---
                    if (_selectedCourseId != null && _viewingSessionId != null)
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('subjects')
                            .where('courseId', isEqualTo: _selectedCourseId)
                            .where('semester', isEqualTo: _selectedSemester)
                            .where(
                              'sessionId',
                              isEqualTo: _viewingSessionId,
                            ) // KEY FILTER
                            .orderBy('createdAt')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return Padding(
                              padding: const EdgeInsets.only(top: 50),
                              child: Center(
                                child: GeometricLoader(
                                  size: 30,
                                  isDarkMode: isDarkMode,
                                ),
                              ),
                            );
                          final subjects = snapshot.data!.docs;

                          if (subjects.isEmpty) {
                            if (isReadOnly) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text(
                                    "No data in this past session.",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              );
                            }
                            return _buildEmptyState();
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.fromLTRB(
                              24,
                              0,
                              24,
                              bottomPadding + 80,
                            ),
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: subjects.length,
                            itemBuilder: (context, index) {
                              final data =
                                  subjects[index].data()
                                      as Map<String, dynamic>;
                              final id = subjects[index].id;
                              return _buildSubjectTile(
                                data,
                                id,
                                theme,
                                isReadOnly,
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: GeometricLoader(size: 60, isDarkMode: isDarkMode),
                ),
              ),
          ],
        );
      },
    );
  }
}
