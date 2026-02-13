import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../../utils/custom_toast.dart';
import '../../widgets/geometric_loader.dart';

class QRGeneratorScreen extends StatefulWidget {
  const QRGeneratorScreen({super.key});

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedLabId;
  String _selectedLabName = 'Select Lab';
  int _totalPCs = 0;

  Future<void> _saveQrToGallery(String data, String pcNumber) async {
    try {
      if (await Permission.photos.request().isDenied &&
          await Permission.storage.request().isDenied) {
        CustomToast.show(context, "Permission Denied!", isError: true);
        return;
      }

      final qrValidationResult = QrValidator.validate(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final size = 1024.0;
        final painter = QrPainter.withQr(
          qr: qrCode,
          color: const Color(0xFF000000),
          emptyColor: const Color(0xFFFFFFFF),
          gapless: true,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

        painter.paint(canvas, Size(size, size));

        final textStyle = ui.TextStyle(
          color: const Color(0xFF000000),
          fontSize: size * 0.12,
          fontWeight: FontWeight.bold,
        );

        final paragraphStyle = ui.ParagraphStyle(textAlign: TextAlign.center);
        final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
          ..pushStyle(textStyle)
          ..addText(pcNumber.replaceFirst("PC-", ""));

        final paragraph = paragraphBuilder.build()
          ..layout(ui.ParagraphConstraints(width: size * 0.3));
        final centerBoxSize = size * 0.22;
        final paint = Paint()..color = const Color(0xFFFFFFFF);
        final rRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size / 2, size / 2),
            width: centerBoxSize,
            height: centerBoxSize * 0.7,
          ),
          Radius.circular(size * 0.02),
        );
        canvas.drawRRect(rRect, paint);
        canvas.drawParagraph(
          paragraph,
          Offset((size - paragraph.width) / 2, (size - paragraph.height) / 2),
        );

        final picture = recorder.endRecording();
        final img = await picture.toImage(size.toInt(), size.toInt());
        final ByteData? byteData = await img.toByteData(
          format: ui.ImageByteFormat.png,
        );
        final Uint8List pngBytes = byteData!.buffer.asUint8List();

        final result = await ImageGallerySaverPlus.saveImage(
          pngBytes,
          name: "Entrixo_${_selectedLabName}_$pcNumber",
          quality: 100,
        );

        if (mounted && result['isSuccess']) {
          CustomToast.show(context, "$pcNumber QR Saved with Label! 📸");
        }
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, "Error: $e", isError: true);
    }
  }

  void _showLabSelector() {
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
                  "Select Lab",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('labs')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: GeometricLoader(size: 30, isDarkMode: false),
                      );
                    }
                    final labs = snapshot.data!.docs;

                    if (labs.isEmpty) {
                      return const Center(
                        child: Text("No Labs Found. Please add a lab first."),
                      );
                    }

                    return ListView.separated(
                      controller: controller,
                      itemCount: labs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 24),
                      itemBuilder: (context, index) {
                        final data = labs[index].data() as Map<String, dynamic>;
                        final isSelected = _selectedLabId == labs[index].id;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.computer,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey,
                            ),
                          ),
                          title: Text(
                            data['labName'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.black,
                            ),
                          ),
                          subtitle: Text("${data['totalPCs']} Computers"),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).primaryColor,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedLabId = labs[index].id;
                              _selectedLabName = data['labName'];
                              _totalPCs = data['totalPCs'];
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          "QR Generator",
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
                GestureDetector(
                  onTap: _showLabSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.hub_rounded, color: theme.primaryColor),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Selected Lab",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _selectedLabName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedLabId != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Showing $_totalPCs unique QR codes for ${_selectedLabName}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: _selectedLabId == null
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: size.width > 600 ? 3 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: _totalPCs,
                    itemBuilder: (context, index) {
                      final pcNumber =
                          "PC-${(index + 1).toString().padLeft(2, '0')}";
                      final qrData = jsonEncode({
                        'labId': _selectedLabId,
                        'pcId': pcNumber,
                        'labName': _selectedLabName,
                        'type': 'static_pc_qr',
                      });

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Header PC Number
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                pcNumber,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: theme.primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // QR Image
                            QrImageView(
                              data: qrData,
                              version: QrVersions.auto,
                              size: 100.0,
                              foregroundColor: const Color(0xFF1A1A1A),
                              gapless: false,
                            ),

                            const SizedBox(height: 12),

                            // Download Button (Premium Look)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _saveQrToGallery(qrData, pcNumber),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.download_rounded,
                                        size: 16,
                                        color: Colors.grey[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Save",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
              child: const Icon(
                Icons.qr_code_scanner_rounded,
                size: 48,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Lab Selected",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Please select a lab from the top menu to generate QR codes for all computers.",
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
