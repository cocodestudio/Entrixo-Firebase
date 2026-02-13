import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../utils/custom_toast.dart';
import '../../widgets/geometric_loader.dart';

class AcademicEquipScreen extends StatefulWidget {
  const AcademicEquipScreen({super.key});

  @override
  State<AcademicEquipScreen> createState() => _AcademicEquipScreenState();
}

class _AcademicEquipScreenState extends State<AcademicEquipScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  final TextEditingController _labNameController = TextEditingController();
  final TextEditingController _pcCountController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _longController = TextEditingController();

  @override
  void dispose() {
    _labNameController.dispose();
    _pcCountController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }

  Future<void> _addLab() async {
    if (_labNameController.text.isEmpty || _pcCountController.text.isEmpty) {
      CustomToast.show(
        context,
        "Please fill Lab Name and PC Count",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final docRef = _firestore.collection('labs').doc();
      await docRef.set({
        'labId': docRef.id,
        'labName': _labNameController.text.trim(),
        'totalPCs': int.parse(_pcCountController.text.trim()),
        'latitude': double.tryParse(_latController.text.trim()) ?? 0.0,
        'longitude': double.tryParse(_longController.text.trim()) ?? 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _labNameController.clear();
      _pcCountController.clear();
      _latController.clear();
      _longController.clear();

      if (mounted) CustomToast.show(context, "Lab added successfully!");
    } catch (e) {
      CustomToast.show(context, "Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
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
            "Lam Management",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Add New Lab"),
              const SizedBox(height: 20),
              _buildInputCard(
                controller: _labNameController,
                label: "Lab Name (e.g. Lab 101)",
                icon: Icons.computer_rounded,
              ),
              const SizedBox(height: 16),
              _buildInputCard(
                controller: _pcCountController,
                label: "Total Computers",
                icon: Icons.numbers_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInputCard(
                      controller: _latController,
                      label: "Latitude",
                      icon: Icons.location_on_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputCard(
                      controller: _longController,
                      label: "Longitude",
                      icon: Icons.location_on_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addLab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const GeometricLoader(size: 20, isDarkMode: false)
                      : const Text(
                          "Create Lab & PC Entries",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
              _buildSectionTitle("Existing Labs"),
              const SizedBox(height: 16),
              _buildLabsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Colors.grey,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildInputCard({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
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
      child: TextField(
        style: TextStyle(fontSize: 16),
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 14),
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLabsList() {
    return StreamBuilder<QuerySnapshot>(
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

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: labs.length,
          itemBuilder: (context, index) {
            final data = labs[index].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.lan_outlined, color: Colors.blue),
                title: Text(
                  data['labName'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "${data['totalPCs']} Computers | Loc: ${data['latitude'].toStringAsFixed(4)}, ${data['longitude'].toStringAsFixed(4)}",
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_sweep_outlined,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _firestore
                      .collection('labs')
                      .doc(labs[index].id)
                      .delete(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
