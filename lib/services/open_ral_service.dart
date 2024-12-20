//This is a collection of services for working with openRAL
//It has to work online and offline, so we have to use Hive to store templates
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/repositories/initial_data.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

var uuid = const Uuid();

//! 1. CloudConnectors

Map<String, Map<String, dynamic>> getCloudConnectors() {
  debugPrint("loading cloud connectors");
  Map<String, Map<String, dynamic>> rList = {};
  for (var doc in localStorage.values) {
    if (doc['template'] != null &&
        doc['template']["RALType"] == "cloudConnector") {
      final doc2 = Map<String, dynamic>.from(doc);
      final domain = getSpecificPropertyfromJSON(doc2, "cloudDomain");
      rList.addAll({domain: doc2});
    }
  }

  //Inital App startup: populate with cloudConnectors from init repo
  for (final cc in initialCloudConnectors) {
    if (!localStorage.containsKey(getObjectMethodUID(cc))) {
      final domain = getSpecificPropertyfromJSON(cc, "cloudDomain");
      rList.addAll({domain: cc});
      //add to hive
      localStorage.put(getObjectMethodUID(cc), cc);
    }
  }

  return rList;
}

dynamic getCloudConnectionProperty(String domain, connectorType, property) {
  dynamic rObject;
  try {
    // domain und subconnector suchen (connectorType)
    final subConnector = cloudConnectors[domain]!["linkedObjects"]
        .firstWhere((subConnector) => subConnector["role"] == connectorType);
    //gewünschte Eigenschaft lesen
    rObject = getSpecificPropertyfromJSON(subConnector, property);
  } catch (e) {
    debugPrint(
        "The requested cloud function property $property does not exist!");
    rObject = null;
  }

  return rObject;
}

//! 2. getTemplate: get an empty openRAL object or method template from local template storage

Future<Map<String, dynamic>> getOpenRALTemplate(String templateName) async {
  Map<String, dynamic> rMap = {};
  try {
    Map<String, dynamic> res =
        json.decode(json.encode(openRALTemplates.get(templateName)));
    rMap = Map<String, dynamic>.from(res);
  } catch (e) {
    debugPrint("Problem");
  }
  return rMap;
}

Future<Map<String, dynamic>> getRALObjectMethodTemplateAsJSON(
    String objectType) async {
  Map<String, dynamic> json = {};

  try {
// Get a JSON template via REST API from RAL mothership
    var url2 =
        '${getCloudConnectionProperty("open-ral.io", "cloudFunctionsConnector", "smartRequestTemplateWeb")["url"]}?apiKey=${getCloudConnectionProperty("open-ral.io", "cloudFunctionsConnector", "apiKey")}&templateName=$objectType&returnFormat=JSON'; //no version requested = most current version
    Uri uri2 = Uri.parse(url2);

    var response2 = await http.get(uri2);
    if (response2.statusCode == 200) {
      //Valides Template kam zurück
      try {
        json = jsonDecode(response2.body);
      } catch (e) {
        print("ERROR: Could not pars json from RAL!");
      }
    } else {
      print("Error requesting RAL template via REST");
    }

    // _json = jsonDecode(jsonString);
  } catch (e) {
    //ToDo: Handle errors
  }

  return json;
}

//! 3.#######  getters for working with openRAL objects ############

