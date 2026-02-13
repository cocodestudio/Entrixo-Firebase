import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/custom_toast.dart';
import '../../widgets/geometric_loader.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedCourseId;
  String _selectedCourseName = 'Select Course';
  int _currentCourseDuration = 0;
  int? _selectedSemester;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- SELECTION LOGIC (Reused for Filter & Edit) ---

  void _showCourseSelector({
    required Function(String id, String name, int duration) onSelect,
  }) {
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
                    if (!snapshot.hasData) {
                      return const Center(
                        child: GeometricLoader(size: 30, isDarkMode: false),
                      );
                    }
                    final courses = snapshot.data!.docs;

                    return ListView.separated(
                      controller: controller,
                      itemCount: courses.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 24),
                      itemBuilder: (context, index) {
                        final doc = courses[index];
                        final data = doc.data() as Map<String, dynamic>;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          title: Text(
                            data['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            "${data['durationYears']} Years",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          onTap: () {
                            onSelect(
                              doc.id,
                              data['name'],
                              data['durationYears'],
                            );
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

  void _showSemesterSelector({
    required int duration,
    required Function(int sem) onSelect,
  }) {
    final int maxSemesters = duration * 2;

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
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(
                      "Semester $sem",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      onSelect(sem);
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

  // --- ACTIONS ---

  void _showStudentActionSheet(Map<String, dynamic> data, String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Manage Student",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 24),
            _buildActionTile(
              icon: Icons.edit_rounded,
              color: Colors.blueAccent,
              label: "Edit Details",
              onTap: () {
                Navigator.pop(context);
                _showEditSheet(data, uid);
              },
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.delete_outline_rounded,
              color: Colors.redAccent,
              label: "Delete Student",
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _deleteStudent(uid);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDestructive
              ? const Color(0xFFFFF5F5)
              : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isDestructive ? Colors.red : const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStudent(String uid) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Student"),
        content: const Text("Are you sure? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestore.collection('users').doc(uid).delete();
                if (mounted)
                  CustomToast.show(context, "Student deleted successfully");
              } catch (e) {
                if (mounted)
                  CustomToast.show(context, "Error: $e", isError: true);
              }
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(Map<String, dynamic> data, String uid) {
    final nameCtrl = TextEditingController(text: data['name']);
    final rollCtrl = TextEditingController(text: data['rollNumber']);

    // Local state for editing course/sem
    String editCourseId = data['courseId'];
    String editCourseName = data['courseName'];
    int editSemester = data['currentSemester'];
    // We need duration to calculate max semesters for the selected course.
    // Assuming 4 years (8 sem) as fallback if not available,
    // or we fetch it. For better UX, we'll try to keep existing or default.
    int editDuration = 4;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
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
                    "Update Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Name Field
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Roll No Field
                  TextField(
                    controller: rollCtrl,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: "Roll Number",
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Course Selector
                  _buildEditSelector(
                    label: "Course",
                    value: editCourseName,
                    icon: Icons.school_outlined,
                    onTap: () {
                      _showCourseSelector(
                        onSelect: (id, name, duration) {
                          setSheetState(() {
                            editCourseId = id;
                            editCourseName = name;
                            editDuration = duration;
                            editSemester = 1; // Reset to 1 on course change
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Semester Selector
                  _buildEditSelector(
                    label: "Semester",
                    value: "Semester $editSemester",
                    icon: Icons.layers_outlined,
                    onTap: () {
                      _showSemesterSelector(
                        duration: editDuration,
                        onSelect: (sem) {
                          setSheetState(() {
                            editSemester = sem;
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await _firestore.collection('users').doc(uid).update({
                            'name': nameCtrl.text.trim(),
                            'rollNumber': rollCtrl.text.trim().toUpperCase(),
                            'courseId': editCourseId,
                            'courseName': editCourseName,
                            'currentSemester': editSemester,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          if (mounted) {
                            Navigator.pop(context);
                            CustomToast.show(context, "Student Updated");
                          }
                        } catch (e) {
                          CustomToast.show(
                            context,
                            "Update Failed: $e",
                            isError: true,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.4),
                      ),
                      child: const Text(
                        "Save Changes",
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
          );
        },
      ),
    );
  }

  Widget _buildEditSelector({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[600]),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down_rounded, color: Colors.black),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          title: Text(
            "Student Directory",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
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
        ),
        body: Column(
          children: [
            // --- FILTER & SEARCH HEADER ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterChip(
                          label: _selectedCourseName,
                          icon: Icons.school_rounded,
                          isSelected: _selectedCourseId != null,
                          onTap: () {
                            _showCourseSelector(
                              onSelect: (id, name, duration) {
                                setState(() {
                                  _selectedCourseId = id;
                                  _selectedCourseName = name;
                                  _currentCourseDuration = duration;
                                  _selectedSemester = null;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFilterChip(
                          label: _selectedSemester == null
                              ? "Semester"
                              : "Sem $_selectedSemester",
                          icon: Icons.layers_rounded,
                          isSelected: _selectedSemester != null,
                          onTap: _selectedCourseId == null
                              ? null
                              : () {
                                  _showSemesterSelector(
                                    duration: _currentCourseDuration,
                                    onSelect: (sem) =>
                                        setState(() => _selectedSemester = sem),
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                  if (_selectedCourseId != null &&
                      _selectedSemester != null) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(
                        () => _searchQuery = val.trim().toLowerCase(),
                      ),
                      decoration: InputDecoration(
                        hintText: "Search by Roll No or Phone...",
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // --- LIST CONTENT ---
            Expanded(
              child: (_selectedCourseId == null || _selectedSemester == null)
                  ? _buildEmptyState(
                      "Select Course & Semester",
                      "To view the student list, please apply filters above.",
                      Icons.filter_alt_off_rounded,
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('users')
                          .where('role', isEqualTo: 'student')
                          .where('courseId', isEqualTo: _selectedCourseId)
                          .where(
                            'currentSemester',
                            isEqualTo: _selectedSemester,
                          )
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: GeometricLoader(size: 40, isDarkMode: false),
                          );
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return _buildEmptyState(
                            "No Students Found",
                            "No students registered in this class yet.",
                            Icons.people_outline_rounded,
                          );
                        }

                        final allStudents = snapshot.data!.docs;
                        final filteredList = allStudents.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final roll = (data['rollNumber'] ?? "")
                              .toString()
                              .toLowerCase();
                          final phone = (data['phoneNumber'] ?? "")
                              .toString()
                              .toLowerCase();
                          return _searchQuery.isEmpty ||
                              roll.contains(_searchQuery) ||
                              phone.contains(_searchQuery);
                        }).toList();

                        if (filteredList.isEmpty) {
                          return _buildEmptyState(
                            "No Match Found",
                            "Try searching with a different roll number.",
                            Icons.search_off_rounded,
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final doc = filteredList[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final bool isManual = data['isManualEntry'] == true;
                            final String initials = (data['name'] ?? "S")
                                .toString()
                                .substring(0, 1)
                                .toUpperCase();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isManual
                                      ? Colors.orange.withOpacity(0.1)
                                      : theme.primaryColor.withOpacity(0.1),
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isManual
                                          ? Colors.orange
                                          : theme.primaryColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        data['name'] ?? "Unknown",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isManual
                                            ? Colors.orange.withOpacity(0.1)
                                            : Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isManual ? "MANUAL" : "VERIFIED",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: isManual
                                              ? Colors.orange
                                              : Colors.green,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.badge_outlined,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        data['rollNumber'] ?? "N/A",
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  color: Colors.grey[400],
                                  onPressed: () =>
                                      _showStudentActionSheet(data, doc.id),
                                ),
                              ),
                            );
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

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(0.5)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
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
              child: Icon(icon, size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
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
