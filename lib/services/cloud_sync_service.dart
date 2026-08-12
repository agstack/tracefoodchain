// This service syncs local hive database to/from the clouds
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:trace_foodchain_app/helpers/deep_copy_map.dart';
import 'package:trace_foodchain_app/helpers/frame_safe_value_notifier.dart';
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
      // The OpenAPI spec documents this parameter as lowercase `uid`, the app
      // has always sent `UID`. Query parameter names are case sensitive, so
      // send both - which one the function reads then does not matter.
      final uri = Uri.parse(urlString).replace(queryParameters: {
        'uid': '$documentUID',
        'UID': '$documentUID',
      });
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

  /// Resolves the pull endpoint.
  ///
  /// The paginated variant lives under its own name (`syncFromCloudBeta`) so
  /// that clients in the field keep resolving the unchanged `syncFromCloud`.
  /// Returns null when the paginated endpoint is not configured for [domain].
  String? paginatedSyncUrl(String domain) {
    try {
      final property = getCloudConnectionProperty(
        domain,
        "cloudFunctionsConnector",
        "syncFromCloudBeta",
      );
      // A missing key yields the sentinel String '-no data found-', not null,
      // so the type has to be checked rather than the value.
      if (property is Map) {
        final url = property["url"];
        if (url is String && url.isNotEmpty) return url;
      }
    } catch (e) {
      debugPrint('[SYNC] no paginated sync endpoint for $domain: $e');
    }
    return null;
  }

  /// True when this domain offers the paginated pull.
  bool supportsPagination(String domain) => paginatedSyncUrl(domain) != null;

  /// Fetches the difference between cloud and device.
  ///
  /// [page]/[pageSize] request one bounded slice instead of the whole diff -
  /// the low-bandwidth path. Both must be given together; omitting them keeps
  /// the classic single-response behaviour. Pagination is only sent to the
  /// paginated endpoint, never to the classic one.
  Future<Map<String, dynamic>> syncObjectsMethodsFromCloud(
    String domain,
    Map<String, dynamic> deviceHashes, {
    int? page,
    int? pageSize,
  }) async {
    final bool wantsPagination = page != null && pageSize != null;
    String? urlString;

    if (wantsPagination) {
      urlString = paginatedSyncUrl(domain);
      if (urlString == null) {
        debugPrint(
            '[SYNC] pagination requested but syncFromCloudBeta is not configured'
            ' - falling back to the classic endpoint');
      }
    }
    if (urlString == null) {
      try {
        urlString = getCloudConnectionProperty(
          domain,
          "cloudFunctionsConnector",
          "syncFromCloud",
        )["url"];
      } catch (e) {
        return {};
      }
    }

    String? apiKey = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (urlString != null && apiKey != null) {
      // Only add the paging fields when we really talk to the paginated
      // endpoint - sending them to the classic one would change a request that
      // is currently answered with the full diff.
      final Map<String, dynamic> body = Map<String, dynamic>.from(deviceHashes);
      final bool paginate =
          wantsPagination && urlString == paginatedSyncUrl(domain);
      if (paginate) {
        body["page"] = page;
        body["pageSize"] = pageSize;
      }

      try {
        final response = await http.post(
          Uri.parse(urlString),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(body),
        );

        if (response.statusCode == 200) {
          Map<String, dynamic> jsonResponse = jsonDecode(response.body);
          return jsonResponse;
        } else {
          debugPrint(
              '[SYNC] syncFromCloud returned HTTP ${response.statusCode}');
          return {};
        }
      } catch (e) {
        debugPrint('[SYNC] syncFromCloud request failed: $e');
        return {};
      }
    } else {
      throw Exception("no valid cloud connection properties found!");
    }
  }
}

/// Which part of a sync run is currently working.
enum SyncPhase {
  /// Photos/documents on their way to Firebase Storage.
  media,

  /// Methods being pushed to the cloud.
  push,

  /// Objects/methods being pulled from the cloud.
  pull,
}

/// Live progress of the running sync.
///
/// Deliberately structured instead of a pre-formatted string: the string would
/// have to be built in the service, where there is no BuildContext and thus no
/// localisation.
class SyncProgress {
  const SyncProgress({
    required this.phase,
    required this.current,
    required this.total,
    this.label,
  });

