// This service syncs local hive database to/from the clouds
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:trace_foodchain_app/helpers/deep_copy_map.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/helpers/json_full_double_to_int.dart';
import 'package:trace_foodchain_app/helpers/sort_json_alphabetically.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/screens/home_screen.dart';
import 'package:trace_foodchain_app/services/get_device_id.dart';
import 'package:trace_foodchain_app/services/media_outbox_service.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/sync_outbox_service.dart';
import 'package:trace_foodchain_app/services/sync_settings_service.dart';
//import 'dart:html' as html;

class CloudApiClient {
  final String domain;
  CloudApiClient({required this.domain});

  Future<bool> sendPublicKeyToFirebase(List<int> publicKeyBytes) async {
    dynamic urlString;
    try {
      urlString = getCloudConnectionProperty(
          domain, "cloudFunctionsConnector", "persistPublicKey")["url"];
    } catch (e) {
      return false;
    }

    final publicKeyBase64 = base64Encode(publicKeyBytes);
    final deviceId = await getDeviceId();
    final apiKey = await FirebaseAuth.instance.currentUser?.getIdToken();

    if (urlString != null && apiKey != null) {
      try {
        final response = await http.post(
          Uri.parse(urlString),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'userId': FirebaseAuth.instance.currentUser?.uid,
            'publicKey': publicKeyBase64,
            'deviceId': deviceId
          }),
        );

        if (response.statusCode == 200) {
          // final responseData = jsonDecode(response.body);
          // return responseData['success'] ?? false;
          return true;
        }
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> getDocumentFromCloud(String domain, documentUID,
      {String searchScope = "methods"}) async {
    String? urlString;
    try {
      urlString = getCloudConnectionProperty(
        domain,
        "cloudFunctionsConnector",
        searchScope == "objects" ? "getRALObjectByUID" : "getRALMethodByUID",
      )["url"];
    } catch (e) {
      return {};
    }
    final apiKey = await FirebaseAuth.instance.currentUser?.getIdToken();

    if (urlString != null && apiKey != null) {
      final uri = Uri.parse("$urlString?UID=$documentUID");
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {};
      }
    } else {
      return {};
    }
  }

  Future<Map<String, dynamic>> syncMethodToCloud(
      String domain, Map<String, dynamic> ralMethod) async {
    dynamic urlString;
    Map<String, dynamic> valueMap = deepCopyMap(ralMethod);

    valueMap = convertToJson(
        valueMap); //Replace Datetime and GeoPoint with JSON objects

    //delete hasMergeConflict and mergeConflictReason from valueMap
    valueMap.remove("hasMergeConflict");
    valueMap.remove("mergeConflictReason");

    final methodUid = ralMethod["identity"]["UID"];

    try {
      urlString = getCloudConnectionProperty(
          domain, "cloudFunctionsConnector", "syncMethodToCloud")["url"];
    } catch (e) {}
    final apiKey = await FirebaseAuth.instance.currentUser?.getIdToken();

    if (urlString != null && apiKey != null) {
      final response = await http.post(
        Uri.parse(urlString),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({'ralMethod': valueMap}),
      );

      if (response.statusCode == 200) {
// return jsonDecode(response.body);
        return {"response": "success"};
      } else {
        //Response codes? 400: Bad Request, 401: Unauthorized, 403: Forbidden, 404: Not Found, 500: Internal Server Error
        //Merge Conflict: 409

        return {
          "response": "${response.statusCode}",
          "responseDetails": jsonDecode(response.body),
        };
      }
    } else {
      // throw Exception("no valid cloud connection properties found!");
      return {"response": "no valid cloud connection properties found!"};
    }
  }

  Future<Map<String, dynamic>> syncObjectsMethodsFromCloud(
    String domain,
    Map<String, dynamic> deviceHashes,
  ) async {
    dynamic urlString;
    try {
      urlString = getCloudConnectionProperty(
        domain,
        "cloudFunctionsConnector",
        "syncFromCloud",
      )["url"];
    } catch (e) {
      return {};
    }
    String? apiKey = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (urlString != null && apiKey != null) {
      try {
        final response = await http.post(
          Uri.parse(urlString),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(deviceHashes),
        );

        if (response.statusCode == 200) {
          Map<String, dynamic> jsonResponse = jsonDecode(response.body);
          return jsonResponse;
        } else {
          return {};
        }
      } catch (e) {
        return {};
      }
    } else {
      throw Exception("no valid cloud connection properties found!");
    }
  }
}

