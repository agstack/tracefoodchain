import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:trace_foodchain_app/main.dart';

class DigitalSignature {
  /// Creates a new signature for the given payload
  Future<String> generateSignature(String payload) async {
    // Sign payload with Ed25519
    final algorithm = Ed25519();
    // Get the keypair from the private key by using it as a seed
    final keyPair = await _getKeyPair();

    final payloadBytes = utf8.encode(payload);

    final signature = await algorithm.sign(
      payloadBytes,
      keyPair: keyPair,
    );
    return base64.encode(signature.bytes);
  }

  /// Returns the public key as a base64 encoded string
  Future<String> getPublicKey() async {
    final keyPair = await _getKeyPair();

    return base64.encode((await keyPair.extractPublicKey()).bytes);
  }

  /// Raw bytes of the current user's public key.
  Future<List<int>> getPublicKeyBytes() async {
    final keyPair = await _getKeyPair();
    return (await keyPair.extractPublicKey()).bytes;
  }

  /// Checks a base64 signature against the current user's own public key.
  ///
  /// Used to detect signatures that were produced with a key this user no
  /// longer has - e.g. made while the app still used one shared device key.
  /// Those can never be verified by the cloud and have to be redone.
  Future<bool> isSignedByCurrentKey(
      String payload, String signatureBase64) async {
    try {
      final algorithm = Ed25519();
      final publicKey = await (await _getKeyPair()).extractPublicKey();
      return await algorithm.verify(
        utf8.encode(payload),
        signature: Signature(
          base64.decode(signatureBase64),
          publicKey: publicKey,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Future<SimpleKeyPair> _getKeyPair() async {
    final keyBytes = await keyManager.getPrivateKey();
    if (keyBytes == null) throw Exception('Privater Schlüssel nicht gefunden');

    final algorithm = Ed25519();

    final keyPair = await algorithm.newKeyPairFromSeed(Uint8List.fromList(keyBytes));

    return keyPair;
  }
}