  final SyncPhase phase;
  final int current;
  final int total;

  /// Optional detail, e.g. the name of the photo being uploaded.
  final String? label;

  /// Null while the total is not yet known - render an indeterminate bar then.
  double? get fraction {
    if (total <= 0) return null;
    return (current / total).clamp(0.0, 1.0);
  }
}

/// What a sync cycle actually did. Without this the UI can only say "something
/// ran", which is indistinguishable from "nothing happened".
class SyncSummary {
  const SyncSummary({
    this.pushed = 0,
    this.failed = 0,
    this.deferred = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.blockedByRunningSync = false,
  });

  /// Methods successfully accepted by the cloud.
  final int pushed;

  /// Methods the cloud rejected or that failed on the wire.
  final int failed;

  /// Methods skipped because they are inside their retry backoff window.
  final int deferred;

  /// Objects/methods written to the local database from the cloud.
  final int pulled;

  /// Methods flagged with a merge conflict - these need a human.
  final int conflicts;

  /// The request was dropped because another cycle was already running.
  final bool blockedByRunningSync;

  bool get didNothing =>
      pushed == 0 && failed == 0 && pulled == 0 && conflicts == 0;
}

class CloudSyncService {
  final CloudApiClient apiClient;
  bool _isSyncing =
      false; // Neues Flag, um parallele Sync-Aufrufe zu verhindern
  // WP A3: a trigger that arrives while a sync runs is coalesced into exactly
  // one follow-up run instead of being dropped.
  bool _rerunRequested = false;
  bool _isUploadingPhotos = false; // Flag to prevent parallel photo uploads

  /// WP B2: page size for the pull.
  ///
  /// Careful: the server pages over the COMPARED lists (its own hash tables),
  /// not over the differences. The number of round trips is therefore
  /// ceil(totalCloudEntries / pageSize) no matter how little actually differs -
  /// with 50 that meant 38 requests to discover 12 changed documents.
  ///
  /// The response payload, on the other hand, only carries the entries that
  /// really differ within the window. A larger page size therefore costs
  /// almost nothing for a device that is roughly in sync, and only bounds the
  /// worst case of a fresh device where everything differs. 250 keeps that
  /// worst case well below the old unbounded single response while cutting the
  /// round trips of the common case by a factor of five.
  static const int _pullPageSize = 250;

  /// Backstop so a server that always reports `hasMore` cannot spin forever.
  static const int _maxPullPages = 500;

  /// Zone marker that distinguishes a trigger fired from inside the running
  /// sync cycle (must be ignored) from an external one (may be coalesced).
  static const Object _syncCycleZoneKey = Object();
  bool get _isInsideSyncCycle => Zone.current[_syncCycleZoneKey] == true;

  /// True while a sync cycle is running - lets the UI show what is happening
  /// instead of leaving the user guessing after a button press.
  final ValueNotifier<bool> isSyncRunning = FrameSafeValueNotifier<bool>(false);

  /// Outcome of the most recent cycle, so the UI can report what actually
  /// happened rather than silently doing nothing.
  final ValueNotifier<SyncSummary?> lastSyncSummary =
      FrameSafeValueNotifier<SyncSummary?>(null);

  /// Live progress, or null when nothing is running.
  final ValueNotifier<SyncProgress?> syncProgress =
      FrameSafeValueNotifier<SyncProgress?>(null);

  CloudSyncService(String domain) : apiClient = CloudApiClient(domain: domain);

  /// How long an upload may make no progress at all before we give up on it.
  /// Generous on purpose - field devices on 2G need minutes for one photo -
  /// but finite, so a dead connection cannot wedge the media queue.
  static const Duration _uploadStallTimeout = Duration(minutes: 3);

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
      final Completer<TaskState> completer = Completer<TaskState>();
      void finish(TaskState state) {
        if (!completer.isCompleted) completer.complete(state);
      }

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

      // A stalled upload must not block the queue forever: every byte that
      // arrives refreshes this stamp, and the watchdog below kills the task
      // once nothing has moved for _uploadStallTimeout.
      DateTime lastActivity = DateTime.now();

