import 'package:flutter/foundation.dart';

/// Notifier um Profil-Updates global zu verbreiten
class ProfileUpdateNotifier {
  static final ProfileUpdateNotifier _instance =
      ProfileUpdateNotifier._internal();
  factory ProfileUpdateNotifier() => _instance;
  ProfileUpdateNotifier._internal();

  /// ValueNotifier um Profile-Updates zu signalisieren
  final ValueNotifier<DateTime> profileUpdateNotifier =
      ValueNotifier(DateTime.now());

  /// Meldet ein Profil-Update
  void notifyProfileUpdated() {
    profileUpdateNotifier.value = DateTime.now();
  }
}