class CloudSyncService {
  final CloudApiClient apiClient;
  bool _isSyncing =
      false; // Neues Flag, um parallele Sync-Aufrufe zu verhindern
  // WP A3: a trigger that arrives while a sync runs is coalesced into exactly
  // one follow-up run instead of being dropped.
  bool _rerunRequested = false;
  bool _isUploadingPhotos = false; // Flag to prevent parallel photo uploads

  CloudSyncService(String domain) : apiClient = CloudApiClient(domain: domain);

  /// Professional file upload with progress tracking for both Web and Native platforms
  /// Returns a Map with 'downloadURL' and 'storagePath' on success, or null on failure
  Future<Map<String, String?>?> _uploadFileWithProgress({
    required String fileName,
    required String contentType,
    File? file, // For native platforms
    Uint8List? bytes, // For web platform or when bytes are available
  }) async {
    try {
      // Reset upload progress
      uploadProgress.value = 0.0;

      final Reference storageRef = FirebaseStorage.instance.ref(fileName);
      final SettableMetadata metadata =
          SettableMetadata(contentType: contentType);

      String? downloadURL;
      String? storagePath;
      bool uploadFinishedOrFailed = false;
      TaskState? finalState;

      // Platform-specific upload
      late UploadTask uploadTask;

      if (kIsWeb) {
        // Web: Use putData with bytes
        if (bytes == null) {
          debugPrint('Error: bytes required for web upload');
          return null;
        }
        uploadTask = storageRef.putData(bytes, metadata);
      } else {
        // Native: Use putFile
        if (file == null) {
          debugPrint('Error: file required for native upload');
          return null;
        }
        uploadTask = storageRef.putFile(file, metadata);
      }

      // Listen to upload progress
      final subscription = uploadTask.snapshotEvents.listen(
        (TaskSnapshot taskSnapshot) async {
          switch (taskSnapshot.state) {
            case TaskState.running:
              final progress = taskSnapshot.totalBytes > 0
                  ? (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) *
                      100.0
                  : 0.0;
              uploadProgress.value = progress;
              debugPrint('Upload progress: ${progress.toStringAsFixed(2)}%');
              break;

            case TaskState.paused:
              debugPrint('Upload paused');
              break;

            case TaskState.success:
              try {
                downloadURL = await taskSnapshot.ref.getDownloadURL();
                storagePath = taskSnapshot.ref.fullPath;
                uploadProgress.value = 100.0;
                debugPrint('Upload successful: $downloadURL');
              } catch (e) {
                debugPrint('Error getting download URL: $e');
              }
              uploadFinishedOrFailed = true;
              finalState = TaskState.success;
              break;

            case TaskState.canceled:
              debugPrint('Upload canceled');
              uploadFinishedOrFailed = true;
              finalState = TaskState.canceled;
              break;

            case TaskState.error:
              debugPrint('Upload error');
              uploadFinishedOrFailed = true;
              finalState = TaskState.error;
              break;
          }
        },
        onError: (error) {
          debugPrint('Upload stream error: $error');
          uploadFinishedOrFailed = true;
          finalState = TaskState.error;
        },
      );

      // Wait for upload to complete
      while (!uploadFinishedOrFailed) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Cancel subscription
      await subscription.cancel();

      // Return result based on final state
      if (finalState == TaskState.success && downloadURL != null) {
        return {
          'downloadURL': downloadURL,
          'storagePath': storagePath,
        };
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error in _uploadFileWithProgress: $e');
      return null;
    }
  }

  Future<void> syncOpenRALTemplates(String domain,
      {Function(int current, int total)? onProgress}) async {
    final totalTemplates = openRALTemplates.keys.length;
    int currentIndex = 0;

    for (var templateName in openRALTemplates.keys) {
      currentIndex++;
      if (onProgress != null) {
        onProgress(currentIndex, totalTemplates);
      }

      try {
        //If possible, always use the cloud versions of the templates for locale database
        // final cloudTemplate = await _apiClient.getRalObjectByUid(domain,templateName);
        // openRALTemplates.put(templateName, cloudTemplate);
      } catch (e) {}
    }
  }

  /// Uploads pending media to Firebase Storage and writes the cloud URL into the
  /// image object once the remote copy has been *verified* (WP A1).
  ///
  /// The work list comes from the durable [MediaOutboxService], not from a scan
  /// of localStorage: an item survives app kills, keeps its retry state, and is
  /// only ever considered done after `confirmedRemote`.
  /// This must be called before syncMethods() to avoid internal loops.
  Future<void> uploadPendingPhotos() async {
    if (syncSettings.isUploadPaused) {
      debugPrint('uploadPendingPhotos: skipped (uploadPaused)');
      cloudLogService.info('uploadPendingPhotos: skipped', data: {
        'reason': 'uploadPaused',
      });
      return;
    }
    if (_isUploadingPhotos) {
      debugPrint(
          'Photo upload already in progress, skipping new upload request');
      return;
    }
    _isUploadingPhotos = true;
    cloudLogService.info('uploadPendingPhotos: start');

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('No authenticated user found, skipping photo upload');
        cloudLogService
            .warn('uploadPendingPhotos: no authenticated user, aborting');
        return;
      }
      if (!mediaOutbox.isOpen) {
        debugPrint('media_outbox not open, skipping photo upload');
        cloudLogService.warn('uploadPendingPhotos: media outbox not open');
        return;
      }

      // Pick up photos captured before the outbox existed (and before this
      // device ever ran a version that enqueued them).
      await _backfillMediaOutbox();

      final dueEntries = mediaOutbox.dueForUpload;
      debugPrint(
          'uploadPendingPhotos: ${dueEntries.length} due of ${mediaOutbox.pendingCount} pending');

      for (final entry in dueEntries) {
        if (syncSettings.isUploadPaused) {
          debugPrint('uploadPendingPhotos: aborting, upload paused mid-run');
          break;
        }
        await _processMediaEntry(entry, user.uid);
      }

      // Confirmed media may release its local copy - but only once the
      // documents referencing it are themselves in the cloud.
      await mediaOutbox.releaseConfirmedLocalCopies(needsSync: _docNeedsSync);
      _refreshPendingCount();
    } catch (e) {
      debugPrint('Error in photo upload process: $e');
      cloudLogService.error('uploadPendingPhotos: outer exception',
          data: {'error': e.toString()});
      // Don't throw - allow sync to continue even if photo upload fails
    } finally {
      _isUploadingPhotos = false;
      cloudLogService.info('uploadPendingPhotos: finished');
    }
  }

  /// Runs one media item through upload -> verify -> confirm.
  Future<void> _processMediaEntry(MediaOutboxEntry entry, String userId) async {
    // Already uploaded but never verified (e.g. the app was killed right after
    // Storage returned 200): verify first, do not upload again.
    if (entry.status == MediaStatus.uploadedUnverified &&
        (entry.remoteUrl?.isNotEmpty ?? false)) {
      await _verifyAndConfirm(entry);
      return;
    }

    currentUploadPhotoName.value = entry.imageName ?? '';
    uploadProgress.value = 0.0;

    try {
      await mediaOutbox.markUploading(entry.mediaUID);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imageName = entry.imageName?.isNotEmpty == true
          ? entry.imageName!
          : 'image';
      final fileName =
          'images/$userId/$imageName/${entry.mediaUID}_$timestamp.jpg';

      debugPrint('Uploading image to Firebase Storage: $fileName');
      cloudLogService.info('uploadPendingPhotos: uploading photo', data: {
        'name': imageName,
        'uid': entry.mediaUID,
        'attempt': '${entry.attemptCount + 1}',
      });

      File? file;
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await mediaOutbox.readBytes(entry);
        if (bytes == null) {
          await mediaOutbox.markFailure(
              entry.mediaUID, 'local bytes unavailable');
          return;
        }
      } else {
        file = File(entry.localPath);
        if (!await file.exists()) {
          await mediaOutbox.markFailure(
              entry.mediaUID, 'local file missing: ${entry.localPath}');
          cloudLogService.error('uploadPendingPhotos: local file missing',
              data: {'uid': entry.mediaUID, 'path': entry.localPath});
          return;
        }
      }

      final uploadResult = await _uploadFileWithProgress(
        fileName: fileName,
        contentType: 'image/jpeg',
        file: file,
        bytes: bytes,
      );

      if (uploadResult == null || uploadResult['downloadURL'] == null) {
        await mediaOutbox.markFailure(entry.mediaUID, 'upload returned null');
        cloudLogService.warn('uploadPendingPhotos: upload returned null result',
            data: {'name': imageName, 'uid': entry.mediaUID});
        return;
      }

      // Storage reported success - durable, but not yet trusted.
      await mediaOutbox.markUploadedUnverified(entry.mediaUID,
          uploadResult['downloadURL']!, uploadResult['storagePath']);

      final refreshed = mediaOutbox.get(entry.mediaUID);
      if (refreshed != null) await _verifyAndConfirm(refreshed);
    } catch (e) {
      await mediaOutbox.markFailure(entry.mediaUID, e.toString());
      debugPrint('Error uploading image: $e');
      cloudLogService.error('uploadPendingPhotos: photo upload exception',
          data: {'uid': entry.mediaUID, 'error': e.toString()});
    } finally {
      currentUploadPhotoName.value = '';
    }
  }

  /// Verifies the remote copy and, only then, writes the cloud URL into the
  /// image object. Nothing downstream ever sees a downloadURL we have not
  /// confirmed to exist.
  Future<void> _verifyAndConfirm(MediaOutboxEntry entry) async {
    final verified = await mediaOutbox.verifyRemoteCopy(entry);
    if (!verified) {
      await mediaOutbox.markVerificationFailed(
          entry.mediaUID, 'remote copy not verifiable');
      cloudLogService.warn('uploadPendingPhotos: verification failed',
          data: {'uid': entry.mediaUID});
      return;
    }

    await mediaOutbox.markConfirmed(entry.mediaUID);
    cloudLogService.info('uploadPendingPhotos: photo uploaded and verified',
        data: {'name': entry.imageName ?? '', 'uid': entry.mediaUID});

    await _writeCloudUrlIntoImageObject(entry);
  }

  /// Persists downloadURL/storagePath on the image object via changeObjectData
  /// so the change is documented with its own method history.
  Future<void> _writeCloudUrlIntoImageObject(MediaOutboxEntry entry) async {
    try {
      var doc = await getLocalObjectMethod(entry.mediaUID);
      if (doc.isEmpty) {
        debugPrint(
            'media: image object ${entry.mediaUID} not found locally, skipping URL update');
        return;
      }
      final existingUrl = getSpecificPropertyfromJSON(doc, "downloadURL");
      if (existingUrl == entry.remoteUrl) return; // already up to date

      // CRITICAL: setSpecificPropertyJSON returns a new copy, must reassign!
      doc = setSpecificPropertyJSON(doc, "downloadURL", entry.remoteUrl, "URL");
      doc = setSpecificPropertyJSON(doc, "storagePath", entry.remotePath, "URL");
      await changeObjectData(doc, syncFromCloud: false);
      debugPrint(
          'Updated downloadURL for image object ${entry.mediaUID} after verification');
    } catch (e) {
      debugPrint('Error writing cloud URL into image object: $e');
      cloudLogService.error('uploadPendingPhotos: could not persist cloud URL',
          data: {'uid': entry.mediaUID, 'error': e.toString()});
    }
  }

  /// Migration for image objects that predate the media outbox.
  Future<void> _backfillMediaOutbox() async {
    if (localStorage == null || !localStorage!.isOpen) return;
    final imageObjects = <Map<String, dynamic>>[];
    for (final doc in localStorage!.values) {
      if (doc["template"]?["RALType"] != "image") continue;
      imageObjects.add(Map<String, dynamic>.from(doc));
    }
    if (imageObjects.isEmpty) return;
    await mediaOutbox.backfill(
      imageObjects: imageObjects,
      uidOf: getObjectMethodUID,
      propertyOf: (doc, prop) {
        final value = getSpecificPropertyfromJSON(doc, prop);
        return value == '-no data found-' ? '' : value;
      },
    );
  }

  /// Does the document with this UID still have to reach the cloud?
  bool _docNeedsSync(String uid) {
    if (localStorage == null || !localStorage!.isOpen) return true;
    final doc = localStorage!.get(uid);
    if (doc == null) return false;
    return doc["needsSync"] != null;
  }

  /// Publishes the number of items still waiting to reach the cloud (WP A2).
  void _refreshPendingCount() {
    int pending = mediaOutbox.isOpen ? mediaOutbox.pendingCount : 0;
    if (localStorage != null && localStorage!.isOpen) {
      for (final doc in localStorage!.values) {
        if (doc["needsSync"] != null) pending++;
      }
    }
    syncSettings.pendingItemCount.value = pending;
  }

