import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/custom_toast.dart';
import '../../widgets/geometric_loader.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollNoController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _selectedCourseId;
  String _selectedCourseName = 'Select Course';
  int _currentCourseDuration = 0;
  int? _selectedSemester;

  @override
  void dispose() {
    _nameController.dispose();
    _rollNoController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _registerStudent() async {
    FocusScope.of(context).unfocus();

    if (_nameController.text.trim().isEmpty ||
        _rollNoController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _selectedCourseId == null ||
        _selectedSemester == null) {
      CustomToast.show(
        context,
        "Please fill all mandatory fields (*)",
        isError: true,
      );
      return;
    }

    if (_phoneController.text.trim().length != 10) {
      CustomToast.show(
        context,
        "Please enter a valid 10-digit phone number",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String fullPhoneNumber = "+91${_phoneController.text.trim()}";

      final QuerySnapshot rollNoCheck = await _firestore
          .collection('users')
          .where(
            'rollNumber',
            isEqualTo: _rollNoController.text.trim().toUpperCase(),
          )
          .get();

      if (rollNoCheck.docs.isNotEmpty) {
        throw "Student with this Roll Number already exists.";
      }

      final QuerySnapshot phoneCheck = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: fullPhoneNumber)
          .get();

      if (phoneCheck.docs.isNotEmpty) {
        throw "Student with this Phone Number already exists.";
      }

      final docRef = _firestore.collection('users').doc();

      await docRef.set({
        'uid': docRef.id,
        'name': _nameController.text.trim(),
        'rollNumber': _rollNoController.text.trim().toUpperCase(),
        'phoneNumber': fullPhoneNumber,
        'courseId': _selectedCourseId,
        'courseName': _selectedCourseName,
        'currentSemester': _selectedSemester,
        'role': 'student',
        'isManualEntry': true,
        'isSetupCompleted': true,
        'registeredBy': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        CustomToast.show(context, "Student Added Successfully!");
        _nameController.clear();
        _rollNoController.clear();
        _phoneController.clear();
        setState(() {
          _selectedCourseId = null;
          _selectedCourseName = 'Select Course';
          _selectedSemester = null;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      CustomToast.show(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCourseSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
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
                child: Text(
                  "Select Course",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('courses')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: GeometricLoader(size: 30, isDarkMode: false),
                      );
                    }

                    final courses = snapshot.data!.docs;
                    if (courses.isEmpty)
                      return const Center(child: Text("No courses found"));

                    return ListView.separated(
                      controller: controller,
                      itemCount: courses.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 24),
                      itemBuilder: (context, index) {
                        final doc = courses[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final isSelected = _selectedCourseId == doc.id;

                        return _buildSelectionItem(
                          title: data['name'],
                          subtitle: "${data['durationYears']} Years Duration",
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedCourseId = doc.id;
                              _selectedCourseName = data['name'];
                              _currentCourseDuration = data['durationYears'];
                              _selectedSemester = null;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
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

  void _showSemesterSelector() {
    if (_selectedCourseId == null) {
      CustomToast.show(context, "Please select a course first", isError: true);
      return;
    }

    final int maxSemesters = _currentCourseDuration * 2;

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
              child: Text(
                "Select Semester",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: maxSemesters,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 24),
                itemBuilder: (context, index) {
                  final sem = index + 1;
                  return _buildSelectionItem(
                    title: "Semester $sem",
                    isSelected: _selectedSemester == sem,
                    onTap: () {
                      setState(() => _selectedSemester = sem);
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
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: isSelected ? theme.primaryColor.withOpacity(0.08) : null,
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
                          : FontWeight.w600,
                      color: isSelected
                          ? theme.primaryColor
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.primaryColor,
                size: 28,
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
          "Add Student",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionLabel("Student Details"),
                const SizedBox(height: 16),
                _buildPremiumTextField(
                  controller: _nameController,
                  label: "Full Name *",
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 16),
                _buildPremiumTextField(
                  controller: _rollNoController,
                  label: "Roll Number *",
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                _buildPremiumTextField(
                  controller: _phoneController,
                  label: "Phone Number *",
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  prefixText: "+91 ",
                ),

                const SizedBox(height: 32),
                _buildSectionLabel("Academic Info"),
                const SizedBox(height: 16),

                _buildPremiumSelector(
                  label: "Course *",
                  value: _selectedCourseName,
                  icon: Icons.school_outlined,
                  onTap: _showCourseSelector,
                  isSelected: _selectedCourseId != null,
                ),
                const SizedBox(height: 16),

                Opacity(
                  opacity: _selectedCourseId == null ? 0.6 : 1.0,
                  child: _buildPremiumSelector(
                    label: "Semester *",
                    value: _selectedSemester == null
                        ? "Select Semester"
                        : "Semester $_selectedSemester",
                    icon: Icons.layers_outlined,
                    onTap: _selectedCourseId == null
                        ? null
                        : _showSemesterSelector,
                    isSelected: _selectedSemester != null,
                  ),
                ),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerStudent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: theme.primaryColor.withOpacity(0.4),
                    ),
                    child: _isLoading
                        ? GeometricLoader(
                            size: 24,
                            isDarkMode: theme.brightness == Brightness.dark,
                          )
                        : const Text(
                            "Register Student",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: GeometricLoader(size: 60, isDarkMode: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumSelector({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.primaryColor.withOpacity(0.5)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? theme.primaryColor : Colors.grey[400],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSelected) ...[
                    Text(
                      label.replaceAll(" *", ""),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSelected
                          ? const Color(0xFF1A1A1A)
                          : Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey[800],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
          fontSize: 13,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          prefixText: prefixText,
          prefixStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
            fontSize: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }
}
