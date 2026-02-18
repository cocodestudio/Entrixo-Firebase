import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../utils/custom_toast.dart';
import '../../widgets/geometric_loader.dart';
import '../utils/export_service.dart';
import '../widgets/export_dialog.dart';

class DailyHeadcountScreen extends StatefulWidget {
  const DailyHeadcountScreen({super.key});

  @override
  State<DailyHeadcountScreen> createState() => _DailyHeadcountScreenState();
}

class _DailyHeadcountScreenState extends State<DailyHeadcountScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isFetchingCount = false;

  String? _selectedCourseId;
  String? _selectedCourseName;
  int? _courseDuration;
  int? _selectedSemester;
  int? _currentTotalStudents;

  final TextEditingController _preController = TextEditingController();
  final TextEditingController _postController = TextEditingController();

  List<BatchHeadcountModel> _todayEntries = [];

  int _grandTotal = 0;
  int _grandPre = 0;
  int _grandPost = 0;

  @override
  void initState() {
    super.initState();
    _fetchDailyData();
  }

  @override
  void dispose() {
    _preController.dispose();
    _postController.dispose();
    super.dispose();
  }

  Future<void> _saveFinalSheet() async {
    if (_todayEntries.isEmpty) {
      CustomToast.show(context, "No entries found to export!", isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ExportDialog(
        onPdfTap: () async {
          Navigator.pop(context);
          CustomToast.show(context, "Generating PDF...", isError: false);

          await ExportService.generatePdf(
            context,
            _selectedDate,
            _todayEntries,
            _grandTotal,
            _grandPre,
            _grandPost,
          );
        },
        onExcelTap: () async {
          Navigator.pop(context);
          CustomToast.show(context, "Generating Excel...", isError: false);

          await ExportService.generateExcel(
            context,
            _selectedDate,
            _todayEntries,
            _grandTotal,
            _grandPre,
            _grandPost,
          );
        },
      ),
    );
  }

  Future<void> _fetchDailyData() async {
    setState(() => _isLoading = true);
    try {
      final String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final docSnap = await _firestore
          .collection('daily_headcounts')
          .doc(dateKey)
          .get();

      if (docSnap.exists) {
        final data = docSnap.data()!;
        final List<dynamic> savedBatches = data['batches'] ?? [];
        _todayEntries = savedBatches
            .map((e) => BatchHeadcountModel.fromMap(e))
            .toList();
      } else {
        _todayEntries = [];
      }
      _recalculateTotals();
    } catch (e) {
      if (mounted)
        CustomToast.show(context, "Error loading data", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudentCount() async {
    if (_selectedCourseId == null || _selectedSemester == null) return;

    setState(() => _isFetchingCount = true);
    try {
      final existingIndex = _todayEntries.indexWhere(
        (e) =>
            e.courseName == _selectedCourseName &&
            e.semester == "Sem $_selectedSemester",
      );

      if (existingIndex != -1) {
        final existing = _todayEntries[existingIndex];
        _currentTotalStudents = existing.totalStudents;
        _preController.text = existing.preLunch.toString();
        _postController.text = existing.postLunch.toString();
        setState(() => _isFetchingCount = false);
        return;
      }

      final countQuery = await _firestore
          .collection('users')
          .where('courseId', isEqualTo: _selectedCourseId)
          .where('currentSemester', isEqualTo: _selectedSemester)
          .where('role', isEqualTo: 'student')
          .count()
          .get();

      setState(() {
        _currentTotalStudents = countQuery.count ?? 0;
        _preController.clear();
        _postController.clear();
        _isFetchingCount = false;
      });
    } catch (e) {
      setState(() => _isFetchingCount = false);
      if (mounted)
        CustomToast.show(context, "Failed to fetch count", isError: true);
    }
  }

  void _addOrUpdateEntry() {
    if (_currentTotalStudents == null) return;
    FocusScope.of(context).unfocus();

    int pre = int.tryParse(_preController.text) ?? 0;
    int post = int.tryParse(_postController.text) ?? 0;

    if (pre > _currentTotalStudents! || post > _currentTotalStudents!) {
      CustomToast.show(
        context,
        "Count cannot exceed Total Students!",
        isError: true,
      );
      return;
    }

    final newEntry = BatchHeadcountModel(
      courseName: _selectedCourseName!,
      semester: "Sem $_selectedSemester",
      totalStudents: _currentTotalStudents!,
      preLunch: pre,
      postLunch: post,
    );

    setState(() {
      final index = _todayEntries.indexWhere(
        (e) =>
            e.courseName == newEntry.courseName &&
            e.semester == newEntry.semester,
      );

      if (index != -1) {
        _todayEntries[index] = newEntry;
      } else {
        _todayEntries.add(newEntry);
      }

      _selectedCourseId = null;
      _selectedCourseName = null;
      _selectedSemester = null;
      _currentTotalStudents = null;
      _preController.clear();
      _postController.clear();

      _recalculateTotals();
    });

    _saveToFirestore();
  }

  void _recalculateTotals() {
    int t = 0, p = 0, po = 0;
    for (var e in _todayEntries) {
      t += e.totalStudents;
      p += e.preLunch;
      po += e.postLunch;
    }
    setState(() {
      _grandTotal = t;
      _grandPre = p;
      _grandPost = po;
    });
  }

  Future<void> _saveToFirestore() async {
    try {
      final String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final Map<String, dynamic> payload = {
        'date': dateKey,
        'dateIso': _selectedDate.toIso8601String(),
        'lastUpdatedBy': _auth.currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'grandTotal': _grandTotal,
        'grandPreLunch': _grandPre,
        'grandPostLunch': _grandPost,
        'batches': _todayEntries.map((e) => e.toMap()).toList(),
      };

      await _firestore
          .collection('daily_headcounts')
          .doc(dateKey)
          .set(payload, SetOptions(merge: true));

      if (mounted)
        CustomToast.show(context, "Entry Saved Successfully", isError: false);
    } catch (e) {
      if (mounted) CustomToast.show(context, "Save Failed", isError: true);
    }
  }

  void _showCourseSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 24),
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      title: Text(
                        data['name'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCourseId = doc.id;
                          _selectedCourseName = data['name'];
                          _courseDuration = data['durationYears'];
                          _selectedSemester = null;
                          _currentTotalStudents = null;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSemesterSheet() {
    if (_selectedCourseId == null) {
      CustomToast.show(context, "Please select a course first", isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: (_courseDuration ?? 0) * 2,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  int sem = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedSemester = sem);
                      Navigator.pop(context);
                      _fetchStudentCount();
                    },
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "SEM",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "$sem",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          "Daily Headcount",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: GeometricLoader(size: 50, isDarkMode: false))
          : Column(
              children: [
                _buildDateSelector(),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSelectionSection(),

                        const SizedBox(height: 24),

                        if (_isFetchingCount)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: GeometricLoader(
                                size: 30,
                                isDarkMode: false,
                              ),
                            ),
                          )
                        else if (_currentTotalStudents != null)
                          _buildInputSection(),

                        const SizedBox(height: 32),

                        if (_todayEntries.isNotEmpty) ...[
                          Text(
                            "TODAY'S ENTRIES",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey[500],
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _todayEntries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _BatchDisplayCard(model: _todayEntries[index]),
                          ),
                        ],

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),

                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2024),
            lastDate: DateTime(2030),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Colors.black,
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            ),
          );
          if (picked != null && picked != _selectedDate) {
            setState(() {
              _selectedDate = picked;
              _selectedCourseId = null;
              _currentTotalStudents = null;
            });
            _fetchDailyData();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: Colors.black54,
                size: 20,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Date",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy, EEEE').format(_selectedDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionSection() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _showCourseSheet,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedCourseId != null
                      ? Colors.black
                      : Colors.grey[300]!,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedCourseName ?? "Select Course",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selectedCourseName != null
                            ? Colors.black
                            : Colors.grey[400],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: _selectedCourseName != null
                        ? Colors.black
                        : Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _showSemesterSheet,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _selectedCourseId == null
                    ? Colors.grey[100]
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedSemester != null
                      ? Colors.black
                      : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedSemester != null
                          ? "Sem $_selectedSemester"
                          : "Sem",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selectedSemester != null
                            ? Colors.black
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: _selectedSemester != null
                        ? Colors.black
                        : Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Headcount Entry",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Total: $_currentTotalStudents",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  "PRE-LUNCH",
                  _preController,
                  const Color(0xFF00D26A),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField(
                  "POST-LUNCH",
                  _postController,
                  const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _addOrUpdateEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Add / Update Entry",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.grey[400],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          cursorColor: Colors.black,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: "0",
            hintStyle: const TextStyle(color: Colors.black12),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _footerStat("TOTAL", "$_grandTotal", Colors.black),
              Container(height: 30, width: 1, color: Colors.grey[200]),
              _footerStat("PRE-LUNCH", "$_grandPre", const Color(0xFF00D26A)),
              Container(height: 30, width: 1, color: Colors.grey[200]),
              _footerStat("POST-LUNCH", "$_grandPost", const Color(0xFF4F46E5)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _todayEntries.isEmpty ? null : _saveFinalSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.save_rounded,
                    color: _todayEntries.isEmpty
                        ? Colors.white.withOpacity(0.5)
                        : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Save Final Sheet",
                    style: TextStyle(
                      color: _todayEntries.isEmpty
                          ? Colors.white.withOpacity(0.5)
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BatchDisplayCard extends StatelessWidget {
  final BatchHeadcountModel model;
  const _BatchDisplayCard({required this.model});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.courseName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  model.semester,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _miniBadge(model.preLunch.toString(), const Color(0xFF00D26A)),
              const SizedBox(width: 8),
              _miniBadge(model.postLunch.toString(), const Color(0xFF4F46E5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String val, Color color) {
    return Container(
      width: 40,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Center(
        child: Text(
          val,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class BatchHeadcountModel {
  final String courseName;
  final String semester;
  final int totalStudents;
  int preLunch;
  int postLunch;

  BatchHeadcountModel({
    required this.courseName,
    required this.semester,
    required this.totalStudents,
    this.preLunch = 0,
    this.postLunch = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'courseName': courseName,
      'semester': semester,
      'totalStudents': totalStudents,
      'preLunch': preLunch,
      'postLunch': postLunch,
    };
  }

  factory BatchHeadcountModel.fromMap(Map<String, dynamic> map) {
    return BatchHeadcountModel(
      courseName: map['courseName'] ?? '',
      semester: map['semester'] ?? '',
      totalStudents: map['totalStudents'] ?? 0,
      preLunch: map['preLunch'] ?? 0,
      postLunch: map['postLunch'] ?? 0,
    );
  }
}
