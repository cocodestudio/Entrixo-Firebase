import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/custom_toast.dart';
import 'auth_repository.dart';
import 'login_screen.dart';

final authControllerProvider = StateNotifierProvider<AuthController, bool>((
  ref,
) {
  return AuthController(authRepository: ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<bool> {
  final AuthRepository authRepository;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthController({required this.authRepository}) : super(false);

  void sendOTP(
    BuildContext context,
    String phoneNumber,
    Function(String) onSent,
  ) async {
    state = true;
    await authRepository.verifyPhoneNumber(
      phoneNumber,
      onCodeSent: (verId) {
        state = false;
        onSent(verId);
      },
      onError: (e) {
        state = false;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
      },
    );
  }

  void verifyAndLogin(
    BuildContext context,
    String verId,
    String otp,
    String role,
    Function(bool) onResult,
  ) async {
    state = true;
    try {
      await authRepository.verifyOTP(verId, otp);

      final User? user = _auth.currentUser;
      bool isSetupDone = false;

      if (user != null) {
        final userDocRef = _firestore.collection('users').doc(user.uid);
        final doc = await userDocRef.get();

        if (doc.exists) {
          isSetupDone = doc.data()?['isSetupCompleted'] ?? false;
        } else {
          final String loginPhone = user.phoneNumber ?? "";

          final preApprovedQuery = await _firestore
              .collection('users')
              .where('phoneNumber', isEqualTo: loginPhone)
              .get();

          if (preApprovedQuery.docs.isNotEmpty) {
            final manualDoc = preApprovedQuery.docs.first;
            final data = manualDoc.data() as Map<String, dynamic>;

            data['uid'] = user.uid;

            data['isManualEntry'] = false;
            data['isPreApproved'] = false;
            data['mergedAt'] = FieldValue.serverTimestamp();

            await userDocRef.set(data);
            await manualDoc.reference.delete();

            isSetupDone = data['isSetupCompleted'] ?? false;
          } else {
            await authRepository.saveUserData(role: role);
            isSetupDone = false;
          }
        }
      }

      state = false;
      onResult(isSetupDone);
    } catch (e) {
      debugPrint("❌ Login Error: $e");
      state = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
    }
  }

  Future<void> logout(BuildContext context) async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _auth.signOut();
      await prefs.clear();

      state = false;
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        CustomToast.show(context, "Logged out successfully");
      }
    } catch (e) {
      state = false;
      if (context.mounted) {
        CustomToast.show(context, "Logout Failed: $e", isError: true);
      }
    }
  }
}