      // Listen to upload progress
      final subscription = uploadTask.snapshotEvents.listen(
        (TaskSnapshot taskSnapshot) async {
          switch (taskSnapshot.state) {
            case TaskState.running:
              lastActivity = DateTime.now();
              final progress = taskSnapshot.totalBytes > 0
                  ? (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) *
                      100.0
                  : 0.0;
              uploadProgress.value = progress;
              debugPrint('Upload progress: ${progress.toStringAsFixed(2)}%');
              break;

            case TaskState.paused:
              lastActivity = DateTime.now();
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
              finish(TaskState.success);
              break;

            case TaskState.canceled:
              debugPrint('Upload canceled');
              finish(TaskState.canceled);
              break;

            case TaskState.error:
              debugPrint('Upload error');
              finish(TaskState.error);
              break;
          }
        },
        onError: (error) {
          // Firebase's Android plugin cancels the native task as soon as the
          // snapshot stream is torn down, which happens right after a
          // successful upload - the resulting "operation was cancelled"
          // (-13040) event arrives late and must not undo a success.
          if (completer.isCompleted) {
            debugPrint('Upload stream error after completion, ignored: $error');
            return;
          }
          debugPrint('Upload stream error: $error');
          finish(TaskState.error);
        },
      );

      // Watchdog: without it a connection that dies mid-transfer never
      // produces a terminal event and uploadPendingPhotos hangs for good.
      final watchdog = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (completer.isCompleted) {
          timer.cancel();
          return;
        }
        if (DateTime.now().difference(lastActivity) < _uploadStallTimeout) {
          return;
        }
        timer.cancel();
        debugPrint('Upload stalled, cancelling: $fileName');
        cloudLogService.warn('media: upload stalled, cancelling', data: {
          'file': fileName,
          'stalledForSeconds': '${_uploadStallTimeout.inSeconds}',
        });
        unawaited(uploadTask.cancel().catchError((_) => false));
        finish(TaskState.canceled);
      });

      final TaskState finalState = await completer.future;
      watchdog.cancel();

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
  Future<void> uploadPendingPhotos({bool ignorePause = false}) async {
    if (syncSettings.isUploadPaused && !ignorePause) {
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

      // Repair pass first: a confirmed upload whose URL never made it onto the
      // image object leaves a record with a broken photo. See
      // _reconcileConfirmedUrls for how that happens.
      await _reconcileConfirmedUrls();

      final dueEntries = mediaOutbox.dueForUpload;
      debugPrint(
          'uploadPendingPhotos: ${dueEntries.length} due of ${mediaOutbox.pendingCount} pending');

      int mediaIndex = 0;
      for (final entry in dueEntries) {
        // Stop as soon as the user pauses mid-run - unless this run is the
        // explicit manual one, which the pause must not cut short.
        if (syncSettings.isUploadPaused && !ignorePause) {
          debugPrint('uploadPendingPhotos: aborting, upload paused mid-run');
          break;
        }
        // Do not upload media whose image object does not exist locally yet.
        // createImageObject enqueues the photo the moment it is captured, but
        // the object itself is only persisted a few steps later in the
        // registration flow - and a sync triggered in between would upload the
        // photo with nowhere to write the resulting URL.
        if (!_imageObjectExists(entry.mediaUID)) {
          debugPrint('uploadPendingPhotos: deferring ${entry.mediaUID} -'
              ' its image object is not saved locally yet');
          continue;
        }

        mediaIndex++;
        syncProgress.value = SyncProgress(
          phase: SyncPhase.media,
          current: mediaIndex,
          total: dueEntries.length,
          label: entry.imageName,
        );
        await _processMediaEntry(entry, user.uid);
      }
      if (dueEntries.isNotEmpty) syncProgress.value = null;

      // Confirmed media may release its local copy - but only once the
      // documents referencing it are themselves in the cloud.
      await mediaOutbox.releaseConfirmedLocalCopies(needsSync: _docNeedsSync);
      _refreshPendingCount();

      // Full state dump: which photo is in which state, with its last error.
      // This is the single most useful artefact when a QC record shows a
      // broken image.
      debugPrint(mediaOutbox.describe());
      final stuck = mediaOutbox.pending;
      if (stuck.isNotEmpty) {
        cloudLogService.warn('media: still pending after run', data: {
          'count': '${stuck.length}',
          'items': stuck
              .map((e) =>
                  '${e.mediaUID}:${e.status}:attempts=${e.attemptCount}:${e.lastError ?? "-"}')
              .join(' | '),
        });
      }
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
      final imageName =
          entry.imageName?.isNotEmpty == true ? entry.imageName! : 'image';
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
          // On web this means the blob URL is dead and no bytes were captured
          // at enqueue time - the photo cannot be recovered by retrying.
          await mediaOutbox.markFailure(
              entry.mediaUID, 'local bytes unavailable',
              localSourceMissing: true);
          cloudLogService.error('media: local bytes unavailable', data: {
            'uid': entry.mediaUID,
            'name': entry.imageName ?? '',
            'path': entry.localPath,
          });
          return;
        }
      } else {
        file = File(entry.localPath);
        if (!await file.exists()) {
          await mediaOutbox.markFailure(
              entry.mediaUID, 'local file missing: ${entry.localPath}',
              localSourceMissing: true);
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
    final verification = await mediaOutbox.verifyRemoteCopy(entry);
    switch (verification) {
      case MediaVerification.missing:
        // Provably not in the cloud - throw the upload away and start over.
        await mediaOutbox.markVerificationFailed(
            entry.mediaUID, 'remote copy missing or wrong size');
        cloudLogService.warn('media: remote copy missing, will re-upload',
            data: {
              'uid': entry.mediaUID,
              'name': entry.imageName ?? '',
              'url': entry.remoteUrl ?? '',
            });
        return;

      case MediaVerification.unverifiable:
        // We could not check (CORS/offline). Keep the upload, retry the check.
        await mediaOutbox.markVerificationDeferred(
            entry.mediaUID, 'verification not possible');
        cloudLogService.warn('media: could not verify remote copy, keeping it',
            data: {
              'uid': entry.mediaUID,
              'name': entry.imageName ?? '',
              'url': entry.remoteUrl ?? '',
            });
        return;

      case MediaVerification.confirmed:
        break;
    }

    await mediaOutbox.markConfirmed(entry.mediaUID);
    cloudLogService.info('media: photo uploaded and verified', data: {
      'name': entry.imageName ?? '',
      'uid': entry.mediaUID,
      'url': entry.remoteUrl ?? '',
      'bytes': '${entry.sizeBytes}',
    });

    await _writeCloudUrlIntoImageObject(entry);
  }

  /// Persists downloadURL/storagePath on the image object via changeObjectData
  /// so the change is documented with its own method history.
  Future<void> _writeCloudUrlIntoImageObject(MediaOutboxEntry entry) async {
    try {
      var doc = await getLocalObjectMethod(entry.mediaUID);
      if (doc.isEmpty) {
        // Without the image object the URL has nowhere to go and the QC view
        // will keep showing a broken image - this must be loud, not a skip.
        debugPrint('media: image object ${entry.mediaUID} NOT FOUND locally,'
            ' cannot store downloadURL');
        cloudLogService.error('media: image object missing, URL not stored',
            data: {'uid': entry.mediaUID, 'name': entry.imageName ?? ''});
        return;
      }
      final existingUrl = getSpecificPropertyfromJSON(doc, "downloadURL");
      if (existingUrl == entry.remoteUrl) {
        debugPrint('media: ${entry.mediaUID} downloadURL already up to date');
        return;
      }

      debugPrint('media: writing downloadURL into image object'
          ' ${entry.mediaUID} (was: "$existingUrl")');

      // CRITICAL: setSpecificPropertyJSON returns a new copy, must reassign!
      doc = setSpecificPropertyJSON(doc, "downloadURL", entry.remoteUrl, "URL");
      doc =
          setSpecificPropertyJSON(doc, "storagePath", entry.remotePath, "URL");
      await changeObjectData(doc, syncFromCloud: false);

      // Read back: changeObjectData performs several writes, and a silent
      // failure here is exactly what produces an image-less QC record.
      final check = await getLocalObjectMethod(entry.mediaUID);
      final storedUrl = getSpecificPropertyfromJSON(check, "downloadURL");
      final persisted = storedUrl == entry.remoteUrl;
      debugPrint('media: downloadURL persisted for ${entry.mediaUID}:'
          ' $persisted (stored: "$storedUrl")');
      if (persisted) {
        cloudLogService.info('media: downloadURL stored on image object',
            data: {'uid': entry.mediaUID, 'url': entry.remoteUrl ?? ''});
      } else {
        cloudLogService.error('media: downloadURL did NOT persist', data: {
          'uid': entry.mediaUID,
          'expected': entry.remoteUrl ?? '',
          'found': '$storedUrl',
        });
      }
    } catch (e) {
      debugPrint('Error writing cloud URL into image object: $e');
      cloudLogService.error('media: could not persist cloud URL',
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

  /// Is the openRAL image object for this media already in local storage?
  bool _imageObjectExists(String mediaUID) {
    if (localStorage == null || !localStorage!.isOpen) return false;
    return localStorage!.get(mediaUID) != null;
  }

  /// Writes missing downloadURLs onto image objects whose upload is already
  /// confirmed.
  ///
  /// Needed because the photo is enqueued at capture time while the image
  /// object is persisted only later in the registration flow. A sync triggered
  /// in between uploaded and confirmed the photo at a moment when there was no
  /// object to write the URL to - leaving a confirmed upload that nothing ever
  /// points at. This pass is idempotent and repairs such records on the next
  /// run.
  Future<void> _reconcileConfirmedUrls() async {
    if (!mediaOutbox.isOpen) return;
    if (localStorage == null || !localStorage!.isOpen) return;

    for (final entry in mediaOutbox.all) {
      if (!entry.isConfirmed) continue;
      final url = entry.remoteUrl;
      if (url == null || url.isEmpty) continue;

      final raw = localStorage!.get(entry.mediaUID);
      if (raw == null) continue; // object still not there - try again next run

      final doc = Map<String, dynamic>.from(raw);
      final stored = getSpecificPropertyfromJSON(doc, "downloadURL");
      if (stored == url) continue; // already correct

      debugPrint('media: repairing missing downloadURL on ${entry.mediaUID}'
          ' (stored: "$stored")');
      cloudLogService.warn('media: repairing missing downloadURL',
          data: {'uid': entry.mediaUID, 'url': url});
      await _writeCloudUrlIntoImageObject(entry);
    }
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
    syncSettings.failedItemCount.value =
        mediaOutbox.isOpen ? mediaOutbox.unrecoverableCount : 0;
  }

//This function syncs all methods and objects to the cloud if tagged as being changed/generated locally only

  Future<bool> syncMethods(String domain,
      {Function(int current, int total)? onProgress,
      Function(int current, int total)? onDownloadProgress,
      VoidCallback? onFetchingFromCloud,
      bool syncFromCloud = true,
      bool force = false,
      bool ignorePause = false}) async {
    // WP A2: the user can suspend all cloud traffic. Local capture and the
    // needsSync flagging keep running - only the wire is silent.
    // [ignorePause] is for the explicit "sync now" button: pausing is meant to
    // stop *automatic* traffic so the user can trigger it deliberately later -
    // a manual press must therefore go through.
    if (syncSettings.isUploadPaused && !ignorePause) {
      debugPrint('[SYNC] skipped (uploadPaused)');
      cloudLogService
          .info('syncMethods: skipped', data: {'reason': 'uploadPaused'});
      return false;
    }

    if (_isSyncing) {
      // A sync cycle writes to the database itself (conflict flagging, clearing
      // sync flags), and every one of those writes runs through
      // setObjectMethod, which in turn triggers a sync. Treating those nested
      // triggers as "another run is needed" makes every cycle schedule a
      // successor - an endless chain that never lets _isSyncing go false again.
      // Only triggers from outside the cycle may request a follow-up.
      if (_isInsideSyncCycle) {
        debugPrint('[SYNC] nested trigger from inside the running cycle,'
            ' ignored');
        return false;
      }
      // WP A3: an external trigger arriving during a run is not dropped - it is
      // remembered and produces exactly one follow-up run.
      _rerunRequested = true;
      debugPrint('Sync already in progress, scheduling exactly one follow-up');
      return false;
    }
    _isSyncing = true;
    isSyncRunning.value = true;
    bool success = false;
    try {
      // The marker lives in the zone, so anything called from within the cycle
      // - however deep - can be told apart from a timer or button press.
      success = await runZoned(
        () => _runSyncCycle(
          domain,
          onProgress: onProgress,
          onDownloadProgress: onDownloadProgress,
          onFetchingFromCloud: onFetchingFromCloud,
          syncFromCloud: syncFromCloud,
          force: force,
          ignorePause: ignorePause,
        ),
        zoneValues: {_syncCycleZoneKey: true},
      );
    } finally {
      _isSyncing = false;
      isSyncRunning.value = false;
      syncProgress.value = null;
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
      bool syncFromCloud = true,
      bool force = false,
      bool ignorePause = false}) async {
    List<String> failedSyncedOutputObjects = [];
    bool cycleSuccess = false;
    int pushedCount = 0;
    int failedCount = 0;
    int deferredCount = 0;
    int pulledCount = 0;
    int conflictCount = 0;
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
      // A manual "sync now" bypasses the backoff: the user asked explicitly,
      // and waiting on an invisible timer is exactly what the button is meant
      // to avoid.
      if (force) {
        debugPrint('[SYNC] manual sync - ignoring retry backoff');
      } else {
        final int backedOffCount = methodsToSyncToCloud
            .where((m) => syncOutbox.isBackedOff(getObjectMethodUID(m)))
            .length;
        if (backedOffCount > 0) {
          methodsToSyncToCloud.removeWhere(
              (m) => syncOutbox.isBackedOff(getObjectMethodUID(m)));
          deferredCount = backedOffCount;
          debugPrint(
              '[SYNC] $backedOffCount method(s) deferred by retry backoff, next due ${syncOutbox.nextDueAt}');
        }
      }

      bool syncSuccess = true;
      int currentMethodIndex = 0;
      final totalMethodsToSync = methodsToSyncToCloud.length;

      for (final method in methodsToSyncToCloud) {
        currentMethodIndex++;
        if (onProgress != null) {
          onProgress(currentMethodIndex, totalMethodsToSync);
        }
        syncProgress.value = SyncProgress(
          phase: SyncPhase.push,
          current: currentMethodIndex,
          total: totalMethodsToSync,
        );

        final doc2 = Map<String, dynamic>.from(method);
        final methodUid = getObjectMethodUID(doc2);
        try {
          debugPrint('Syncing method to cloud: $methodUid');
          Map<String, dynamic> syncresult =
              await apiClient.syncMethodToCloud(domain, doc2);
          if (syncresult["response"] == "success") {
            debugPrint('Method $methodUid synced successfully to cloud');
            pushedCount++;
            await syncOutbox.recordSuccess(methodUid); //clears any retry state
            await setObjectMethod(
                doc2, false, false); //persists removal of sync flag from method
          } else {
            failedCount++;
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
                    conflictCount++;
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
          failedCount++;
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

      // Objects reach the cloud as outputObjects of their methods, so their
      // needsSync flag is cleared here rather than by a push of their own.
      // This depends only on the push results - running it before the pull
      // keeps the flags from piling up on clients that never pull
      // (syncFromCloud: false, e.g. the landscape web app), where they used to
      // stay set forever and inflate the "waiting items" counter.
      await _clearSyncFlagsFor(deviceHashes, failedSyncedOutputObjects);

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

      //*** WP A4: atomic pull phase + WP B2: paginated download ***
      // Incoming documents are written to a staging box first and only moved
      // into localStorage in one batch once the WHOLE payload has arrived -
      // across all pages. A crash mid-pull therefore leaves the local state
      // fully "before"; the next run re-fetches cleanly via the hash
      // comparison. Committing per page would reintroduce exactly the
      // half-updated state A4 exists to prevent.
      await syncOutbox.beginStaging();

      bool paginate = apiClient.supportsPagination(domain);
      int page = 0;
      int stagedCount = 0;
      bool hasMore = true;

      while (hasMore) {
        var cloudData = await apiClient.syncObjectsMethodsFromCloud(
          domain,
          deviceHashes,
          page: paginate ? page : null,
          pageSize: paginate ? _pullPageSize : null,
        );
        debugPrint('[SYNC] pull page $page returned,'
            ' isEmpty=${cloudData.isEmpty}');

        // The paginated endpoint is new. If it fails before delivering
        // anything, fall back to the endpoint that has been in production all
        // along rather than failing the whole pull.
        if (cloudData.isEmpty && paginate && page == 0) {
          debugPrint('[SYNC] paginated endpoint failed on the first page,'
              ' falling back to the classic syncFromCloud');
          cloudLogService.warn('syncMethods: paginated pull unavailable,'
              ' using classic endpoint');
          paginate = false;
          cloudData =
              await apiClient.syncObjectsMethodsFromCloud(domain, deviceHashes);
        }

        // An empty result means an error - discard the staged batch rather than
        // committing a partial download.
        if (cloudData.isEmpty) {
          debugPrint('[SYNC] cloudData is empty, discarding staged pull');
          await syncOutbox.clearStaging();
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
            //Check if the UID of this object is in the failedSyncedOutputObjects, only add if not
            String uid = getObjectMethodUID(item);
            if (!failedSyncedOutputObjects.contains(uid)) {
              mergedList.add(item);
            }
          }
        }

        for (final item in mergedList) {
          stagedCount++;
          // The total diff size is unknown while pages remain, so report an
          // optimistic denominator that converges on the last page.
          final int provisionalTotal =
              hasMore && paginate ? stagedCount + _pullPageSize : stagedCount;
          if (onDownloadProgress != null) {
            onDownloadProgress(stagedCount, provisionalTotal);
          } else if (onProgress != null) {
            onProgress(stagedCount, provisionalTotal);
          }
          syncProgress.value = SyncProgress(
            phase: SyncPhase.pull,
            current: stagedCount,
            total: provisionalTotal,
          );

          final docData = Map<String, dynamic>.from(item);
          docData.remove("needsSync");
          final String docUid = getObjectMethodUID(docData);
          if (docUid.isEmpty) {
            debugPrint('[SYNC] skipping pulled document without UID');
            continue;
          }
          await syncOutbox.stage(docUid, _normalizeIncomingDocument(docData));
        }

        if (!paginate) break; // classic endpoint answers in one response
        hasMore = cloudData["hasMore"] == true;
        final nextPage = cloudData["nextPage"];
        page = nextPage is int ? nextPage : page + 1;

        // Backstop against a server that never stops reporting hasMore.
        if (page >= _maxPullPages) {
          debugPrint('[SYNC] pull page limit ($_maxPullPages) reached,'
              ' discarding incomplete batch');
          cloudLogService.warn('syncMethods: pull page limit reached',
              data: {'pages': '$page', 'staged': '$stagedCount'});
          await syncOutbox.clearStaging();
          return false;
        }
      }

      // Marker + commit: everything before this point is discardable.
      await syncOutbox.markStagingComplete();
      final committed = await syncOutbox.commitStagingInto(localStorage!);
      pulledCount = committed;
      debugPrint('[SYNC] pull phase committed $committed documents atomically'
          ' (${paginate ? "${page + 1} page(s)" : "single response"})');

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
      lastSyncSummary.value = SyncSummary(
        pushed: pushedCount,
        failed: failedCount,
        deferred: deferredCount,
        pulled: pulledCount,
        conflicts: conflictCount,
      );
      _refreshPendingCount();
      debugPrint('[SYNC] summary: pushed=$pushedCount failed=$failedCount '
          'deferred=$deferredCount pulled=$pulledCount '
          'conflicts=$conflictCount');
      cloudLogService.info('syncMethods: finished', data: {
        'domain': domain,
        'success': '$cycleSuccess',
        'pushed': '$pushedCount',
        'failed': '$failedCount',
        'deferred': '$deferredCount',
        'pulled': '$pulledCount',
        'conflicts': '$conflictCount',
      });
    }
  }

  /// Clears `needsSync` on everything that reached the cloud in this cycle.
  ///
  /// Objects are never pushed on their own - they travel as outputObjects of
  /// their methods - so this is the only place their flag is cleared. Items
  /// whose method failed are listed in [failedSyncedOutputObjects] and keep
  /// their flag so the next run retries them.
  Future<void> _clearSyncFlagsFor(Map<String, dynamic> deviceHashes,
      List<String> failedSyncedOutputObjects) async {
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
    cloudLogService
        .info('recoverInterruptedPull', data: {'committed': '$committed'});
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