Future<Map<String, dynamic>> getRALObjectFromDomain(
    String domain, String objectUID) async {
  Map<String, dynamic> returnObject = {};
  if (cloudConnectors.isEmpty) getCloudConnectors();

  String? dscMetadataUrl;
  String dscMetadataUuidField =
      "databaseID"; //ToDo: this is permarobotics specific - read from object connector
  String dscMetadataEndpoint =
      "getSensorInfo"; //ToDo: this is permarobotics specific - read from object connector

  if (domain != "") {
    dscMetadataUrl = getCloudConnectionProperty(
        domain, "cloudFunctionsConnector", dscMetadataEndpoint)["url"];
    debugPrint("url is $dscMetadataUrl");

//ToDo: ÄNDERN, API KEY IM HEADER ÜBERMITTELN!!!!!

    // var url2 =
    //     '$dsc_metadata_url?${dsc_metadata_uuid_field}=${objectUID}?apiKey=${getCloudConnectionProperty("permarobotics.com", "cloudFunctionsConnector", "apiKey")}'; //databaseID
    var url2 = '$dscMetadataUrl?$dscMetadataUuidField=$objectUID'; //databaseID
    Uri uri2 = Uri.parse(url2);

    var response2 = await http.get(uri2);
    if (response2.statusCode == 200) {
      returnObject = jsonDecode(response2.body)[0];
    } else {
      debugPrint("could not get object from domain $domain");
      returnObject = {};
    }
  } else {
    debugPrint("ERROR: no domain specified!");
    returnObject = {};
  }
  return returnObject;
}

//Get object or method from local database
Future<Map<String, dynamic>> getObjectMethod(String objectMethodUID) async {
  Map<String, dynamic> doc2 = {};
  try {
    for (var doc in localStorage.values) {
      if (doc['identity'] != null &&
          doc['identity']["UID"] == objectMethodUID) {
        doc2 = Map<String, dynamic>.from(doc);
        break;
      }
      //return doc2;
    }
  } catch (e) {
    return {};
  }
  return doc2;
}

// a) IDENTITY
String getObjectMethodUID(Map<String, dynamic> objectMethod) {
  try {
    return objectMethod["identity"]["UID"];
  } catch (e) {
    return "";
  }
}

// b) LOCATION

// c) METHODHISTORY

// d) SPECIFIC PROPERTIES
dynamic getSpecificPropertyfromJSON(
    Map<String, dynamic> jsonDoc, String property) {
  dynamic rstring;
  final ssnodes = jsonDoc["specificProperties"];

//! ***************** Legacy Map ************************
  if (ssnodes is Map) {
    try {
      rstring = ssnodes[property];
      if (rstring == null) return "-no data found-";
      return rstring;
    } catch (e) {
      return "-no data found-";
    }
  } else {
    try {
      for (var node in ssnodes) {
        if (node["name"] != null) {
          if (node["name"] == property) {
            rstring = node["value"];
          }
        } else {
          if (node["key"] == property) {
            rstring = node["value"];
          }
        }
      }
    } catch (e) {}
    rstring ??= '-no data found-';
    return rstring;
  }
}

String getSpecificPropertyUnitfromJSON(
    Map<String, dynamic> jsonDoc, String property) {
  String rstring = '-no data found-';
  final ssnodes = jsonDoc["specificProperties"];
  for (var node in ssnodes) {
    if (node["name"] != null) {
      if (node["name"] == property) {
        rstring = node["unit"];
      }
    } else {
      if (node["key"] == property) {
        rstring = node["unit"];
      }
    }
  }
  return rstring;
}
// e) LINKED OBJECTS / OBJECT REFERENCES

// f) INPUTOBJECTS

// d) OUTPUTOBJECTS

//! 4.#########  setters for working with openRAL objects ########

Future<Map<String, dynamic>> setObjectMethod(
    Map<String, dynamic> objectMethod, bool markForSyncToCloud) async {
  //Make sure it gets a valid
  if (getObjectMethodUID(objectMethod) == "") {
    setObjectMethodUID(objectMethod, uuid.v4());
    if (objectMethod.containsKey("existenceStarts")) {
      if (objectMethod["existenceStarts"] == null) {
        objectMethod["existenceStarts"] = DateTime
            .now(); //ToDo: Test: Can this be stored in Hive? Otherwise ISO8601 String!
      }
    }
  }

  if (objectMethod["role"] != null) {
    objectMethod.remove("role");
    //Remove unwanted role declaration of objects
  }

  //!tag for syncing
  if (markForSyncToCloud) objectMethod["needsSync"] = true;

  await localStorage.put(getObjectMethodUID(objectMethod), objectMethod);
  var connectivityResult = await (Connectivity().checkConnectivity());
  //if connected to the internet, immediately sync to cloud, otherwise it has just been synced and only needs local persistence
  if (objectMethod["needsSync"] != null) {
    if ((objectMethod["needsSync"] == true) &&
        (!connectivityResult.contains(ConnectivityResult.none))) {
      await cloudSyncService.syncObjectsAndMethods('permarobotics.com');
    }
  }
  return objectMethod;
}

