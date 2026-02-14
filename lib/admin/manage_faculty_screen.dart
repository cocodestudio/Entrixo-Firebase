import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/custom_toast.dart';

class ManageFacultyScreen extends StatefulWidget {
  const ManageFacultyScreen({super.key});

  @override
  State<ManageFacultyScreen> createState() => _ManageFacultyScreenState();
}

class _ManageFacultyScreenState extends State<ManageFacultyScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isProcessing = false;
  bool _isFocused = false;
  Map<String, dynamic>? _userData;
  String? _userDocId;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    _focusNode.unfocus();
    if (_phoneController.text.trim().length != 10) {
      _showCustomToast("Please enter a valid 10-digit number", false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _userData = null;
    });

    try {
      final formattedPhone = "+91${_phoneController.text.trim()}";

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: formattedPhone)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _userDocId = querySnapshot.docs.first.id;
          _userData = querySnapshot.docs.first.data();
        });
      } else {
        setState(() {
          _errorMessage = "No user found with this number.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error searching user";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserRole(bool makeAdmin) async {
    if (_userDocId == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final newRole = makeAdmin ? 'admin' : 'student';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userDocId)
          .update({'role': newRole});

      setState(() {
        _userData!['role'] = newRole;
      });

      if (mounted) {
        _showCustomToast(
          makeAdmin ? "Promoted to Faculty" : "Access Revoked",
          true,
        );
      }
    } catch (e) {
      if (mounted) {
        _showCustomToast("Operation failed", false);
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showCustomToast(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess
            ? const Color(0xFF00D26A)
            : const Color(0xFFFF4B4B),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
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
            "Manage Faculty",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddAdminScreen()),
            );
          },
          backgroundColor: Colors.black,
          elevation: 5,
          icon: const Icon(Icons.add_moderator_rounded, color: Colors.white),
          label: const Text(
            "Add New Admin",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Manage Access",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Search user by phone number to manage role.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 25),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isFocused
                        ? Colors.black
                        : Colors.grey.withOpacity(0.1),
                    width: _isFocused ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A1A1A).withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                      ),
                      child: Text(
                        "+91",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchUser(),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(10),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter 10-digit number",
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _isLoading ? null : _searchUser,
                      child: Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.search_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage.isNotEmpty)
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_off_rounded,
                          size: 32,
                          color: Colors.red[300],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_userData != null) _buildUserCard(theme),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(ThemeData theme) {
    final bool isAdmin = _userData!['role'] == 'admin';
    final String name = _userData!['name'] ?? 'Unknown';
    final String email = _userData!['email'] ?? 'No Email';
    final String phone = _userData!['phoneNumber'] ?? 'No Phone';
    final String? profileUrl = _userData!['profileUrl'];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_userData!['role']),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
                image: (profileUrl != null && profileUrl.isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(profileUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (profileUrl == null || profileUrl.isEmpty)
                  ? Container(
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 44,
                        color: theme.primaryColor,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              phone,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            Text(
              email,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Current Role",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? const Color(0xFF6366F1).withOpacity(0.1)
                          : const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isAdmin ? "FACULTY" : "STUDENT",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isAdmin
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF10B981),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () => _updateUserRole(!isAdmin),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAdmin
                      ? const Color(0xFFFEF2F2)
                      : theme.primaryColor,
                  elevation: isAdmin ? 0 : 8,
                  shadowColor: isAdmin
                      ? Colors.transparent
                      : theme.primaryColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: isAdmin
                        ? const BorderSide(color: Color(0xFFFEE2E2))
                        : BorderSide.none,
                  ),
                ),
                child: _isProcessing
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: isAdmin ? Colors.red : Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isAdmin
                                ? Icons.remove_circle_outline_rounded
                                : Icons.verified_user_rounded,
                            color: isAdmin ? Colors.red : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isAdmin
                                ? "Revoke Faculty Access"
                                : "Promote to Faculty",
                            style: TextStyle(
                              color: isAdmin ? Colors.red : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddAdminScreen extends StatefulWidget {
  const AddAdminScreen({super.key});

  @override
  State<AddAdminScreen> createState() => _AddAdminScreenState();
}

class _AddAdminScreenState extends State<AddAdminScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _createAdmin() async {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.length != 10) {
      _showCustomToast("Please fill all details correctly", false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formattedPhone = "+91$phone";
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: formattedPhone)
          .get();

      if (userQuery.docs.isNotEmpty) {
        _showCustomToast("User with this number already exists", false);
        setState(() => _isLoading = false);
        return;
      }

      await FirebaseFirestore.instance.collection('users').add({
        'name': name,
        'phoneNumber': formattedPhone,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'isPreApproved': true,
        'isSetupCompleted': true,
        'email': 'Pending Signup',
        'profileUrl': '',
      });

      if (mounted) {
        _showCustomToast("Admin Access Granted Successfully!", true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showCustomToast("Error creating admin: $e", false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCustomToast(String message, bool isSuccess) {
    CustomToast.show(
        context,
        message,
        isError: !isSuccess
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
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
            "Add New Admin",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        "Create Profile",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Enter details to pre-approve a new faculty member.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 25),
                      _buildLabel("Full Name"),
                      TextField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: "e.g. Dr. Rajesh Kumar",
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildLabel("Mobile Number"),
                      TextField(
                        controller: _phoneController,
                        focusNode: _phoneFocus,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(10),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black,
                          letterSpacing: 1,
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter 10-digit number",
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            letterSpacing: 0,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Text(
                              "+91",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.security_rounded,
                                  size: 16,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Security & Access Protocol".toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.grey[700],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildBulletPoint(
                              "This action creates a pre-approved profile.",
                            ),
                            const SizedBox(height: 8),
                            _buildBulletPoint(
                              "User must login with the exact +91 number.",
                            ),
                            const SizedBox(height: 8),
                            _buildBulletPoint(
                              "Profile completion will be skipped automatically.",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Grant Access",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: CircleAvatar(radius: 2, backgroundColor: Colors.grey[400]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
