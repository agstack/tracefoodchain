import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/models/harvest_model.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import 'package:trace_foodchain_app/screens/settings_screen.dart';
import 'package:trace_foodchain_app/services/cloud_sync_service.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const String harvestsBoxName = 'harvests';

  Future<void> initializeDatabase() async {
    await Hive.initFlutter();
    Hive.registerAdapter(HarvestModelAdapter());
    await Hive.openBox<HarvestModel>(harvestsBoxName);
  }

  Future<List<Map<String, dynamic>>> getProductsWithPrices() async {
    List<Map<String, dynamic>> rstring = [];
    //ToDo: Missing
    return rstring;
  }

  Future<List<HarvestModel>> getHarvests() async {
    final box = Hive.box<HarvestModel>(harvestsBoxName);
    return box.values.toList();
  }

  Future<void> insertHarvest(HarvestModel harvest) async {
    final box = Hive.box<HarvestModel>(harvestsBoxName);
    await box.add(harvest);
  }

  Future<void> updateHarvest(HarvestModel harvest) async {
    final box = Hive.box<HarvestModel>(harvestsBoxName);
    await box.put(harvest.key, harvest);
  }

  Future<void> deleteHarvest(HarvestModel harvest) async {
    final box = Hive.box<HarvestModel>(harvestsBoxName);
    await box.delete(harvest.key);
  }

  Future<List<Map<String, dynamic>>> getOrdersForBuyer(String userId) async {
    List<Map<String, dynamic>> rstring = [];
    //ToDo: Missing
    return rstring;
  }

  Future<List<Map<String, dynamic>>> getInventory() async {
    List<Map<String, dynamic>> rstring = [];
    //ToDo: Missing
    return rstring;
  }

  Future<String> updateInventoryItem(Map<String, dynamic> inventoryItem) async {
    String rstring = "";
    //ToDo: Missing
    return rstring;
  }

  Future<String> syncHarvests(Map<String, dynamic> harvests) async {
    String rstring = "";
    //ToDo: Missing
    return rstring;
  }

  Future<String> updateDeliveryStatus(
      Map<String, dynamic> harvests, String newStatus) async {
    String rstring = "";
    //ToDo: Missing
    return rstring;
  }

  Future<List<Map<String, dynamic>>> getDeliveryHistory() async {
    List<Map<String, dynamic>> rstring = [];
    //ToDo: Missing
    return rstring;
  }

  Future<List<Map<String, dynamic>>> getActiveDeliveries() async {
    List<Map<String, dynamic>> rstring = [];
    //ToDo: Missing
    return rstring;
  }

  Future<void> deleteFromBox<T>(String boxName, dynamic key) async {
    final box = Hive.box<T>(boxName);
    bool deleted = false;
    for (var key2 in localStorage!.keys) {
      if (key2 == key) {
        await box.delete(key);
        debugPrint("Deleted $key");
        deleted = true;
        break;
      }
    }
    if (!deleted) debugPrint("Could not delete $key");
  }

