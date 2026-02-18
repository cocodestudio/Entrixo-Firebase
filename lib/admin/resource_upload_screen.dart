import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/geometric_loader.dart';
import '../utils/custom_toast.dart';

class ResourceUploadScreen extends StatefulWidget {
  const ResourceUploadScreen({super.key});

  @override
  State<ResourceUploadScreen> createState() => _ResourceUploadScreenState();
}

class _ResourceUploadScreenState extends State<ResourceUploadScreen> {
  String _activeTab = 'Upload';
  String _selectedType = 'Resource';
  final List<String> _types = ['Resource', 'Assignment'];

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _rulesController = TextEditingController();

  String _selectedCourseId = 'ALL';
  String _selectedCourseName = 'All Courses';
  String _selectedSemester = 'ALL';
  int _currentCourseDuration = 0;

  PlatformFile? _pickedFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  IconData _getTypeIcon(String type) {
    return type == 'Assignment'
        ? Icons.assignment_turned_in_rounded
        : Icons.folder_copy_rounded;
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'jpg',
          'png',
          'zip',
        ],
      );

      if (result != null) {
        if (result.files.first.size > 10 * 1024 * 1024) {
          if (mounted) {
            CustomToast.show(
              context,
              "File too large. Max 10MB allowed.",
              isError: true,
            );
          }
          return;
        }
        setState(() {
          _pickedFile = result.files.first;
        });
      }
    } catch (e) {
      CustomToast.show(context, "Error picking file: $e", isError: true);
    }
  }

  Future<void> _uploadAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedFile == null && _linkController.text.isEmpty) {
      CustomToast.show(
        context,
        "Please attach a file or provide a link",
        isError: true,
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? fileUrl;
      String? fileName;
      String? fileExtension;

      if (_pickedFile != null) {
        final file = File(_pickedFile!.path!);
        fileName = _pickedFile!.name;
        fileExtension = _pickedFile!.extension;

        final storageRef = FirebaseStorage.instance.ref().child(
          'resources/${_selectedType.toLowerCase()}s/${DateTime.now().millisecondsSinceEpoch}_$fileName',
        );

        final uploadTask = storageRef.putFile(file);

        uploadTask.snapshotEvents.listen((event) {
          setState(() {
            _uploadProgress = event.bytesTransferred / event.totalBytes;
          });
        });

        await uploadTask;
        fileUrl = await storageRef.getDownloadURL();
      }

      final data = {
        'type': _selectedType,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'link': _linkController.text.trim(),
        'rules': _rulesController.text.trim(),
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileExtension': fileExtension,
        'courseId': _selectedCourseId,
        'courseName': _selectedCourseName,
        'semester': _selectedSemester,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': 'Admin',
      };

      await FirebaseFirestore.instance.collection('resources').add(data);

      _titleController.clear();
      _descController.clear();
      _linkController.clear();
      _rulesController.clear();
      setState(() {
        _pickedFile = null;
        _isUploading = false;
        _uploadProgress = 0.0;
        _selectedCourseId = 'ALL';
        _selectedCourseName = 'All Courses';
        _selectedSemester = 'ALL';
      });

      if (mounted)
        CustomToast.show(context, "$_selectedType uploaded successfully!");
    } catch (e) {
      if (mounted)
        CustomToast.show(context, "Upload Failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteResource(String id, String? fileUrl) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Delete Resource"),
            content: const Text("Are you sure? This cannot be undone."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('resources').doc(id).delete();

      if (fileUrl != null && fileUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(fileUrl).delete();
        } catch (_) {}
      }

      if (mounted) CustomToast.show(context, "Resource deleted");
    } catch (e) {
      if (mounted) CustomToast.show(context, "Error: $e", isError: true);
    }
  }

  void _showCourseSelector() {
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
              stream: FirebaseFirestore.instance
                  .collection('courses')
                  .snapshots(),
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
                      _buildSelectionItem(
                        title: "All Courses",
                        isSelected: _selectedCourseId == 'ALL',
                        onTap: () {
                          setState(() {
                            _selectedCourseId = 'ALL';
                            _selectedCourseName = 'All Courses';
                            _currentCourseDuration = 0;
                            _selectedSemester = 'ALL';
                          });
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(height: 1),
                      ...courses.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildSelectionItem(
                          title: data['name'],
                          subtitle: "${data['durationYears']} Years",
                          isSelected: _selectedCourseId == doc.id,
                          onTap: () {
                            setState(() {
                              _selectedCourseId = doc.id;
                              _selectedCourseName = data['name'];
                              _currentCourseDuration = data['durationYears'];
                              _selectedSemester = 'ALL';
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

  void _showSemesterSelector() {
    if (_selectedCourseId == 'ALL') {
      CustomToast.show(
        context,
        "Select a specific course first",
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

  Widget _buildTypeCard(String type, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _pickedFile = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey.withOpacity(0.2),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                _getTypeIcon(type),
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                type,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileUploadArea() {
    if (_pickedFile != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).primaryColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.description_rounded,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pickedFile!.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB",
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.red),
              onPressed: () => setState(() => _pickedFile = null),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_rounded, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              "Tap to upload files",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "PDF, DOC, JPG (Max 10MB)",
              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: _types
                .map((type) => _buildTypeCard(type, _selectedType == type))
                .toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people_alt_rounded,
                      size: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Target Audience",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _showCourseSelector,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedCourseName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                if (_selectedCourseId != 'ALL') ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _showSemesterSelector,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedSemester == 'ALL'
                                ? "All Semesters"
                                : "Semester $_selectedSemester",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Details",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  validator: (v) => v!.isEmpty ? "Title is required" : null,
                  decoration: InputDecoration(
                    hintText: "Title (e.g. Lab Manual 01)",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Description (Optional)",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                if (_selectedType == 'Assignment') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rulesController,
                    decoration: InputDecoration(
                      hintText: "Rules or Instructions (Optional)",
                      prefixIcon: const Icon(Icons.gavel_rounded, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  "Attachments",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildFileUploadArea(),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    "OR",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    hintText: "Paste external link",
                    prefixIcon: const Icon(Icons.link_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildManageTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('resources')
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: GeometricLoader(size: 40, isDarkMode: false),
          );
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 60,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  "No resources uploaded yet",
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;
            final type = data['type'] ?? 'Resource';
            final date = (data['uploadedAt'] as Timestamp?)?.toDate();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: type == 'Assignment'
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getTypeIcon(type),
                      color: type == 'Assignment' ? Colors.orange : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['title'] ?? 'Untitled',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${data['courseName']} • ${data['semester'] == 'ALL' ? 'All Semesters' : 'Sem ${data['semester']}'}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (date != null)
                          Text(
                            DateFormat('dd MMM yyyy').format(date),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[400],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    onPressed: () => _deleteResource(id, data['fileUrl']),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          "Resources & Assignments",
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 'Upload'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeTab == 'Upload'
                            ? theme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Upload New",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _activeTab == 'Upload'
                              ? Colors.white
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 'Manage'),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeTab == 'Manage'
                            ? theme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Manage Files",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _activeTab == 'Manage'
                              ? Colors.white
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _activeTab == 'Upload' ? _buildUploadTab() : _buildManageTab(),
          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GeometricLoader(size: 40, isDarkMode: false),
                      const SizedBox(height: 16),
                      Text(
                        "Uploading... ${(_uploadProgress * 100).toInt()}%",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _activeTab == 'Upload'
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FloatingActionButton.extended(
                onPressed: _isUploading ? null : _uploadAndSave,
                backgroundColor: theme.primaryColor,
                elevation: 4,
                label: Text(
                  "Publish $_selectedType",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                icon: const Icon(
                  Icons.cloud_upload_rounded,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
