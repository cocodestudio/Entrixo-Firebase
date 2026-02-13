import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;

class ProfileState {
  final bool isLoading;
  final File? pickedImage;
  final String? profileUrl;
  final String name;
  final String email;
  final String role;

  ProfileState({
    this.isLoading = false,
    this.pickedImage,
    this.profileUrl,
    this.name = '',
    this.email = '',
    this.role = 'student',
  });

  ProfileState copyWith({
    bool? isLoading,
    File? pickedImage,
    String? profileUrl,
    String? name,
    String? email,
    String? role,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      pickedImage: pickedImage ?? this.pickedImage,
      profileUrl: profileUrl ?? this.profileUrl,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }
}

final userStreamProvider = StreamProvider<ProfileState>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(ProfileState());

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        if (doc.exists) {
          final data = doc.data()!;
          return ProfileState(
            name: data['name'] ?? '',
            email: data['email'] ?? '',
            profileUrl: data['profilePic'] ?? '',
            role: data['role'] ?? 'student',
            isLoading: false,
          );
        }
        return ProfileState();
      });
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
      final streamData = ref.watch(userStreamProvider).value ?? ProfileState();
      return ProfileController(streamData);
    });

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(ProfileState initialState) : super(initialState);

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  Future<void> pickImage(dynamic context) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        state = state.copyWith(pickedImage: File(image.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> saveProfile(
    dynamic context,
    String newName,
    String newEmail, {
    VoidCallback? onSuccess,
    Function(String)? onError,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    state = state.copyWith(isLoading: true);

    try {
      String? downloadUrl = state.profileUrl;

      if (state.pickedImage != null) {
        final dir = await path_provider.getTemporaryDirectory();
        final targetPath = p.join(dir.absolute.path, "${user.uid}_temp.jpg");

        XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
          state.pickedImage!.absolute.path,
          targetPath,
          quality: 70,
          format: CompressFormat.jpeg,
        );

        if (compressedFile != null) {
          final ref = _storage
              .ref()
              .child('user_profiles')
              .child('${user.uid}.jpg');

          await ref.putFile(File(compressedFile.path));
          downloadUrl = await ref.getDownloadURL();
        }
      }
      if (!mounted) return;

      await _firestore.collection('users').doc(user.uid).update({
        'name': newName,
        'email': newEmail,
        'profilePic': downloadUrl,
      });

      if (!mounted) return;

      state = state.copyWith(
        isLoading: false,
        profileUrl: downloadUrl,
        name: newName,
        email: newEmail,
        pickedImage: null,
      );

      if (onSuccess != null) onSuccess();
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
        if (onError != null) onError(e.toString());
      }
    }
  }
}