//This function looks for all containers (of all kinds) that are owned by the user and are not nested within other containers
  List<Map<String, dynamic>> getContainers(String ownerUID) {
    // if (accountUID!="") ownerUID = accountUID; // TESTACCOUNT
    List<Map<String, dynamic>> rList = [];
    debugPrint("getting containers owned by $ownerUID");
    for (var doc in localStorage!.values) {
      if (["bag", "container", "building", "transportVehicle"]
          .contains(doc["template"]["RALType"])) {
        //ToDo: get a dynamic list of what is a container
        final currentOwners = doc["currentOwners"];
        for (var owner in currentOwners) {
          if (owner["UID"] == ownerUID) {
            //Check if it is not nested within other containers!
            if ((doc["currentGeolocation"]["container"]["UID"] == "") ||
                (doc["currentGeolocation"]["container"]["UID"] == "unknown")) {
              debugPrint(
                  "found ${doc["template"]["RALType"]} ${doc["identity"]["UID"]}");
              Map<String, dynamic> doc2 = Map<String, dynamic>.from(doc);
              if ((isTestmode && doc2.containsKey("isTestmode")) ||
                  (!isTestmode && !doc2.containsKey("isTestmode"))) {
                rList.add(doc2);
              }
              break;
            }
          }
        }
      }
    }

    return rList;
  }

  Future<List<Map<String, dynamic>>> getInboxItems(String ownerUID) async {
    List<Map<String, dynamic>> rList = [];
    debugPrint("getting inbox items for $ownerUID");
    for (var doc in localStorage!.values) {
      if (doc["currentGeolocation"] != null) {
        final currentGeolocationIncomingUID =
            doc["currentGeolocation"]["container"]["UID"];

        bool isOwner = false;
        if (doc.containsKey("currentOwners") && doc["currentOwners"] is List) {
          isOwner = (doc["currentOwners"] as List)
              .any((owner) => owner["UID"] == ownerUID);
        }

        if (isOwner && currentGeolocationIncomingUID == "inTransfer") {
          //if user is owner and container is empty => inbox
          debugPrint(
              "found ${doc["template"]["RALType"]} ${doc["identity"]["UID"]}");
          Map<String, dynamic> doc2 = Map<String, dynamic>.from(doc);
          if ((isTestmode && doc2.containsKey("isTestmode")) ||
              (!isTestmode && !doc2.containsKey("isTestmode"))) rList.add(doc2);
          break;
        }
      }
    }

    return rList;
  }

  Future<List<Map<String, dynamic>>> getNestedContainedItems(
      String containerUID) async {
    Set<String> processedContainers = {};
    List<Map<String, dynamic>> allItems = [];

    Future<void> processContainer(String uid) async {
      if (processedContainers.contains(uid)) {
        return; // Avoid circular references
      }
      processedContainers.add(uid);

      List<Map<String, dynamic>> items = await getContainedItems(uid);
      for (var item in items) {
        if ((isTestmode && item.containsKey("isTestmode")) ||
            (!isTestmode && !item.containsKey("isTestmode"))) {
          allItems.add(item);
        }

        String nestedContainerUID = item['identity']['UID'];
        await processContainer(nestedContainerUID);
      }
    }

    await processContainer(containerUID);
    return allItems;
  }

  Future<List<Map<String, dynamic>>> getContainedItems(
      String containerUID) async {
    List<Map<String, dynamic>> rList = [];
    for (var doc in localStorage!.values) {
      try {
        final containerUID2 = doc["currentGeolocation"]["container"]["UID"];

        if (containerUID2 == containerUID) {
          Map<String, dynamic> doc2 = Map<String, dynamic>.from(doc);
          if ((isTestmode && doc2.containsKey("isTestmode")) ||
              (!isTestmode && !doc2.containsKey("isTestmode"))) rList.add(doc2);
        }
      } catch (e) {}
    }
    return rList;
  }

  Future<Map<String, dynamic>> getFirstSale(
      BuildContext context, Map<String, dynamic> coffee) async {
    final appState = Provider.of<AppState>(context, listen: false);
    Map<String, dynamic> rstring = {};
    final firstSaleUID = coffee["methodHistoryRef"]
        .firstWhere((method) => method["RALType"] == "changeContainer")["UID"];
    Map<String, dynamic> firstSale = await getLocalObjectMethod(firstSaleUID);
    //if this method has not been synced from cloud, we need to force downsync!
    if (firstSale.isEmpty && appState.isConnected) {
      final firstSaleDoc = await cloudSyncService.apiClient
          .getDocumentFromCloud("tracefoodchain.org", firstSaleUID);
      if (firstSaleDoc.isNotEmpty) {
        await setObjectMethod(firstSaleDoc, false, false);
        firstSale = await getLocalObjectMethod(firstSaleUID);
      }
    }

    Map<String, dynamic> doc2 = Map<String, dynamic>.from(firstSale);
    rstring = firstSale;
    return rstring;
  }

  Future<List<Map<String, dynamic>>> getImportHistory() async {
    List<Map<String, dynamic>> rstring = [];
    //ToDo: Missing
    return rstring;
  }

  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    List<Map<String, dynamic>> rstring = [];
    //ToDo: Missing
    return rstring;
  }

  Future<List<Map<String, dynamic>>> buyHarvest(
      Map<String, dynamic> harvest, double quantity, price) async {
    List<Map<String, dynamic>> rstring = [];
    //ToDo: Missing
    return rstring;
  }

  Future<List<Map<String, dynamic>>> sellHarvest(
      Map<String, dynamic> harvest, double quantity, price) async {
    List<Map<String, dynamic>> rstring = [];
    //ToDo: Missing
    //1. get openRAL template of
    return rstring;
  }

  Future<List<Map<String, dynamic>>> getShoppingCart(String userId) async {
    List<Map<String, dynamic>> rstring = [];
    //ToDo: Missing
    return rstring;
  }

  Future<List<Map<String, dynamic>>> insertContainer(
      Map<String, dynamic> container) async {
    List<Map<String, dynamic>> rstring = [];
    //ToDo: Missing
    return rstring;
  }
}

String formatTimestamp(dynamic timestamp) {
  if (timestamp is! DateTime) {
    if (timestamp is String) {
      final parsedDate = DateTime.tryParse(timestamp);
      if (parsedDate != null) {
        return DateFormat('yyyy-MM-dd HH:mm').format(parsedDate);
      }
    }
    return 'N/A';
  }
  try {
    return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
  } catch (e) {
    print('Error formatting timestamp: $e');
    return 'Invalid Date';
  }
}

