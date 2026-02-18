import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
  ),
);

class AuthRepository {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  AuthRepository({required this.auth, required this.firestore});

  Future<void> verifyPhoneNumber(
    String phoneNumber, {
    required Function(String) onCodeSent,
    required Function(FirebaseAuthException) onError,
  }) async {
    await auth.verifyPhoneNumber(
      phoneNumber: '+91$phoneNumber',
      verificationCompleted: (PhoneAuthCredential credential) async {
        await auth.signInWithCredential(credential);
      },
      verificationFailed: onError,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserCredential> verifyOTP(String verificationId, String otp) async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    return await auth.signInWithCredential(credential);
  }

  Future<String> getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "unknown_ios_device";
    }
  }

  Future<void> saveUserData({required String role, required User user}) async {
    final deviceId = await getDeviceId();
    final userDoc = await firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      await firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'phoneNumber': user.phoneNumber,
        'role': role,
        'deviceId': deviceId,
        'isSetupCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
