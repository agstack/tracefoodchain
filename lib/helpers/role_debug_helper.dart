import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';

/// Debug-Hilfsklasse für Rollenverwaltung
/// Hilft bei der Diagnose von Problemen mit der Benutzerrollenverwaltung
class RoleDebugHelper {
  /// Zeigt umfassende Debug-Informationen zur aktuellen Benutzerrolle
  static Future<Map<String, dynamic>> getFullUserRoleDebugInfo() async {
    final debugInfo = <String, dynamic>{};

    // Firebase Auth Status
    final currentUser = FirebaseAuth.instance.currentUser;
    debugInfo['firebaseUser'] = {
      'uid': currentUser?.uid,
      'email': currentUser?.email,
      'isLoggedIn': currentUser != null,
    };

    // appUserDoc Status
    debugInfo['appUserDoc'] = {
      'isNull': appUserDoc == null,
      'hasData': appUserDoc != null,
      'keys': appUserDoc?.keys.toList(),
    };

    if (appUserDoc != null) {
      // Detaillierte appUserDoc Analyse
      final userRole = getSpecificPropertyfromJSON(appUserDoc!, "userRole");
      debugInfo['appUserDocDetails'] = {
        'userRole': userRole,
        'hasIdentity': appUserDoc!.containsKey('identity'),
        'identity': appUserDoc!.containsKey('identity')
            ? appUserDoc!['identity']
            : null,
        'hasTemplate': appUserDoc!.containsKey('template'),
        'template': appUserDoc!.containsKey('template')
            ? appUserDoc!['template']
            : null,
      };
    }

    // Cloud-Rolle direkt aus Firestore laden
    if (currentUser != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('TFC_objects')
            .doc(currentUser.uid)
            .get();

        debugInfo['firestoreUser'] = {
          'exists': userDoc.exists,
          'data': userDoc.exists ? userDoc.data() : null,
        };

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final cloudRole = getSpecificPropertyfromJSON(userData, "userRole");
          debugInfo['firestoreUser']['userRole'] = cloudRole;
        }
      } catch (e) {
        debugInfo['firestoreError'] = e.toString();
      }
    }

    return debugInfo;
  }

  /// Versucht appUserDoc aus Firestore zu reparieren
  static Future<bool> repairAppUserDoc() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('❌ No Firebase user logged in');
      return false;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        // Setze appUserDoc mit den Firestore-Daten
        appUserDoc = Map<String, dynamic>.from(userDoc.data()!);
        debugPrint('✅ appUserDoc successfully repaired from Firestore');

        // Debug: Zeige die reparierte Rolle
        final role = getSpecificPropertyfromJSON(appUserDoc!, "userRole");
        debugPrint('🔧 Repaired user role: $role');

        return true;
      } else {
        debugPrint('❌ User document not found in Firestore');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error repairing appUserDoc: $e');
      return false;
    }
  }

  /// Erstellt eine manuelle Rollenzuweisung (nur für Debugging/Notfälle)
  static Future<void> manualRoleAssignment(
      String targetUID, String newRole) async {
    try {
      await FirebaseFirestore.instance
          .collection('TFC_objects')
          .doc(targetUID)
          .update({
        'userRole': newRole,
        'lastRoleUpdate': FieldValue.serverTimestamp(),
        'roleUpdateMethod': 'manual_debug_assignment',
      });

      debugPrint('✅ Manual role assignment completed: $targetUID -> $newRole');
    } catch (e) {
      debugPrint('❌ Manual role assignment failed: $e');
      rethrow;
    }
  }

  /// Zeigt alle verfügbaren Benutzer mit ihren aktuellen Rollen
  static Future<List<Map<String, dynamic>>> getAllUsersWithRoles() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .where('template.RALType', isEqualTo: 'user')
          .get();

      final users = <Map<String, dynamic>>[];
      for (final doc in querySnapshot.docs) {
        final userData = doc.data();
        final role = getSpecificPropertyfromJSON(userData, "userRole");
        final email = getSpecificPropertyfromJSON(userData, "email");

        users.add({
          'uid': doc.id,
          'role': role,
          'email': email,
          'hasData': userData.isNotEmpty,
        });
      }

      return users;
    } catch (e) {
      debugPrint('Error fetching all users: $e');
      return [];
    }
  }
}