/// Converts parts of the object to a format that can be encoded to JSON
/// e.g. DateTime is converted to ISO8601 string
/// GeoPoint is converted to a map with latitude and longitude
dynamic convertToJson(dynamic firestoreObj) {
  if (firestoreObj is List) {
    return firestoreObj.map((item) => convertToJson(item)).toList();
  } else if (firestoreObj is Map) {
    final Map<String, dynamic> convertedObj = {};
    firestoreObj.forEach((key, value) {
      try {
        if (value is Timestamp) {
          convertedObj[key] = {
            '_seconds': value.seconds,
            '_nanoseconds': value.nanoseconds,
          };
        } else if (value is DateTime) {
          final dateInSeconds = DateTime.fromMillisecondsSinceEpoch(
            (value.millisecondsSinceEpoch ~/ 1000) * 1000,
          );
          String isoString =
              dateInSeconds.toIso8601String().split('.').first.trim();
          convertedObj[key] = isoString;
        } else if (value.runtimeType.toString() == 'GeoPoint') {
          // Expliziter Typ-Check mit runtimeType
          final latitude = value.latitude;
          final longitude = value.longitude;
          convertedObj[key] = {'latitude': latitude, 'longitude': longitude};
        } else {
          convertedObj[key] = convertToJson(value);
        }
      } catch (e) {
        // Bei Fehlern versuchen wir, das GeoPoint direkt zu erkennen
        try {
          if (value != null &&
              value.runtimeType.toString().contains('GeoPoint')) {
            debugPrint("Spezielle GeoPoint-Konvertierung für $key");
            convertedObj[key] = {
              'latitude': value.latitude,
              'longitude': value.longitude,
            };
          } else {
            debugPrint(
              "Konvertierungsfehler für Schlüssel $key: $e - Typ war: ${value?.runtimeType}",
            );
            convertedObj[key] = null; // Standardwert bei Fehlern
          }
        } catch (innerError) {
          debugPrint("Innerer Fehler bei Konvertierung von $key: $innerError");
          convertedObj[key] = null;
        }
      }
    });
    return convertedObj;
  } else if (firestoreObj is DateTime) {
    final dateInSeconds = DateTime.fromMillisecondsSinceEpoch(
      (firestoreObj.millisecondsSinceEpoch ~/ 1000) * 1000,
    );
    String isoString = dateInSeconds.toIso8601String().split('.').first.trim();
    return isoString;
  } else if (firestoreObj != null &&
      firestoreObj.runtimeType.toString().contains('GeoPoint')) {
    // Direkter Zugriff auf GeoPoint außerhalb einer Map
    try {
      return {
        'latitude': firestoreObj.latitude,
        'longitude': firestoreObj.longitude,
      };
    } catch (e) {
      debugPrint("Fehler bei direkter GeoPoint-Konvertierung: $e");
      return null;
    }
  } else {
    // Simple datatype like string or number
    return firestoreObj;
  }
}
// dynamic convertToJson(dynamic firestoreObj) {
//   if (firestoreObj is List) {
//     return firestoreObj.map((item) => convertToJson(item)).toList();
//   } else if (firestoreObj is Map) {
//     final Map<String, dynamic> convertedObj = {};
//     firestoreObj.forEach((key, value) {
//       if (value is Timestamp) {
//         convertedObj[key] = {
//           '_seconds': value.seconds,
//           '_nanoseconds': value.nanoseconds
//         };
//       } else if (value is DateTime) {
//         final dateInSeconds = DateTime.fromMillisecondsSinceEpoch(
//             (value.millisecondsSinceEpoch ~/ 1000) * 1000);
//         String isoString =
//             dateInSeconds.toIso8601String().split('.').first.trim();
//         // debugPrint("ISOSTRING: >>>" + isoString+"<<<");
//         convertedObj[key] = isoString;
//       } else if (value is GeoPoint) {
//         convertedObj[key] = {
//           'latitude': value.latitude,
//           'longitude': value.longitude
//         };
//       } else {
//         convertedObj[key] = convertToJson(value);
//       }
//     });
//     return convertedObj;
//   } else if (firestoreObj is DateTime) {
//     final dateInSeconds = DateTime.fromMillisecondsSinceEpoch(
//         (firestoreObj.millisecondsSinceEpoch ~/ 1000) * 1000);
//     String isoString = dateInSeconds.toIso8601String().split('.').first.trim();
//     // debugPrint("ISOSTRING: >>>" + isoString+"<<<");

//     return isoString;
//   } else {
//     // Simple datatype like string or number
//     return firestoreObj;
//   }
// }

dynamic convertToFirestore(dynamic jsonObj) {
  if (jsonObj is List) {
    return jsonObj.map((item) => convertToFirestore(item)).toList();
  } else if (jsonObj is Map) {
    final Map<String, dynamic> convertedObj = {};
    jsonObj.forEach((key, value) {
      if (value is Map && hasTwoKeys(value)) {
        if (value.containsKey('_seconds') &&
            value.containsKey('_nanoseconds')) {
          convertedObj[key] =
              Timestamp(value['_seconds'], value['_nanoseconds']);
        } else if (value.containsKey('_latitude') &&
            value.containsKey('_longitude')) {
          convertedObj[key] = GeoPoint(value['_latitude'], value['_longitude']);
        } else {
          convertedObj[key] = convertToFirestore(value);
        }
      } else {
        convertedObj[key] = convertToFirestore(value);
      }
    });
    return convertedObj;
  } else {
    // Simple datatype like string or number
    return jsonObj;
  }
}

/// Helper method to check if the object has exactly two keys
bool hasTwoKeys(Map obj) {
  return obj.keys.length == 2;
}