// a) IDENTITY
Map<String, dynamic> setObjectMethodUID(
    Map<String, dynamic> objectMethod, String uid) {
  Map<String, dynamic> rMap = objectMethod;
  objectMethod["identity"]["UID"] = uid;
  return rMap;
}

// b) LOCATION

// c) METHODHISTORY

// d) SPECIFIC PROPERTIES
Map<String, dynamic> setSpecificPropertyJSON(
    Map<String, dynamic> jsonDoc, String name, dynamic value, String unit) {
  Map<String, dynamic> jdoc = Map<String, dynamic>.from(jsonDoc);
  String newUnit = "";
  if (unit == "") {
    newUnit = getSpecificPropertyUnitfromJSON(jsonDoc, name);
  } else {
    newUnit = unit;
  }
  try {
    jdoc["specificProperties"]
            .firstWhere((o) => o["name"] == name || o["key"] == name)['value'] =
        value;
    jdoc["specificProperties"]
            .firstWhere((o) => o["name"] == name || o["key"] == name)['unit'] =
        newUnit;
  } catch (e) {
//Property does not exist, add...
    try {
      (jdoc["specificProperties"] as List)
          .add({"key": name, "value": value, "unit": newUnit});
    } catch (e) {
      Map<String, dynamic> myAdd = {
        "key": name,
        "value": value,
        "unit": newUnit
      };

      Map<String, String> stringMap = myAdd.cast<String, String>();
      List<Map<String, dynamic>> sp = jdoc["specificProperties"];
      sp.add(stringMap);
    }
  }
  return jdoc;
}
// e) LINKED OBJECTS / OBJECT REFERENCES

// f) INPUTOBJECTS
Map<String, dynamic> addInputobject(
    Map<String, dynamic> method, Map<String, dynamic> object, String role) {
  if (method['inputObjects'] == null) {
    method['inputObjects'] = [];
  }

  // Extract UID from the object to be added
  var newObjectUID = object['identity']?['UID'];

  // Check if 'inputObjects' already contains an object with the same UID
  bool exists =
      method['inputObjects'].any((o) => o['identity']?['UID'] == newObjectUID);

  if (!exists) {
    object["role"] = role;
    method['inputObjects'].add(object);
  } else {
    debugPrint(
        'An object with UID $newObjectUID already exists in inputObjects.');
  }

  return method;
}

// d) OUTPUTOBJECTS
Map<String, dynamic> addOutputobject(
    Map<String, dynamic> method, Map<String, dynamic> object, String role) {
  if (method['outputObjects'] == null) {
    method['outputObjects'] = [];
  }

  // Extract UID from the object to be added
  var newObjectUID = object['identity']?['UID'];

  // Find the index of the object with the same UID, if it exists
  int index = method['outputObjects']
      .indexWhere((o) => o['identity']?['UID'] == newObjectUID);

  if (index == -1) {
    // If the object does not exist, add it to the list
    object["role"] = role;
    method['outputObjects'].add(object);
  } else {
    // If the object exists, replace it
    debugPrint(
        'An object with UID $newObjectUID already exists in outputObjects, replacing...');
    object["role"] = role; // Ensure the role is updated
    method['outputObjects'][index] = object;
  }

  return method;
}

