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
      final UserCredential credential = await authRepository.verifyOTP(
        verId,
        otp,
      );
      final User? user = credential.user;

      if (user == null) throw Exception("User not found after verification");

      bool isSetupDone = false;

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
          final data = manualDoc.data();

          await userDocRef.set({
            ...data,
            'uid': user.uid,
            'isManualEntry': false,
            'isPreApproved': false,
            'mergedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await manualDoc.reference.delete();
          isSetupDone = data['isSetupCompleted'] ?? false;
        } else {
          await authRepository.saveUserData(role: role, user: user);
          isSetupDone = false;
        }
      }

      state = false;
      onResult(isSetupDone);
    } catch (e) {
      state = false;
      debugPrint("❌ Login Error: $e");
      String errorMessage = "Invalid OTP";
      if (e is FirebaseAuthException) {
        if (e.code == 'session-expired') {
          errorMessage = "OTP Expired. Resend again.";
        }
        if (e.code == 'invalid-verification-code') {
          errorMessage = "Wrong OTP. Check again.";
        }
      }

      if (context.mounted) {
        CustomToast.show(context, errorMessage, isError: true);
      }
    }
  }

  Future<void> logout(BuildContext context) async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _auth.signOut();
      await prefs.remove('user_role');
      await prefs.remove('setup_done');
      await prefs.setBool('isFirstTime', false);

      state = false;

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeIn,
                    ),
                    child: child,
                  );
                },
          ),
          (route) => false,
        );

        CustomToast.show(context, "Logged out successfully");
      }
    } catch (e) {
      state = false;
      debugPrint("❌ Logout Error: $e");
      if (context.mounted) {
        CustomToast.show(
          context,
          "Logout Failed: Please try again",
          isError: true,
        );
      }
    }
  }
}
