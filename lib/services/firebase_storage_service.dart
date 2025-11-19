import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();

  /// Upload an avatar image for the current user (works on all platforms)
  /// Returns the download URL if successful, null otherwise
  static Future<String?> uploadUserAvatar(XFile imageFile) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found');
        return null;
      }

      // Create a reference to the avatar location
      final String fileName =
          'avatars/${user.uid}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child(fileName);

      UploadTask uploadTask;

      // For all platforms, use bytes upload since it's universal
      final bytes = await imageFile.readAsBytes();
      uploadTask = ref.putData(
          bytes,
          SettableMetadata(
            contentType: 'image/jpeg',
          ));

      final TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Avatar uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  /// Upload avatar from Uint8List (for web platform)
  static Future<String?> uploadUserAvatarFromBytes(
      Uint8List imageBytes, String fileName) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found');
        return null;
      }

      // Create a reference to the avatar location
      final String fullFileName =
          'avatars/${user.uid}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child(fullFileName);

      // Upload the bytes
      final UploadTask uploadTask = ref.putData(
          imageBytes,
          SettableMetadata(
            contentType: 'image/jpeg',
          ));
      final TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Avatar uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading avatar from bytes: $e');
      return null;
    }
  }

  /// Pick an image from gallery or camera
  static Future<XFile?> pickImage(
      {ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Show image source selection dialog (adapted for web/mobile)
  static Future<XFile?> showImageSourceDialog(BuildContext context) async {
    if (kIsWeb) {
      // On web, only gallery is available
      return await pickImage(source: ImageSource.gallery);
    }

    return showDialog<XFile?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Avatar-Bild auswählen'),
          content: const Text('Woher möchten Sie Ihr Profilbild auswählen?'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final image = await pickImage(source: ImageSource.camera);
                Navigator.of(context).pop(image);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 8),
                  Text('Kamera'),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final image = await pickImage(source: ImageSource.gallery);
                Navigator.of(context).pop(image);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library),
                  SizedBox(width: 8),
                  Text('Galerie'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
          ],
        );
      },
    );
  }

  /// Delete user's avatar
  static Future<bool> deleteUserAvatar(String downloadUrl) async {
    try {
      final Reference ref = FirebaseStorage.instance.refFromURL(downloadUrl);
      await ref.delete();
      debugPrint('Avatar deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting avatar: $e');
      return false;
    }
  }

  /// Get user's avatar folder reference for listing all avatars
  static Reference getUserAvatarFolder() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }
    return _storage.ref().child('avatars/${user.uid}');
  }
}