//This function syncs all methods and objects to the cloud if tagged as being changed/generated locally only

  Future<bool> syncMethods(String domain,
      {Function(int current, int total)? onProgress,
      Function(int current, int total)? onDownloadProgress,
      VoidCallback? onFetchingFromCloud,
      bool syncFromCloud = true}) async {
    // WP A2: the user can suspend all cloud traffic. Local capture and the
    // needsSync flagging keep running - only the wire is silent.
    if (syncSettings.isUploadPaused) {
      debugPrint('[SYNC] skipped (uploadPaused)');
      cloudLogService
          .info('syncMethods: skipped', data: {'reason': 'uploadPaused'});
      return false;
    }

    // WP A3: a trigger arriving during a run is no longer dropped - it is
    // remembered and produces exactly one follow-up run.
    if (_isSyncing) {
      _rerunRequested = true;
      debugPrint('Sync already in progress, scheduling exactly one follow-up');
      return false;
    }
    _isSyncing = true;
    bool success = false;
    try {
      success = await _runSyncCycle(
        domain,
        onProgress: onProgress,
        onDownloadProgress: onDownloadProgress,
        onFetchingFromCloud: onFetchingFromCloud,
        syncFromCloud: syncFromCloud,
      );
    } finally {
      _isSyncing = false;
    }

    if (_rerunRequested) {
      _rerunRequested = false;
      debugPrint('[SYNC] running the coalesced follow-up sync');
      unawaited(syncMethods(domain,
          onProgress: onProgress,
          onDownloadProgress: onDownloadProgress,
          onFetchingFromCloud: onFetchingFromCloud,
          syncFromCloud: syncFromCloud));
    }
    return success;
  }

  Future<bool> _runSyncCycle(String domain,
      {Function(int current, int total)? onProgress,
      Function(int current, int total)? onDownloadProgress,
      VoidCallback? onFetchingFromCloud,
      bool syncFromCloud = true}) async {
    List<String> failedSyncedOutputObjects = [];
    bool cycleSuccess = false;
    cloudLogService.info('syncMethods: start', data: {'domain': domain});
    final databaseHelper = DatabaseHelper();
    try {
      //****** 1. SYNC METHODS TO CLOUD - and build hash map for later syncing from cloud *********
      List<Map<String, dynamic>> methodsToSyncToCloud = [];
      Map<String, dynamic> deviceHashes = {
        "objectHashTable": [],
        "methodHashTable": [],
      };
      for (var doc in localStorage!.values) {
        final doc2 = Map<String, dynamic>.from(doc);
        if (doc2["methodHistoryRef"] != null) {
          //This is an object
          if (doc2["needsSync"] != null) {
            doc2.remove(
                "needsSync"); //!need to avoid needsSync being in the Hash!

            // setObjectMethod(doc2, false, false);
          }

          final String hash = generateStableHash(doc2);
          final String uid = getObjectMethodUID(doc2);

          deviceHashes["objectHashTable"].add({"UID": uid, "hash": hash});
        } else {
          //This is a method
          String hash = "";
          final String uid = getObjectMethodUID(doc2);
          if (doc2["digitalSignatures"] == null) {
            //! REMOVE LATER: Make sure old methods of the pre-cloud era get a digital signature
            //Sync anyway after getting a digital signature
            final doc3 = await setObjectMethod(doc2, true, false);
            methodsToSyncToCloud.add(doc3);
            hash = generateStableHash(doc3);
          } else {
            //Handle standard methods (sync upwards if they need a sync)
            if (doc2["needsSync"] != null) {
              doc2.remove(
                  "needsSync"); //!need to avoid needsSync being in the Hash!
              methodsToSyncToCloud.add(doc2);
            }
            hash = generateStableHash(doc2);
          }

          if (hash != "")
            deviceHashes["methodHashTable"].add({"UID": uid, "hash": hash});
        }
      }
      // WP A3: items that failed recently wait out their backoff window. They
      // stay flagged `needsSync` and still contribute their hash, so nothing is
      // lost - the push is merely deferred.
      final int backedOffCount = methodsToSyncToCloud
          .where((m) => syncOutbox.isBackedOff(getObjectMethodUID(m)))
          .length;
      if (backedOffCount > 0) {
        methodsToSyncToCloud
            .removeWhere((m) => syncOutbox.isBackedOff(getObjectMethodUID(m)));
        debugPrint(
            '[SYNC] $backedOffCount method(s) deferred by retry backoff, next due ${syncOutbox.nextDueAt}');
      }

      bool syncSuccess = true;
      int currentMethodIndex = 0;
      final totalMethodsToSync = methodsToSyncToCloud.length;

      for (final method in methodsToSyncToCloud) {
        currentMethodIndex++;
        if (onProgress != null) {
          onProgress(currentMethodIndex, totalMethodsToSync);
        }

        final doc2 = Map<String, dynamic>.from(method);
        final methodUid = getObjectMethodUID(doc2);
        try {
          debugPrint('Syncing method to cloud: $methodUid');
          Map<String, dynamic> syncresult =
              await apiClient.syncMethodToCloud(domain, doc2);
          if (syncresult["response"] == "success") {
            debugPrint('Method $methodUid synced successfully to cloud');
            await syncOutbox.recordSuccess(methodUid); //clears any retry state
            await setObjectMethod(
                doc2, false, false); //persists removal of sync flag from method
          } else {
            await syncOutbox.recordFailure(
                methodUid, syncresult["response"].toString());
            debugPrint(
                'Error syncing method $methodUid to cloud: ${syncresult["response"].toString()}');
            if (doc2.containsKey("outputObjects") &&
                doc2["outputObjects"] is List) {
              for (final output in doc2["outputObjects"]) {
                if (output is Map<String, dynamic>) {
                  failedSyncedOutputObjects.add(output["identity"]["UID"]);
                }
              }
            }
            if (syncresult["responseDetails"] != null) {
              switch (syncresult["response"]) {
                case "409":
                  debugPrint('[SYNC 409] Merge conflict for method $methodUid');
                  debugPrint(
                      '[SYNC 409] Full responseDetails: ${syncresult["responseDetails"]}');
                  //ToDo: Flag methods or objects with merge conflicts
                  if (syncresult["responseDetails"]
                      .containsKey("methodConflict")) {
                    debugPrint(
                        '[SYNC 409] methodConflict: ${syncresult["responseDetails"]["methodConflict"]}');
                    //problem to merge method
                    //     - cloudVersionInvalid
                    //     - clientVersionInvalid
                    //     - conflictReasonUnknown
                    Map<String, dynamic> conflictMethod =
                        await getLocalObjectMethod(getObjectMethodUID(doc2));
                    debugPrint(
                        '[SYNC 409] conflictMethod loaded, isEmpty=${conflictMethod.isEmpty}');
                    conflictMethod["hasMergeConflict"] = true;
                    conflictMethod["mergeConflictReason"] =
                        syncresult["responseDetails"]["methodConflict"];
                    await setObjectMethod(conflictMethod, false, true);
                    debugPrint(
                        '[SYNC 409] conflictMethod saved with hasMergeConflict=true');
                  }
                  if (syncresult["responseDetails"]
                      .containsKey("conflictObjects")) {
                    final conflictList =
                        syncresult["responseDetails"]["conflictObjects"];
                    debugPrint(
                        '[SYNC 409] conflictObjects count: ${conflictList?.length ?? 0}, content: $conflictList');
                    // conflictObjects: List of objects with merge conflicts
                    // "objectUid": "a9b94df2-2ad8-4f2f-b469-3d8bb6f9f054" => flag as problematic
                    for (final object in conflictList) {
                      debugPrint(
                          '[SYNC 409] Flagging conflictObject: ${object["objectUid"]}');
                      Map<String, dynamic> conflictObject =
                          await getLocalObjectMethod(object["objectUid"]);
                      debugPrint(
                          '[SYNC 409] conflictObject loaded, isEmpty=${conflictObject.isEmpty}');
                      conflictObject["hasMergeConflict"] = true;
                      await setObjectMethod(conflictObject, false, true);
                      debugPrint(
                          '[SYNC 409] conflictObject ${object["objectUid"]} saved with hasMergeConflict=true');
                    }
                  }
                  debugPrint(
                      '[SYNC 409] 409 handling done, continuing loop (syncSuccess=false)');

                  break;
                case "400":
                  //general problem: one of
                  // missingParameters:
                  // invalidSignature => Flag method as invalid
                  // errorMessage

                  if (kDebugMode && 1 == 2) {
                    String signingObject = "";
                    List<String> pathsToSign = [];
                    for (final so in doc2["digitalSignatures"]) {
                      List<String> pathsToSign = [];
                      for (final sc in so["signedContent"]) {
                        pathsToSign.add(sc);
                      }
                      signingObject = createSigningObject(pathsToSign, doc2);
                      await Share.share(signingObject);
                    }

                    //  await Share.share(doc2.toString());
                  }
                  if (syncresult["responseDetails"]
                      .containsKey("invalidSignature")) {
                    Map<String, dynamic> conflictMethod =
                        await getLocalObjectMethod(getObjectMethodUID(doc2));
                    conflictMethod["hasMergeConflict"] = true;
                    conflictMethod["mergeConflictReason"] =
                        "invalid digital signature";
                    await setObjectMethod(conflictMethod, false, true);
                  }

                  break;
                default:
              }
            }
            syncSuccess = false;
            snackbarMessageNotifier.value =
                "error syncing to cloud: ${syncresult["response"].toString()}";

            // globalSnackBarNotifier.value = {
            //   'type': 'error',
            //   'text': "error syncing to cloud",
            //   'errorCode': syncresult["response"]
            // };
          }
        } catch (e) {
          syncSuccess = false;
          await syncOutbox.recordFailure(methodUid, e.toString());
          debugPrint(
              '[SYNC] Exception in inner try-catch for method $methodUid: $e');
          snackbarMessageNotifier.value = "unknown error syncing to cloud";
          // globalSnackBarNotifier.value = {
          //   'type': 'error',
          //   'text': "error syncing to cloud",
          //   'errorCode': "unknown error"
          // };
        }
        if (syncSuccess) {
          snackbarMessageNotifier.value = "sync to cloud successful";
          // globalSnackBarNotifier.value = {
          //   'type': 'info',
          //   'text': 'sync to cloud successful'
          // };
        }
      }

      debugPrint(
          '[SYNC] Upload loop done. syncSuccess=$syncSuccess, syncFromCloud param=$syncFromCloud');

      //******* 2. SYNC METHODS AND OBJECTS FROM CLOUD - independet of new methods on device ********
      //This happens in case a user has logged into a second device (e.g., webapp on PC)
      //1. Generate a hash list from all objects and methods on the device

      //2. Get all objects and methods from the cloud that are not on the device or need to be updated
      if (!syncFromCloud) {
        debugPrint('[SYNC] syncFromCloud=false, returning early');
        cycleSuccess = syncSuccess;
        if (cycleSuccess) await syncSettings.markSyncSuccessful();
        return cycleSuccess;
      }
      debugPrint('[SYNC] Starting syncObjectsMethodsFromCloud...');
      if (onFetchingFromCloud != null) {
        onFetchingFromCloud();
      }
      final cloudData =
          await apiClient.syncObjectsMethodsFromCloud(domain, deviceHashes);
      debugPrint(
          '[SYNC] syncObjectsMethodsFromCloud returned, isEmpty=${cloudData.isEmpty}');
      // this will return an empty object in case there is an error.
      if (cloudData.isEmpty) {
        debugPrint('[SYNC] cloudData is empty, returning false');
        return false;
      }

      // Fusioniere die beiden Listen "ralMethods" und "ralObjects" zu einer final mergedList
      List<dynamic> mergedList = [];
      if (cloudData.containsKey("ralMethods") &&
          cloudData["ralMethods"] is List) {
        mergedList.addAll(cloudData["ralMethods"]);
      }
      if (cloudData.containsKey("ralObjects") &&
          cloudData["ralObjects"] is List) {
        for (final item in cloudData["ralObjects"]) {
          // );
          //Check if the UID of this object is in the failedSyncedOutputObjects, only add if not
          String uid = getObjectMethodUID(item);
          if (!failedSyncedOutputObjects.contains(uid)) {
            mergedList.add(item);
          }
        }
      }
      //*** WP A4: atomic pull phase ***
      // Incoming documents are written to a staging box first and only moved
      // into localStorage in one batch once the whole payload has arrived. A
      // crash mid-pull therefore leaves the local state fully "before" - the
      // next run re-fetches cleanly via the hash comparison.
      await syncOutbox.beginStaging();
      int currentDownloadIndex = 0;
      final totalDownloads = mergedList.length;

      for (final item in mergedList) {
        currentDownloadIndex++;
        if (onDownloadProgress != null) {
          onDownloadProgress(currentDownloadIndex, totalDownloads);
        } else if (onProgress != null) {
          onProgress(currentDownloadIndex, totalDownloads);
        }

        final docData = Map<String, dynamic>.from(item);

        //);
        docData.remove("needsSync");
        final String docUid = getObjectMethodUID(docData);
        if (docUid.isEmpty) {
          debugPrint('[SYNC] skipping pulled document without UID');
          continue;
        }
        await syncOutbox.stage(docUid, _normalizeIncomingDocument(docData));
      }

      // Marker + commit: everything before this point is discardable.
      await syncOutbox.markStagingComplete();
      final committed = await syncOutbox.commitStagingInto(localStorage!);
      debugPrint('[SYNC] pull phase committed $committed documents atomically');

      // Traverse through all maps in deviceHashes.
      // For each entry, extract the "UID", load the corresponding object,
      // remove "needsSync" if it exists, and save the updated object.
      for (final hashList in deviceHashes.values) {
        for (final entry in hashList) {
          if (entry is Map<String, dynamic> && entry.containsKey("UID")) {
            final uid = entry["UID"];
            final localDoc = await getLocalObjectMethod(uid);
            if (localDoc.containsKey("needsSync")) {
              if (!failedSyncedOutputObjects.contains(uid)) {
                localDoc.remove("needsSync");
                await setObjectMethod(localDoc, false, false);
              }
            }
          }
        }
      }
      //
      cycleSuccess = syncSuccess;
      if (cycleSuccess) await syncSettings.markSyncSuccessful();
      return cycleSuccess;
    } catch (e) {
      debugPrint(
          '[SYNC] Exception in outer try-catch (skipping syncFromCloud!): $e');
      cloudLogService.error('syncMethods: outer exception',
          data: {'domain': domain, 'error': e.toString()});
      return false;
    } finally {
      debugPrint('[SYNC] syncMethods finally block reached');
      _refreshPendingCount();
      cloudLogService.info('syncMethods: finished',
          data: {'domain': domain, 'success': '$cycleSuccess'});
    }
  }

  /// Applies the side effects `setObjectMethod` would have applied to a pulled
  /// document, so staging + batch commit behaves identically to the previous
  /// per-item write - just atomically.
  Map<String, dynamic> _normalizeIncomingDocument(Map<String, dynamic> doc) {
    if (doc["role"] != null) {
      doc.remove("role"); //Remove unwanted role declaration of objects
    }
    if (doc.containsKey("existenceStarts") && doc["existenceStarts"] == null) {
      doc["existenceStarts"] = DateTime.now();
    }
    return doc;
  }

  /// Commits or discards whatever an interrupted pull left behind (WP A4).
  /// Call once after the user boxes are open, before the first sync.
  Future<void> recoverInterruptedPull() async {
    if (!syncOutbox.isOpen) return;
    if (localStorage == null || !localStorage!.isOpen) return;
    if (!syncOutbox.hasStagedData) return;
    final committed = await syncOutbox.commitStagingInto(localStorage!);
    debugPrint(committed > 0
        ? '[SYNC] recovered $committed staged documents from an interrupted pull'
        : '[SYNC] discarded an incomplete staged pull');
    cloudLogService.info('recoverInterruptedPull',
        data: {'committed': '$committed'});
  }
}

///Returns the SHA-256 hash of a Utf8 encoded JSON string as a hex string
///Can be converted to bytes with utf8.encode(hashString)
String generateStableHash(Map<String, dynamic> docData) {
  Map<String, dynamic> valueMap = deepCopyMap(docData);

  valueMap =
      convertToJson(valueMap); //Replace Datetime and GeoPoint with JSON objects

  //Avoid json string with double like 1000.0 -> because on some platforms doubles are stringified without the .0
  valueMap = jsonFullDoubleToInt(valueMap);

  //Sort alphabetically to ensure getting the same hash for the same data
  valueMap = sortJsonAlphabetically(valueMap);

  final jsonString = jsonEncode(valueMap);
  // if (valueMap.keys.contains("methodHistoryRef")) {
  //
  // }
  final String uid = getObjectMethodUID(docData);

  //

  final bytes = utf8.encode(jsonString);

  //
  // }");

  final hashStr = sha256.convert(bytes).toString();

  return hashStr;
}
