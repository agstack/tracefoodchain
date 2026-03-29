import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../l10n/app_localizations.dart';

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
  ///
  /// Separates the source-selection dialog from the actual image picking to
  /// avoid the double-pop problem where [Navigator.pop] is called once to
  /// close the dialog and then again (on an already-orphaned context) to
  /// return the result, silently popping the parent route instead.
  static Future<XFile?> showImageSourceDialog(BuildContext context) async {
    if (kIsWeb) {
      // On web, only gallery is available
      return await pickImage(source: ImageSource.gallery);
    }

    final l10n = AppLocalizations.of(context)!;

    // Step 1: let the user pick a source (camera / gallery).  The dialog
    // closes and only returns an ImageSource enum value — no picking yet.
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.selectImageSource,
            style: const TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(ImageSource.camera),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt),
                const SizedBox(width: 8),
                Text(l10n.fromCamera),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(ImageSource.gallery),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library),
                const SizedBox(width: 8),
                Text(l10n.fromGallery),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel,
                style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );

    if (source == null) return null;

    // Step 2: pick the image only after the dialog is fully gone.  This
    // ensures the camera/gallery intent is launched from a clean state and
    // the result is returned correctly on all devices.
    return await pickImage(source: source);
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
