// This service syncs local hive database to/from the clouds
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/helpers/json_full_double_to_int.dart';
import 'package:trace_foodchain_app/helpers/sort_json_alphabetically.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/screens/home_screen.dart';
import 'package:trace_foodchain_app/services/get_device_id.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
      debugPrint("Error getting cloud connection properties: $e");
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
        debugPrint("Error sending public key to Firebase: $e");
        return false;
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> getDocumentFromCloud(
      String domain, documentUID) async {
    String? urlString;
    try {
      urlString = getCloudConnectionProperty(
        domain,
        "cloudFunctionsConnector",
        "getRALMethodByUID",
      )["url"];
    } catch (e) {
      debugPrint(
          "Error getting cloud connection property 'syncObjectsMethodsFromCloud': $e");

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
        debugPrint(
            "Failed to get method $documentUID from cloud: ${response.statusCode}");
        return {};
      }
    } else {
      return {};
    }
  }

  Future<Map<String, dynamic>> syncMethodToCloud(
      String domain, Map<String, dynamic> ralMethod) async {
    dynamic urlString;
    Map<String, dynamic> valueMap = Map<String, dynamic>.from(ralMethod as Map);

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
        debugPrint("Sync of Method '$methodUid' successful");

        // return jsonDecode(response.body);
        return {"response": "success"};
      } else {
        //Response codes? 400: Bad Request, 401: Unauthorized, 403: Forbidden, 404: Not Found, 500: Internal Server Error
        //Merge Conflict: 409
        debugPrint(
            "Failed to sync method '$methodUid' to cloud: ${response.statusCode}");
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
      debugPrint(
          "Error getting cloud connection property 'syncObjectsMethodsFromCloud': $e");

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
          debugPrint(
              'Failed to sync objects and methods from cloud: ${response.statusCode}');
          return {};
        }
      } catch (e) {
        debugPrint('Error syncing from cloud: $e');
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

  CloudSyncService(String domain) : apiClient = CloudApiClient(domain: domain);

  Future<void> syncOpenRALTemplates(String domain) async {
    for (var templateName in openRALTemplates.keys) {
      try {
        //If possible, always use the cloud versions of the templates for locale database
        // final cloudTemplate = await _apiClient.getRalObjectByUid(domain,templateName);
        // openRALTemplates.put(templateName, cloudTemplate);
      } catch (e) {
        debugPrint('Error syncing template $templateName: $e');
      }
    }
  }

//This function syncs all methods and objects to the cloud if tagged as being changed/generated locally only

  Future<bool> syncMethods(String domain) async {
    List<String> failedSyncedOutputObjects = [];
    if (_isSyncing) {
      debugPrint("Sync bereits aktiv, überspringe $domain");
      return false;
    }
    _isSyncing = true;
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
      bool syncSuccess = true;
      for (final method in methodsToSyncToCloud) {
        final doc2 = Map<String, dynamic>.from(method);
        final methodUid = getObjectMethodUID(doc2);
        try {
          Map<String, dynamic> syncresult =
              await apiClient.syncMethodToCloud(domain, doc2);
          if (syncresult["response"] == "success") {
            setObjectMethod(
                doc2, false, false); //persists removal of sync flag from method
          } else {
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
                  //ToDo: Flag methods or objects with merge conflicts
                  if (syncresult["responseDetails"]
                      .containsKey("methodConflict")) {
                    //problem to merge method
                    //     - cloudVersionInvalid
                    //     - clientVersionInvalid
                    //     - conflictReasonUnknown
                    Map<String, dynamic> conflictMethod =
                        await getLocalObjectMethod(getObjectMethodUID(doc2));
                    conflictMethod["hasMergeConflict"] = true;
                    conflictMethod["mergeConflictReason"] =
                        syncresult["responseDetails"]["methodConflict"];
                    await setObjectMethod(conflictMethod, false, true);
                  }
                  if (syncresult["responseDetails"]
                      .containsKey("conflictObjects")) {
                    // conflictObjects: List of objects with merge conflicts
                    // "objectUid": "a9b94df2-2ad8-4f2f-b469-3d8bb6f9f054" => flag as problematic
                    for (final object in syncresult["responseDetails"]
                        ["conflictObjects"]) {
                      Map<String, dynamic> conflictObject =
                          await getLocalObjectMethod(object["objectUid"]);
                      conflictObject["hasMergeConflict"] = true;
                      await setObjectMethod(conflictObject, false, true);
                    }
                  }

                  break;
                case "400":
                  //general problem: one of
                  // missingParameters:
                  // invalidSignature => Flag method as invalid
                  // errorMessage
                  debugPrint(
                      "Error syncing method {$methodUid}: 400: ${syncresult["responseDetails"]}");
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
          snackbarMessageNotifier.value = "unknown error syncing to cloud";
          // globalSnackBarNotifier.value = {
          //   'type': 'error',
          //   'text': "error syncing to cloud",
          //   'errorCode': "unknown error"
          // };
          debugPrint('Error syncing method {$methodUid}: $e');
        }
        if (syncSuccess) {
          snackbarMessageNotifier.value = "sync to cloud successful";
          // globalSnackBarNotifier.value = {
          //   'type': 'info',
          //   'text': 'sync to cloud successful'
          // };
        }
      }

      //******* 2. SYNC METHODS AND OBJECTS FROM CLOUD - independet of new methods on device ********
      //This happens in case a user has logged into a second device (e.g., webapp on PC)
      //1. Generate a hash list from all objects and methods on the device

      //2. Get all objects and methods from the cloud that are not on the device or need to be updated
      final cloudData =
          await apiClient.syncObjectsMethodsFromCloud(domain, deviceHashes);
      // this will return an empty object in case there is an error.
      if (cloudData.isEmpty) {
        debugPrint("Unknown error syncing from cloud!");
        return false;
      }

      // Fusioniere die beiden Listen "ralMethods" und "ralObjects" zu einer final mergedList
      List<dynamic> mergedList = [];
      if (cloudData.containsKey("ralMethods") &&
          cloudData["ralMethods"] is List) {
        debugPrint(
            "Got ${cloudData["ralMethods"].length} updated methods from cloud");

        mergedList.addAll(cloudData["ralMethods"]);
      }
      if (cloudData.containsKey("ralObjects") &&
          cloudData["ralObjects"] is List) {
        debugPrint(
            "Got ${cloudData["ralObjects"].length} updated objects from cloud");
        for (final item in cloudData["ralObjects"]) {
          // debugPrint(getObjectMethodUID(item));
          //Check if the UID of this object is in the failedSyncedOutputObjects, only add if not
          String uid = getObjectMethodUID(item);
          if (!failedSyncedOutputObjects.contains(uid)) {
            mergedList.add(item);
          }
        }
      }
      // bool downloadedFirst = false;
      for (final item in mergedList) {
        final docData = Map<String, dynamic>.from(item);

        //debugPrint(jsonEncode(docData));
        docData.remove("needsSync");
        await setObjectMethod(docData, false, false);
      }

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
    } catch (e) {
      debugPrint("Error during syncing to cloud: $e !");
      return false;
    } finally {
      _isSyncing = false;
      return true;
    }
  }
}

///Returns the SHA-256 hash of a Utf8 encoded JSON string as a hex string
///Can be converted to bytes with utf8.encode(hashString)
String generateStableHash(Map<String, dynamic> docData) {
  Map<String, dynamic> valueMap = Map<String, dynamic>.from(docData as Map);

  valueMap =
      convertToJson(valueMap); //Replace Datetime and GeoPoint with JSON objects

  //Avoid json string with double like 1000.0 -> because on some platforms doubles are stringified without the .0
  valueMap = jsonFullDoubleToInt(valueMap);

  //Sort alphabetically to ensure getting the same hash for the same data
  valueMap = sortJsonAlphabetically(valueMap);

  final jsonString = jsonEncode(valueMap);
  // if (valueMap.keys.contains("methodHistoryRef")) {
  //   debugPrint(jsonString);
  // }
  final String uid = getObjectMethodUID(docData);

  //debugPrint("JSON String for Hash: '$jsonString'");

  final bytes = utf8.encode(jsonString);

  // debugPrint("Bytes Length: ${bytes.length}");
  // debugPrint("First 10 Bytes: ${bytes.sublist(0, 10)}");

  final hashStr = sha256.convert(bytes).toString();

  return hashStr;
}
