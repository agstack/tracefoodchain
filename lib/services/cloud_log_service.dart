import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:trace_foodchain_app/constants.dart';

/// Levels for cloud log entries.
class CloudLogLevel {
  static const String info = 'INFO';
  static const String warn = 'WARN';
  static const String error = 'ERROR';
}

/// Service that writes app-startup logs to Firestore collection `TFC_cloudlog`.
///
/// Structure:
/// ```
/// TFC_cloudlog/
///   {userId}/                         ← User document (created once on first login)
///     email: String
///     createdAt: Timestamp
///     lastSeen: Timestamp
///     sessions/                        ← Subcollection
///       {sessionId}/                   ← ISO-8601-formatted session ID per app start
///         sessionId: String
///         startTime: Timestamp
///         platform: String
///         appVersion: String
///         endTime: Timestamp?
///         endDestination: String?       ← "home_screen" | "registrar_screen"
///         logs/                         ← Subcollection
///           {autoId}/                   ← Individual log entries
///             time: Timestamp
///             level: "INFO" | "WARN" | "ERROR"
///             message: String
///             data: Map?
/// ```
///
/// Only logs when a session has been started (requires online connectivity).
/// All internal errors are swallowed — this service must never affect app stability.
class CloudLogService {
  String? _userId;
  String? _sessionId;
  bool _sessionStarted = false;

  // ─── Session ID ────────────────────────────────────────────────────────────

  /// Generates and stores an ISO-8601-based session ID.
  /// Call this as early as possible during app startup, even before knowing
  /// the userId or connectivity state.
  String generateSessionId() {
    final now = DateTime.now().toUtc();
    // Format: "2026-05-07T10-30-00-000" (colons replaced with dashes for Firestore doc ID)
    final id = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}T'
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}-'
        '${now.second.toString().padLeft(2, '0')}-'
        '${now.millisecond.toString().padLeft(3, '0')}';
    _sessionId = id;
    return id;
  }

  /// Sets an already-generated session ID (e.g. passed from AuthScreen to SplashScreen).
  void setSessionId(String id) {
    _sessionId = id;
  }

  String? get sessionId => _sessionId;
  bool get isSessionStarted => _sessionStarted;

  // ─── Session Lifecycle ─────────────────────────────────────────────────────

  /// Creates / updates the user document and starts a new session document.
  /// Call this once after authentication and connectivity are confirmed.
  ///
  /// Idempotent: calling it again with the same [userId] and active [_sessionId]
  /// only updates `lastSeen` on the user document.
  Future<void> startSession(String userId, {String? email}) async {
    if (_sessionId == null) return;
    if (!_isFirestoreAvailable()) return;

    // Fresh connectivity check – do not rely on AppState.isConnected
    // which may not be up-to-date at the moment of the call.
    try {
      final results = await Connectivity().checkConnectivity();
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (!isOnline) {
        debugPrint('☁️ [CloudLogService] Offline – skipping session start');
        return;
      }
    } catch (_) {
      // Can't determine connectivity – skip logging
      return;
    }

    try {
      _userId = userId;

      final firestore = FirebaseFirestore.instance;
      final userDocRef = firestore.collection('TFC_cloudlog').doc(userId);

      // Create or update user document (merge so we never overwrite existing data)
      final userPayload = <String, dynamic>{
        'lastSeen': FieldValue.serverTimestamp(),
      };
      if (email != null) userPayload['email'] = email;

      await userDocRef.set(
        {
          ...userPayload,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Create session document
      final sessionDocRef = userDocRef.collection('sessions').doc(_sessionId);

      final platformName = _getPlatformName();
      await sessionDocRef.set({
        'sessionId': _sessionId,
        'startTime': FieldValue.serverTimestamp(),
        'platform': platformName,
        'appVersion': APP_VERSION,
      });

      _sessionStarted = true;
      debugPrint('☁️ [CloudLogService] Session started: $_sessionId');
    } catch (e) {
      debugPrint('☁️ [CloudLogService] Failed to start session: $e');
      // Never rethrow — logging must not break the app
    }
  }

  /// Marks the session as finished with [destination] ("home_screen" or "registrar_screen").
  Future<void> closeSession(String destination) async {
    if (!_sessionStarted || _userId == null || _sessionId == null) return;
    if (!_isFirestoreAvailable()) return;

    try {
      await FirebaseFirestore.instance
          .collection('TFC_cloudlog')
          .doc(_userId)
          .collection('sessions')
          .doc(_sessionId)
          .update({
        'endTime': FieldValue.serverTimestamp(),
        'endDestination': destination,
      });
      debugPrint('☁️ [CloudLogService] Session closed → $destination');
    } catch (e) {
      debugPrint('☁️ [CloudLogService] Failed to close session: $e');
    }
  }

  // ─── Logging ───────────────────────────────────────────────────────────────

  /// Writes a log entry into the current session's `logs` subcollection.
  /// Silently ignored if no session is active or the device is offline.
  Future<void> log(
    String level,
    String message, {
    Map<String, dynamic>? data,
  }) async {
    if (!_sessionStarted || _userId == null || _sessionId == null) return;
    if (!_isFirestoreAvailable()) return;

    try {
      final now = DateTime.now().toUtc();
      // Use ISO-8601-formatted timestamp as document ID so logs are
      // sorted chronologically by default in the Firestore console.
      final docId = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}T'
          '${now.hour.toString().padLeft(2, '0')}-'
          '${now.minute.toString().padLeft(2, '0')}-'
          '${now.second.toString().padLeft(2, '0')}-'
          '${now.millisecond.toString().padLeft(3, '0')}';

      final entry = <String, dynamic>{
        'time': FieldValue.serverTimestamp(),
        'level': level,
        'message': message,
      };
      if (data != null && data.isNotEmpty) entry['data'] = data;

      await FirebaseFirestore.instance
          .collection('TFC_cloudlog')
          .doc(_userId)
          .collection('sessions')
          .doc(_sessionId)
          .collection('logs')
          .doc(docId)
          .set(entry);

      debugPrint('☁️ [CloudLog] [$level] $message');
    } catch (e) {
      debugPrint(
          '☁️ [CloudLogService] Failed to write log [$level] $message: $e');
    }
  }

  Future<void> info(String message, {Map<String, dynamic>? data}) =>
      log(CloudLogLevel.info, message, data: data);

  Future<void> warn(String message, {Map<String, dynamic>? data}) =>
      log(CloudLogLevel.warn, message, data: data);

  Future<void> error(String message, {Map<String, dynamic>? data}) =>
      log(CloudLogLevel.error, message, data: data);

  // ─── Reset ─────────────────────────────────────────────────────────────────

  /// Resets the service state. Call on user logout.
  void reset() {
    _userId = null;
    _sessionId = null;
    _sessionStarted = false;
    debugPrint('☁️ [CloudLogService] Reset');
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  bool _isFirestoreAvailable() {
    try {
      FirebaseFirestore.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  String _getPlatformName() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'unknown';
  }
}
