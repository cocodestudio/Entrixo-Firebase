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
      Navigator.pop(context);
      _showSnack("Course added successfully!");
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSubject(String name, String code) async {
    if (name.trim().isEmpty || code.trim().isEmpty) {
      _showSnack("Please fill all fields", isError: true);
      return;
    }
    if (_selectedCourseId == null) {
      _showSnack("No course selected", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final existing = await _firestore
          .collection('subjects')
          .where('courseId', isEqualTo: _selectedCourseId)
          .where('code', isEqualTo: code.trim().toUpperCase())
          .get();

      if (existing.docs.isNotEmpty) {
        throw "Subject code '${code.trim().toUpperCase()}' already exists!";
      }

      await _firestore.collection('subjects').add({
        'name': name.trim(),
        'code': code.trim().toUpperCase(),
        'courseId': _selectedCourseId,
        'semester': _selectedSemester,
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context);
      _showSnack("Lab added successfully!");
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              const SizedBox(height: 8),
              Text(
                "Define the course structure and duration.",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                    elevation: 0,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.science_rounded,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Add New Lab",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          "$_selectedCourseName • Semester $_selectedSemester",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: "Lab Name",
                  hintText: "e.g. Advanced Java",
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
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _addSubject(
                          nameController.text,
                          codeController.text,
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    shadowColor: theme.primaryColor.withOpacity(0.4),
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? GeometricLoader(size: 24, isDarkMode: isDarkMode)
                      : const Text(
                          "Save Lab Subject",
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDarkMode = theme.brightness == Brightness.dark;

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
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding > 0 ? 0 : 20),
            child: FloatingActionButton.extended(
              onPressed: _showAddSubjectSheet,
              backgroundColor: theme.primaryColor,
              elevation: 2,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                "Add Lab",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle("Department Course"),
                      IconButton(
                        onPressed: _showAddCourseSheet,
                        icon: Icon(Icons.add_circle, color: theme.primaryColor),
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
                      if (!snapshot.hasData) {
                        return Center(
                          child: GeometricLoader(
                            size: 30,
                            isDarkMode: isDarkMode,
                          ),
                        );
                      }
                      final courses = snapshot.data!.docs;

                      if (courses.isEmpty) {
                        return Center(
                          child: TextButton.icon(
                            onPressed: _showAddCourseSheet,
                            icon: const Icon(Icons.add),
                            label: const Text("Add your first course"),
                          ),
                        );
                      }

                      if (_selectedCourseId == null && courses.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _selectedCourseId = courses.first.id;
                              _selectedCourseName = courses.first['name'];
                              _selectedCourseDuration =
                                  courses.first['durationYears'];
                              _selectedSemester = 1;
                            });
                          }
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
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final doc = courses[index];
                          final name = doc['name'];
                          final duration = doc['durationYears'];
                          final isSelected = _selectedCourseId == doc.id;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCourseId = doc.id;
                                _selectedCourseName = name;
                                _selectedCourseDuration = duration;
                                _selectedSemester = 1;
                              });
                            },
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
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: theme.primaryColor.withOpacity(
                                            0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Center(
                                child: Text(
                                  name,
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
                        onTap: () => setState(() => _selectedSemester = sem),
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
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.secondary
                                          .withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('subjects')
                        .where('courseId', isEqualTo: _selectedCourseId)
                        .where('semester', isEqualTo: _selectedSemester)
                        .orderBy('createdAt')
                        .snapshots(),
                    builder: (context, snapshot) {
                      int count = 0;
                      if (snapshot.hasData) count = snapshot.data!.docs.length;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle("Active Labs"),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "$count Found",
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedCourseId != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('subjects')
                        .where('courseId', isEqualTo: _selectedCourseId)
                        .where('semester', isEqualTo: _selectedSemester)
                        .orderBy('createdAt')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 50),
                          child: Center(
                            child: GeometricLoader(
                              size: 30,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                        );
                      }
                      final subjects = snapshot.data!.docs;

                      if (subjects.isEmpty) return _buildEmptyState();

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
                          final data = subjects[index];
                          final name = data.data().toString().contains('name')
                              ? data['name']
                              : 'Unknown';
                          final code = data.data().toString().contains('code')
                              ? data['code']
                              : '---';

                          return _buildSubjectTile(name, code, data.id, theme);
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
    String name,
    String code,
    String id,
    ThemeData theme,
  ) {
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
          ),
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
}