Future updateMethodHistories(Map<String, dynamic> jsonDoc) async {
  final methodUID = jsonDoc["identity"]["UID"];
  final methodRALType = jsonDoc["template"]["RALType"];
//Alle inputObject und outputobjects extrahieren
//Für jedes Objekt: Objekt laden, MethodHistoryRef holen - schaun ob das Objekt schon dranhängt, ansonsten dranhängen
  final ouidList = [];
  if (jsonDoc["inputObjects"] != null)
    for (final obj in jsonDoc["inputObjects"]) {
      ouidList.add(obj["identity"]["UID"]);
    }

  if (jsonDoc["inputObjectsRef"] != null)
    for (final obj in jsonDoc["inputObjectsRef"]) {
      if (!ouidList.contains(obj["UID"])) ouidList.add(obj["UID"]);
    }

  if (jsonDoc["outputObjects"] != null)
    for (final obj in jsonDoc["outputObjects"]) {
      if (!ouidList.contains(obj["UID"])) ouidList.add(obj["identity"]["UID"]);
    }

  if (jsonDoc["outputObjectsRef"] != null)
    for (final obj in jsonDoc["outputObjectsRef"]) {
      if (!ouidList.contains(obj["UID"])) ouidList.add(obj["UID"]);
    }

  for (final uid in ouidList) {
    print("checking $uid");
    final oDoc = await getObjectMethod(uid);
    if (oDoc.isNotEmpty) {
      try {
        if (oDoc["methodHistoryRef"]
            .firstWhere((element) => element["UID"] == methodUID,
                orElse: () => {})
            .isEmpty) {
          //Check if already in List
          print("Eintrag $methodUID existiert noch nicht in Methodhistory!");
          oDoc["methodHistoryRef"]
              .add({"UID": methodUID, "RALType": methodRALType});

          await setObjectMethod(oDoc, true);
        } else {
          print("Eintrag $methodUID existiert schon in Methodhistory");
        }
      } catch (e) {
        print("Knoten MethodHistory existiert noch nicht in $uid");
        oDoc["methodHistoryRef"] = {"UID": methodUID, "RALType": methodRALType};

        await setObjectMethod(oDoc, true);
      }
    }
  }
}

Future<List<Map<String, dynamic>>> getContainedItems(
    Map<String, dynamic> item) async {
  List<Map<String, dynamic>> rList = [];
//ToDo: iteratively cycle through all contained items until a container is empty

  return rList;
}

Future<Map<String, dynamic>> getObjectOrGenerateNew(
    String uid, type, field) async {
  Map<String, dynamic> rDoc = {};
  //check all items with this type: do they have the id on the field?
  List<Map<dynamic, dynamic>> candidates = localStorage.values
      .where((candidate) => candidate['template']["RALType"] == type)
      .toList();
  for (dynamic candidate in candidates) {
    Map<String, dynamic> candidate2 = Map<String, dynamic>.from(candidate);
    switch (field) {
      case "uid":
        if (candidate2["identity"]["UID"] == uid) rDoc = candidate2;
        break;
      case "alternateUid":
        if (candidate2["identity"]["alternateIDs"].length != 0) {
          if (candidate2["identity"]["alternateIDs"][0]["UID"] == uid) {
            rDoc = candidate2;
          }
        }
        break;
      default:
    }
    if (rDoc.isNotEmpty) break;
  }
  if (rDoc.isEmpty) {
    Map<String, dynamic> rDoc2 = await getOpenRALTemplate(type);
    rDoc = rDoc2;
    rDoc["identity"]["UID"] = "";
    debugPrint("generated new template for $type");
  }
  return rDoc;
}

Future<Map<String, dynamic>> getContainerByAlternateUID(String uid) async {
  Map<String, dynamic> rDoc = {};
  //check all items with this type: do they have the id on the field?
  List<Map<dynamic, dynamic>> candidates = localStorage.values
      .where((candidate) => candidate['template']["RALType"] != "")
      .toList();
  for (dynamic candidate in candidates) {
    Map<String, dynamic> candidate2 = Map<String, dynamic>.from(candidate);

    if (candidate2["identity"]["alternateIDs"].length != 0) {
      if (candidate2["identity"]["alternateIDs"][0]["UID"] == uid) {
        rDoc = candidate2;
      }
    }

    if (rDoc.isNotEmpty) break;
  }

  return rDoc;
}
