import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

class StudentScannerScreen extends StatefulWidget {
  const StudentScannerScreen({super.key});

  @override
  State<StudentScannerScreen> createState() => _StudentScannerScreenState();
}

class _StudentScannerScreenState extends State<StudentScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
    formats: [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;
  bool _isSuccess = false;
  String _statusMessage = "Align QR code within the frame";
  Color _statusColor = Colors.white;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.start();
    }
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _controller.start();
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Camera Permission Required"),
        content: const Text(
          "Entrixo needs camera access to scan attendance QR codes. Please enable it in settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(ctx);
            },
            child: const Text("Settings"),
          ),
        ],
      ),
    );
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing || _isSuccess) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code != null) {
      _processAttendance(code);
    }
  }

  Future<void> _processAttendance(String qrData) async {
    setState(() {
      _isProcessing = true;
      _controller.stop();
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "User not authenticated";

      _updateStatus("Detecting Student Profile...", Colors.blue);
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      if (userData == null) throw "User profile not found";

      final String courseId = userData['courseId'];
      final int semester = userData['currentSemester'] ?? 1;

      final activeSessionQuery = await firestore
          .collection('academic_sessions')
          .where('status', isEqualTo: 'Active')
          .limit(1)
          .get();

      if (activeSessionQuery.docs.isEmpty)
        throw "No active academic session found";
      final String sessionId = activeSessionQuery.docs.first.id;

      String? targetLabId;
      if (qrData.startsWith('{')) {
        final Map<String, dynamic> data = jsonDecode(qrData);
        targetLabId = data['labId'];
      } else {
        throw "Invalid QR Format! Please scan the official Lab QR.";
      }

      _updateStatus("Verifying Schedule...", Colors.teal);
      final now = DateTime.now();
      String? currentSubjectId;
      String? uniqueKey;
      bool labFoundForToday = false;

      final subjectsQuery = await firestore
          .collection('subjects')
          .where('courseId', isEqualTo: courseId)
          .where('semester', isEqualTo: semester)
          .where('sessionId', isEqualTo: sessionId)
          .get();

      for (var doc in subjectsQuery.docs) {
        final subData = doc.data();
        final List schedule = subData['schedule'] ?? [];

        for (var item in schedule) {
          final DateTime sessionDate = (item['date'] as Timestamp).toDate();

          if (DateUtils.isSameDay(sessionDate, now)) {
            labFoundForToday = true;

            final String startTimeStr = item['startTime'];
            final String endTimeStr = item['endTime'];
            final sParts = startTimeStr.split(':');
            final eParts = endTimeStr.split(':');

            final DateTime labStartTime = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(sParts[0]),
              int.parse(sParts[1]),
            );
            final DateTime labEndTime = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(eParts[0]),
              int.parse(eParts[1]),
            );

            final DateTime windowStart = labEndTime.subtract(
              const Duration(minutes: 15),
            );

            if (now.isAfter(labStartTime) && now.isBefore(labEndTime)) {
              if (now.isAfter(windowStart)) {
                currentSubjectId = doc.id;
                uniqueKey =
                    "ATT_${user.uid}_${currentSubjectId}_${DateFormat('yyyyMMdd').format(now)}";
                break;
              } else {
                final int waitMins = windowStart.difference(now).inMinutes;
                throw "Too Early! Attendance window opens in $waitMins minutes.";
              }
            }
          }
        }
        if (currentSubjectId != null) break;
      }

      if (!labFoundForToday) throw "No Lab scheduled for your batch today.";
      if (currentSubjectId == null)
        throw "No active Lab session found at this time.";

      _updateStatus("Verifying Location...", Colors.blue);
      final studentPosition = await _determinePosition();

      final labDoc = await firestore.collection('labs').doc(targetLabId).get();
      if (!labDoc.exists) throw "Invalid Lab QR!";

      final labData = labDoc.data()!;
      double distanceInMeters = Geolocator.distanceBetween(
        studentPosition.latitude,
        studentPosition.longitude,
        labData['latitude'],
        labData['longitude'],
      );

      if (distanceInMeters > 50.0) {
        throw "Out of Range! You must be inside the Lab to mark attendance.";
      }

      _updateStatus("Marking Attendance...", Colors.orange);
      await _markAttendanceInFirestore(
        user.uid,
        sessionId,
        currentSubjectId!,
        uniqueKey!,
        studentPosition,
      );

      _showSuccessScreen();
    } catch (e) {
      _showFailureScreen(e.toString());
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw "Location services are disabled.";
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw "Location permissions are denied";
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw "Location permissions are permanently denied";
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _markAttendanceInFirestore(
    String uid,
    String sessionId,
    String subjectId,
    String uniqueKey,
    Position position,
  ) async {
    final firestore = FirebaseFirestore.instance;

    final today = DateTime.now();
    final dateKey = "${today.year}-${today.month}-${today.day}";

    final existingQuery = await firestore
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .where('uniqueSessionKey', isEqualTo: uniqueKey)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      throw "Attendance already marked for this session!";
    }

    await firestore.collection('attendance').add({
      'uid': uid,
      'sessionId': sessionId,
      'subjectId': subjectId,
      'uniqueSessionKey': uniqueKey,
      'timestamp': FieldValue.serverTimestamp(),
      'dateKey': dateKey,
      'status': 'Present',
      'location': {'lat': position.latitude, 'lng': position.longitude},
      'deviceInfo': 'Android/iOS',
      'method': 'QR_SCAN',
    });
  }

  void _updateStatus(String msg, Color color) {
    if (mounted) {
      setState(() {
        _statusMessage = msg;
        _statusColor = color;
      });
    }
  }

  void _showSuccessScreen() {
    if (mounted) {
      setState(() {
        _isSuccess = true;
        _isProcessing = false;
      });
    }
  }

  void _showFailureScreen(String error) {
    if (mounted) {
      setState(() {
        _isSuccess = false;
        _isProcessing = false;
        _statusMessage = error;
      });

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 60,
              ),
              const SizedBox(height: 16),
              const Text(
                "Scan Failed",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error.replaceAll("Exception: ", ""),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _isSuccess = false;
                      _statusMessage = "Align QR code within the frame";
                      _statusColor = Colors.white;
                    });
                    _controller.start();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Try Again",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return _buildSuccessView();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
            errorBuilder: (context, error) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Camera Error: ${error.errorCode}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          CustomPaint(
            painter: ScannerOverlayPainter(
              borderColor: _isProcessing
                  ? _statusColor
                  : Theme.of(context).primaryColor,
              borderRadius: 24,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 280,
            ),
            child: Container(),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _controller.toggleTorch(),
                        icon: ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (context, state, child) {
                            final bool isTorchOn =
                                state.torchState == TorchState.on;
                            return Icon(
                              isTorchOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color: isTorchOn ? Colors.yellow : Colors.white,
                              size: 28,
                            );
                          },
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Container(
                  margin: const EdgeInsets.only(bottom: 50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isProcessing)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _statusColor,
                            ),
                          ),
                        ),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.8, end: 1.2),
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      onEnd: () {},
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
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

  Widget _buildSuccessView() {
    return Scaffold(
      backgroundColor: const Color(0xFF10B981),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF10B981),
                      size: 80,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              "Attendance Marked!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Successfully recorded for today",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
              child: const Text(
                "Back to Dashboard",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  ScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaSize = cutOutSize;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2;
    final double right = left + scanAreaSize;
    final double bottom = top + scanAreaSize;

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, top, right, bottom),
          Radius.circular(borderRadius),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(backgroundPath, backgroundPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();

    path.moveTo(left, top + borderLength);
    path.lineTo(left, top + borderRadius);
    path.quadraticBezierTo(left, top, left + borderRadius, top);
    path.lineTo(left + borderLength, top);

    path.moveTo(right - borderLength, top);
    path.lineTo(right - borderRadius, top);
    path.quadraticBezierTo(right, top, right, top + borderRadius);
    path.lineTo(right, top + borderLength);

    path.moveTo(right, bottom - borderLength);
    path.lineTo(right, bottom - borderRadius);
    path.quadraticBezierTo(right, bottom, right - borderRadius, bottom);
    path.lineTo(right - borderLength, bottom);

    path.moveTo(left + borderLength, bottom);
    path.lineTo(left + borderRadius, bottom);
    path.quadraticBezierTo(left, bottom, left, bottom - borderRadius);
    path.lineTo(left, bottom - borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
