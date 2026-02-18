import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/geometric_loader.dart';
import '../utils/custom_toast.dart';

class StudentResourcesScreen extends StatefulWidget {
  const StudentResourcesScreen({super.key});

  @override
  State<StudentResourcesScreen> createState() => _StudentResourcesScreenState();
}

class _StudentResourcesScreenState extends State<StudentResourcesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _studentData;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentProfile();
  }

  Future<void> _fetchStudentProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            _studentData = doc.data();
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          "Resources",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: const Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingProfile
          ? Center(child: GeometricLoader(size: 45, isDarkMode: false))
          : _buildResourceList(theme),
    );
  }

  Widget _buildResourceList(ThemeData theme) {
    final String myCourseId = _studentData?['courseId'] ?? 'UNKNOWN';
    final String mySemester =
        _studentData?['currentSemester']?.toString() ?? '1';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('resources')
          .where('type', isEqualTo: 'Resource')
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: Colors.red.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  "Unable to load resources",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: GeometricLoader(size: 40, isDarkMode: false));
        }

        final docs = snapshot.data!.docs;

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String targetCourse = data['courseId'] ?? 'ALL';
          final String targetSem = data['semester']?.toString() ?? 'ALL';

          final bool courseMatch =
              targetCourse == 'ALL' || targetCourse == myCourseId;
          final bool semMatch = targetSem == 'ALL' || targetSem == mySemester;

          return courseMatch && semMatch;
        }).toList();

        if (filteredDocs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          physics: const BouncingScrollPhysics(),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            return _ResourceCard(data: data, theme: theme);
          },
        );
      },
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
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 64,
                color: Colors.indigo.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "No Resources Found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Materials for your course/semester\nwill appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
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

class _ResourceCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final ThemeData theme;

  const _ResourceCard({required this.data, required this.theme});

  @override
  State<_ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends State<_ResourceCard> {
  bool _isDownloading = false;
  double _progress = 0.0;

  Future<void> _handleAction() async {
    final String? fileUrl = widget.data['fileUrl'];
    final String? link = widget.data['link'];
    final String title = widget.data['title'] ?? 'Resource';
    final String? ext = widget.data['fileExtension'];

    if (fileUrl != null && fileUrl.isNotEmpty) {
      await _downloadFile(fileUrl, title, ext);
    } else if (link != null && link.isNotEmpty) {
      await _launchURL(link);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted)
        CustomToast.show(context, "Could not launch link", isError: true);
    }
  }

  Future<void> _downloadFile(
    String url,
    String fileName,
    String? extension,
  ) async {
    if (_isDownloading) return;

    Directory? dir;
    try {
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download/Entrixo');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      dir = await getExternalStorageDirectory();
    }

    final String savePath =
        "${dir?.path}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.${extension ?? 'pdf'}";

    setState(() => _isDownloading = true);

    try {
      await Dio().download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _progress = 0.0;
        });
        CustomToast.show(context, "Saved to Downloads/Entrixo");
        await OpenFile.open(savePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        CustomToast.show(context, "Download Failed", isError: true);
      }
    }
  }

  Color _getFileColor(String? ext) {
    if (ext == null) return Colors.blue;
    final e = ext.toLowerCase();
    if (['pdf'].contains(e)) return const Color(0xFFFF4757);
    if (['doc', 'docx'].contains(e)) return const Color(0xFF2E86DE);
    if (['ppt', 'pptx'].contains(e)) return const Color(0xFFFF9F43);
    if (['xls', 'xlsx'].contains(e)) return const Color(0xFF10AC84);
    if (['jpg', 'png', 'jpeg'].contains(e)) return const Color(0xFF5F27CD);
    return const Color(0xFF576574);
  }

  IconData _getFileIcon(String? ext) {
    if (ext == null) return Icons.link_rounded;
    final e = ext.toLowerCase();
    if (['pdf'].contains(e)) return Icons.picture_as_pdf_rounded;
    if (['doc', 'docx'].contains(e)) return Icons.description_rounded;
    if (['ppt', 'pptx'].contains(e)) return Icons.slideshow_rounded;
    if (['xls', 'xlsx'].contains(e)) return Icons.table_chart_rounded;
    if (['jpg', 'png', 'jpeg'].contains(e)) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final String? fileUrl = widget.data['fileUrl'];
    final String? link = widget.data['link'];
    final String? ext = widget.data['fileExtension'];
    final Timestamp? date = widget.data['uploadedAt'];
    final bool isLink =
        (fileUrl == null || fileUrl.isEmpty) &&
        (link != null && link.isNotEmpty);

    final Color accentColor = isLink ? Colors.blue : _getFileColor(ext);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleAction,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Premium Icon Box
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      if (_isDownloading)
                        CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 3,
                          color: accentColor,
                        )
                      else
                        Icon(
                          _getFileIcon(isLink ? null : ext),
                          color: accentColor,
                          size: 28,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.data['title'] ?? 'Untitled Resource',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1A1A1A),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (date != null) ...[
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM').format(date.toDate()),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isLink ? "LINK" : (ext?.toUpperCase() ?? "FILE"),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Action Button
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: Icon(
                    isLink
                        ? Icons.open_in_new_rounded
                        : (_isDownloading
                              ? Icons.pause_rounded
                              : Icons.download_rounded),
                    size: 20,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
