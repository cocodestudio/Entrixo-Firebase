import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'auth_repository.dart';

final authControllerProvider = StateNotifierProvider<AuthController, bool>((
  ref,
) {
  return AuthController(authRepository: ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<bool> {
  final AuthRepository authRepository;

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
    VoidCallback onSuccess,
  ) async {
    state = true;
    try {
      await authRepository.verifyOTP(verId, otp);
      await authRepository.saveUserData(role: role);
      state = false;
      onSuccess();
    } catch (e) {
      state = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
    }
  }
}
