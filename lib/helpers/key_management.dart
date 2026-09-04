import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trace_foodchain_app/main.dart';

/// Manages the signing keypair.
///
/// The keypair is PER USER, not per device. Storing it under one fixed name
/// meant a second user logging in on the same device silently reused the first
/// user's private key: their methods were signed with a key the cloud has not
/// registered for them, so every push failed with an invalid signature - while
/// the app reported success.
///
/// It also breaks the security model. Conflict resolution in the cloud rests on
/// "a signature by another user proves the payload was not manipulated, because
/// this client has no access to that user's private key". A shared key makes
/// that argument false.
class KeyManager {
  final _storage = const FlutterSecureStorage();

  /// Pre-multi-user storage location. Migrated once, then removed.
  static const String _legacyStorageKey = 'private_key';

  String _storageKeyFor(String uid) => 'private_key_$uid';

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// True when the public key of the locally stored keypair could not be
  /// (re-)sent to the cloud on the last attempt - typically because the device
  /// was offline. Signing keeps working; the registration is retried as soon as
  /// connectivity is back (see [retryPendingPublicKeyRegistration]).
  bool get publicKeyRegistrationPending => _publicKeyRegistrationPending;
  bool _publicKeyRegistrationPending = false;

  /// Makes sure the signed-in user has their own keypair AND - best effort -
  /// that the matching public key is registered in the cloud.
  ///
  /// Re-registering on every login is deliberate: a key that exists locally but
  /// never reached the cloud (failed request, app killed, user switch) is
  /// exactly the failure that makes every later push fail on the signature
  /// check. Re-sending is cheap and repairs it silently.
  ///
  /// A FAILED re-registration must NOT disable signing though. The private key
  /// is on the device, so signing works offline - and the app is built to be
  /// used offline. Treating the failed upload as "no secure communication"
  /// locked users out of the app entirely after they had started it once
  /// without network coverage. The attempt is therefore remembered and retried
  /// when the device is online again.
  ///
  /// Returns true when signing is possible.
  Future<bool> ensureKeysForCurrentUser() async {
    final uid = _currentUid;
    if (uid == null) {
      debugPrint('KeyManager: no signed-in user, cannot prepare keys');
      return false;
    }

    final privateKey = await _readPrivateKeyFor(uid);

    // The legacy device-wide key is deliberately NOT adopted. We cannot tell
    // whose key it is, and handing it to whoever signs in first would register
    // one user's key as another's - permanently recreating the very problem
    // this change fixes. Methods signed with it are repaired by re-signing
    // (see resignAsCurrentUser), so nothing depends on keeping it.
    await _discardLegacyKey();

    if (privateKey != null) {
      final registered = await _registerPublicKeyOf(privateKey);
      _publicKeyRegistrationPending = !registered;
      debugPrint('KeyManager: existing key for $uid,'
          ' public key registered: $registered');
      return true;
    }

    debugPrint('KeyManager: no key for $uid yet, generating a new keypair');
    return generateAndStoreKeys();
  }

  /// Re-sends the public key after a failed attempt (offline start).
  ///
  /// Call this when connectivity returns. Does nothing when there is nothing
  /// to repair. Returns true when the key is registered in the cloud.
  Future<bool> retryPendingPublicKeyRegistration() async {
    if (!_publicKeyRegistrationPending) return true;
    final privateKey = await getPrivateKey();
    if (privateKey == null) return false;

    final registered = await _registerPublicKeyOf(privateKey);
    _publicKeyRegistrationPending = !registered;
    debugPrint('KeyManager: retried public key registration: $registered');
    return registered;
  }

  /// Removes the pre-multi-user key so nothing can fall back to it.
  Future<void> _discardLegacyKey() async {
    final legacy = await _storage.read(key: _legacyStorageKey);
    if (legacy == null) return;
    await _storage.delete(key: _legacyStorageKey);
    debugPrint('KeyManager: discarded the legacy device-wide private key');
  }

  Future<bool> generateAndStoreKeys() async {
    final uid = _currentUid;
    if (uid == null) return false;
    try {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final privateKey = await keyPair.extractPrivateKeyBytes();

      // Public Key an Server senden und auf Erfolg prüfen
      final success = await cloudSyncService.apiClient
          .sendPublicKeyToFirebase(publicKey.bytes);

      if (success) {
        // Nur wenn Cloud-Speicherung erfolgreich war, privaten Schlüssel lokal speichern
        await savePrivateKey(privateKey);
        _publicKeyRegistrationPending = false;
        return true;
      } else {
        debugPrint('KeyManager: public key could NOT be stored in the cloud -'
            ' keeping no private key, signing stays disabled');
        return false;
      }
    } catch (e) {
      debugPrint('KeyManager: key generation failed: $e');
      return false;
    }
  }

  /// Derives the public key from the stored seed and registers it for the
  /// current user.
  Future<bool> _registerPublicKeyOf(List<int> privateKeySeed) async {
    try {
      final algorithm = Ed25519();
      final keyPair = await algorithm
          .newKeyPairFromSeed(Uint8List.fromList(privateKeySeed));
      final publicKey = await keyPair.extractPublicKey();
      return await cloudSyncService.apiClient
          .sendPublicKeyToFirebase(publicKey.bytes);
    } catch (e) {
      debugPrint('KeyManager: could not register public key: $e');
      return false;
    }
  }

  /// Speichert den privaten Schlüssel sicher im Secure Storage
  Future<void> savePrivateKey(List<int> privateKeyBytes) async {
    final uid = _currentUid;
    if (uid == null) return;
    final encodedKey = base64Encode(privateKeyBytes);
    await _storage.write(key: _storageKeyFor(uid), value: encodedKey);
  }

  /// Ruft den privaten Schlüssel des angemeldeten Nutzers ab.
  ///
  /// Bewusst OHNE Rückfall auf den Legacy-Schlüssel: Ein Rückfall würde genau
  /// den Fehler reproduzieren, dass ein Nutzer mit dem Schlüssel eines anderen
  /// signiert.
  Future<List<int>?> getPrivateKey() async {
    final uid = _currentUid;
    if (uid == null) return null;
    return _readPrivateKeyFor(uid);
  }

  Future<List<int>?> _readPrivateKeyFor(String uid) async {
    final encodedKey = await _storage.read(key: _storageKeyFor(uid));
    if (encodedKey == null) return null;
    return base64Decode(encodedKey);
  }
}
