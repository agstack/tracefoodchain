import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/models/harvest_model.dart';
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
    for (var key2 in localStorage.keys) {
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
  Future<List<Map<String, dynamic>>> getContainers(String ownerUID) async {
    List<Map<String, dynamic>> rList = [];
    debugPrint("getting containers owned by $ownerUID");
    for (var doc in localStorage.values) {
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
              rList.add(doc2);
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
    for (var doc in localStorage.values) {
      if (doc["currentGeolocation"] != null) {
        final currentOwnerIncomingUID =
            doc["currentGeolocation"]["container"]["UID"];

        if (currentOwnerIncomingUID == ownerUID) {
          debugPrint(
              "found ${doc["template"]["RALType"]} ${doc["identity"]["UID"]}");
          Map<String, dynamic> doc2 = Map<String, dynamic>.from(doc);
          rList.add(doc2);
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
        allItems.add(item);

        String nestedContainerUID = item['identity']['UID'];
        await processContainer(nestedContainerUID);
      }
    }

    await processContainer(containerUID);
    return allItems;
  }

  Future<List<Map<String, dynamic>>> getContainedItems(
      String containerUID) async {
    List<Map<String, dynamic>> rstring = [];
    for (var doc in localStorage.values) {
      try {
        final containerUID2 = doc["currentGeolocation"]["container"]["UID"];

        if (containerUID2 == containerUID) {
          Map<String, dynamic> doc2 = Map<String, dynamic>.from(doc);
          rstring.add(doc2);
        }
      } catch (e) {}
    }
    return rstring;
  }

  Future<Map<String, dynamic>> getFirstSale(Map<String, dynamic> coffee) async {
    Map<String, dynamic> rstring = {};
    final firstSaleUID = coffee["methodHistoryRef"]
        .firstWhere((method) => method["RALType"] == "changeContainer")["UID"];
    final firstSale = await getObjectMethod(firstSaleUID);
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
    return 'N/A';
  }
  try {
    return DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
  } catch (e) {
    print('Error formatting timestamp: $e');
    return 'Invalid Date';
  }
}
