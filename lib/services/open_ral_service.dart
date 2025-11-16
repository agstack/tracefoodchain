//This is a collection of services for working with openRAL
//It has to work online and offline, so we have to use Hive to store templates
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:json_path/json_path.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/helpers/json_full_double_to_int.dart';
import 'package:trace_foodchain_app/helpers/sort_json_alphabetically.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/repositories/initial_data.dart';
import 'package:trace_foodchain_app/screens/settings_screen.dart';
import 'package:uuid/uuid.dart';

var uuid = const Uuid();

//! 1. CloudConnectors

Future<Map<String, Map<String, dynamic>>> getCloudConnectors() async {
  
  Map<String, Map<String, dynamic>> rList = {};

  //Always populate with cloudConnectors from initial repo
  for (final cc in initialCloudConnectors) {
    final domain = getSpecificPropertyfromJSON(cc, "cloudDomain");
    rList.addAll({domain: cc});
    if (localStorage != null) {
      //update local storage

      localStorage!.put(getObjectMethodUID(cc), cc);
    }
  }

  return rList;
}

dynamic getCloudConnectionProperty(String domain, connectorType, property) {
  dynamic rObject;
  try {
    // domain und subconnector suchen (connectorType)
    Map<String, dynamic> subConnector = Map<String, dynamic>.from(
        cloudConnectors[domain]!["linkedObjects"].firstWhere(
            (subConnector) => subConnector["role"] == connectorType));
    //read requested property
    rObject = getSpecificPropertyfromJSON(subConnector, property);
  } catch (e) {
    
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
        
      }
    } else {
      
    }

    // _json = jsonDecode(jsonString);
  } catch (e) {
    //ToDo: Handle errors
  }

  return json;
}

//Get object or method from local database
Future<Map<String, dynamic>> getLocalObjectMethod(
    String objectMethodUID) async {
  Map<String, dynamic> doc2 = {};
  try {
    for (var doc in localStorage!.values) {
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

Future<Map<String, dynamic>> setObjectMethod(Map<String, dynamic> objectMethod,
    bool signMethod, bool markForSyncToCloud) async {
  //Make sure it gets a valid
  if (getObjectMethodUID(objectMethod) == "") {
    throw ("ERROR: Object or Method has no UID!");
  } else {
    //***************  EXISTING OBJECT OR METHOD ***************
    if (objectMethod.containsKey("existenceStarts")) {
      //EXISTING METHOD
      if (objectMethod["existenceStarts"] == null) {
        objectMethod["existenceStarts"] = DateTime
            .now(); //ToDo: Test: Can this be stored in Hive? Otherwise ISO8601 String!
      }
      //***************  EXISTING METHOD TO SIGN ***************
      if (signMethod == true) {
        //!DIGITAL SIGNATURE
        //if state is finished, always sign complete method
        //if is running and change container, it is an "inbox" method missing the container in io and oo
        //if is running and change owner, it is an "inbox" method missing the owner in io and oo
        //
        String signingObject = "";
        List<String> pathsToSign = ["\$"];
        //Online sale: We do not know the new container yet, but we know the content
        if ((objectMethod["methodState"] == "running") &&
            (objectMethod["template"]["RALType"] == "changeContainer")) {
          pathsToSign = [
            //sale online process, new container not yet known
            "\$.identity.UID",
            "\$.inputObjects[?(@.role=='item')]",
            //The new state of the item (with new container is not known at that time)
          ];
        }
        signingObject = createSigningObject(pathsToSign, objectMethod);
        // await Share.share(signingObject);
        if (kDebugMode) {
          // await Share.share(signingObject);
        }
        // 
        // 
        // 
        // 

        final signature =
            await digitalSignature.generateSignature(signingObject);
        if (objectMethod["digitalSignatures"] == null) {
          objectMethod["digitalSignatures"] = [];
        }
        objectMethod["digitalSignatures"].add({
          "signature": signature,
          "signerUID": FirebaseAuth.instance.currentUser?.uid,
          // "signedContent": ["\$"]
          "signedContent": pathsToSign
        });
      }
    }
  }

  if (objectMethod["role"] != null) {
    objectMethod.remove("role");
    //Remove unwanted role declaration of objects
  }

  //!tag for syncing with cloud
  if (markForSyncToCloud) objectMethod["needsSync"] = true;

  //Local storage
  await localStorage!.put(getObjectMethodUID(objectMethod), objectMethod);

  // sync with cloud if tagged for this and device is connected to the internet
  var connectivityResult = await (Connectivity().checkConnectivity());
  if (objectMethod["needsSync"] != null) {
    if ((objectMethod["needsSync"] == true) &&
        (!connectivityResult.contains(ConnectivityResult.none))) {
      await cloudSyncService.syncMethods('tracefoodchain.org');
    }
  }
  return objectMethod;
}

// a) IDENTITY
Map<String, dynamic> setObjectMethodUID(
    Map<String, dynamic> objectMethod, String uid) {
  Map<String, dynamic> rMap = objectMethod;
  objectMethod["identity"]["UID"] = uid;

  // Tag dependent on isTestmode
  if (isTestmode) {
    objectMethod["isTestmode"] = true;
  }
  //once marked as testdata, it will always stay test data

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
// Create a deep copy of the object using json encode/decode
  Map<String, dynamic> objectCopy = safeDeepCopy(object);

// Extract UID from the object copy to be added
  var newObjectUID = objectCopy['identity']?['UID'];

  // Find the index of the object with the same UID, if it exists
  int index = method['inputObjects']
      .indexWhere((o) => o['identity']?['UID'] == newObjectUID);

  if (index == -1) {
    // If the object does not exist, add it to the list
    objectCopy["role"] = role;
    method['inputObjects'].add(objectCopy);
  } else {
    // If the object exists, replace it
    
    objectCopy["role"] = role; // Ensure the role is updated
    method['inputObjects'][index] = objectCopy;
  }

// // Check if 'inputObjects' already contains an object with the same UID
//   bool exists =
//       method['inputObjects'].any((o) => o['identity']?['UID'] == newObjectUID);

//   if (!exists) {
//     objectCopy["role"] = role;
//     method['inputObjects'].add(objectCopy);
//   } else {
//     
//   }

  return method;
}

// d) OUTPUTOBJECTS
Map<String, dynamic> addOutputobject(
    Map<String, dynamic> method, Map<String, dynamic> object, String role) {
  if (method['outputObjects'] == null) {
    method['outputObjects'] = [];
  }
// Create a deep copy of the object using json encode/decode
  Map<String, dynamic> objectCopy = safeDeepCopy(object);

  // Extract UID from the object to be added
  var newObjectUID = objectCopy['identity']?['UID'];

  // Find the index of the object with the same UID, if it exists
  int index = method['outputObjects']
      .indexWhere((o) => o['identity']?['UID'] == newObjectUID);

  if (index == -1) {
    // If the object does not exist, add it to the list
    objectCopy["role"] = role;
    method['outputObjects'].add(objectCopy);
  } else {
    // If the object exists, replace it
    
    objectCopy["role"] = role; // Ensure the role is updated
    method['outputObjects'][index] = objectCopy;
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
    
    final oDoc = await getLocalObjectMethod(uid);
    if (oDoc.isNotEmpty) {
      try {
        if (oDoc["methodHistoryRef"]
            .firstWhere((element) => element["UID"] == methodUID,
                orElse: () => {})
            .isEmpty) {
          //Check if already in List
          
          oDoc["methodHistoryRef"]
              .add({"UID": methodUID, "RALType": methodRALType});

          await setObjectMethod(oDoc, false, false);
        } else {
          
        }
      } catch (e) {
        
        oDoc["methodHistoryRef"] = {"UID": methodUID, "RALType": methodRALType};

        await setObjectMethod(oDoc, false, false);
      }
    }
  }
}

// ToDo: Convert to API call
Future<List<Map<String, dynamic>>> getFirebaseObjectsByAlternateUID(
    String uid) async {
  final querySnapshot = await FirebaseFirestore.instance
      .collection('TFC_objects')
      .where('identity.alternateIDs',
          arrayContains: {'UID': uid, 'issuedBy': 'Asset Registry'}).get();

  return querySnapshot.docs
      .map((doc) => doc.data() as Map<String, dynamic>)
      .toList();
}

// ToDo: Convert to API call - this is a helper function to get all objects of the current user - self-registred fields!
Stream<QuerySnapshot> getMyObjectsStream() {
  String? currentUserUID = appUserDoc?["identity"]["UID"];
  if (currentUserUID == null) {
    throw Exception('User not authenticated');
  }

  // currentUserUID = "";

  return FirebaseFirestore.instance.collection('TFC_objects').where(
      'currentOwners',
      arrayContains: {'UID': currentUserUID}).snapshots();
}

Future<Map<String, dynamic>> getObjectOrGenerateNew(
    String uid, List<String> types, String field) async {
  Map<String, dynamic> rDoc = {};
  //check all items with these types: do they have the id on the field?
  List<Map<dynamic, dynamic>> candidates = localStorage!.values
      .where((candidate) => types.contains(candidate['template']["RALType"]))
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
    Map<String, dynamic> rDoc2 = await getOpenRALTemplate(types[0]);
    rDoc = rDoc2;
    rDoc["identity"]["UID"] = "";
    
  }
  return rDoc;
}

Future<bool> checkAlternateIDExists(String alternateID) async {
  List<Map<dynamic, dynamic>> allItems = localStorage!.values
      .where((item) => item['identity']?['alternateIDs'] != null)
      .toList();

  for (dynamic item in allItems) {
    Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
    List alternateIDs = itemMap['identity']['alternateIDs'];

    if (alternateIDs.any((id) => id['UID'] == alternateID)) {
      return true;
    }
  }

  return false;
}

Future<Map<String, dynamic>> getContainerByAlternateUID(String uid) async {
  Map<String, dynamic> rDoc = {};
  //check all items with this type: do they have the id on the field?
  List<Map<dynamic, dynamic>> candidates = localStorage!.values
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

String createSigningObject(
    List<String> pathsToSign, Map<String, dynamic> objectMethod) {
  final copy = Map<String, dynamic>.from(objectMethod);
  copy.remove("digitalSignatures"); //do not sign existing signatures again
  copy.remove("needsSync");
  copy.remove("hasMergeConflict");
  copy.remove("mergeConflictReason");

  List<dynamic> partsToSign = [];
  for (String path in pathsToSign) {
    if (!path.startsWith("\$.") && (path != "\$")) {
      path = "\$.$path";
    }
    JsonPath? jp;
    try {
      jp = JsonPath(path);
    } catch (e) {
      );
    }
    final matches = jp!.read(copy);
    if (matches.isNotEmpty) {
      if (matches.first.value is Map) {
        Map<String, dynamic> valueMap =
            Map<String, dynamic>.from(matches.first.value as Map);
        valueMap = convertToJson(
            valueMap); //Replace Datetime and GeoPoint with JSON objects

        partsToSign.add(Map<String, dynamic>.from(valueMap as Map));
      } else if (matches.first.value is List) {
        if (matches.first.value != null && matches.first.value is Iterable) {
          for (final item in matches.first.value as Iterable) {
            Map<String, dynamic> valueMap =
                Map<String, dynamic>.from(item as Map);

            valueMap = convertToJson(
                valueMap); //Replace Datetime and GeoPoint with JSON objects

            partsToSign.add(valueMap);
          }
        }
      } else {
        partsToSign.add(matches.first.value);
      } //Only value
    }
  }

  partsToSign = jsonFullDoubleToInt(partsToSign);
  partsToSign = sortJsonAlphabetically(partsToSign);

  try {
    //ToDO: We need to convert DateTime to isostring and geopoint to a map before serializing
    final rstring = jsonEncode(partsToSign);
  } catch (e) {
    );
  }
  return jsonEncode(partsToSign);
}

Map<String, dynamic> safeDeepCopy(Map<String, dynamic> object) {
  Map<String, dynamic> objectCopy =
      json.decode(json.encode(object, toEncodable: (obj) {
    if (obj is DateTime) {
      return {'__type': 'DateTime', 'value': obj.toIso8601String()};
    }
    if (obj is Timestamp) {
      return {
        '__type': 'Timestamp',
        'seconds': obj.seconds,
        'nanoseconds': obj.nanoseconds
      };
    }
    if (obj is GeoPoint) {
      return {
        '__type': 'GeoPoint',
        'latitude': obj.latitude,
        'longitude': obj.longitude
      };
    }
    return obj;
  }));

  // Convert back special types
  _convertSpecialTypes(objectCopy);
  return objectCopy;
}

void _convertSpecialTypes(dynamic obj) {
  if (obj is Map<String, dynamic>) {
    for (var key in obj.keys.toList()) {
      var value = obj[key];
      if (value is Map<String, dynamic> && value['__type'] != null) {
        switch (value['__type']) {
          case 'DateTime':
            obj[key] = DateTime.parse(value['value']);
            break;
          case 'Timestamp':
            obj[key] = Timestamp(value['seconds'], value['nanoseconds']);
            break;
          case 'GeoPoint':
            obj[key] = GeoPoint(value['latitude'], value['longitude']);
            break;
        }
      } else if (value is Map || value is List) {
        _convertSpecialTypes(value);
      }
    }
  } else if (obj is List) {
    for (var i = 0; i < obj.length; i++) {
      _convertSpecialTypes(obj[i]);
    }
  }
}

Future<String> generateDigitalSibling(Map<String, dynamic> newItem) async {
  if (getObjectMethodUID(newItem) == "") {
    setObjectMethodUID(newItem, const Uuid().v4());
  }
  final generateDSJob = await getOpenRALTemplate("generateDigitalSibling");
  //Add Executor
  generateDSJob["executor"] = appUserDoc!;
  generateDSJob["methodState"] = "finished";
  //Step 1: get method an uuid (for method history entries)
  setObjectMethodUID(generateDSJob, const Uuid().v4());
  //Step 2: save the object a first time to get it the method history change
  await setObjectMethod(newItem, false, false);
  //Step 3: add the output objects with updated method history to the method
  addOutputobject(generateDSJob, newItem, "item");
  //Step 4: update method history in all affected objects (will also tag them for syncing)
  await updateMethodHistories(generateDSJob);
  //Step 5: again add Outputobjects to generate valid representation in the method
  newItem = await getLocalObjectMethod(getObjectMethodUID(newItem));
  addOutputobject(generateDSJob, newItem, "item");
  //Step 6: persist process
  await setObjectMethod(generateDSJob, true, true); //sign it!
  return getObjectMethodUID(newItem);
}

Future<void> changeObjectData(Map<String, dynamic> newObjectVersion) async {
  //Get the old object version (from local storage or from cloud if newer and connected)
  final oldObjectVersion =
      await getLocalObjectMethod(newObjectVersion["identity"]["UID"]);
  //In case the object is not in local storage, we have to get it from the cloud in case we are online
  if (oldObjectVersion.isEmpty) {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      //get it from TFC_objects
      final querySnapshot = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .where('identity.UID', isEqualTo: newObjectVersion["identity"]["UID"])
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        oldObjectVersion.addAll(querySnapshot.docs.first.data());
      }
    }
  }
  //in case the object is still not found, we have to throw an error
  if (oldObjectVersion.isEmpty) {
    throw Exception(
        "The object with UID ${newObjectVersion["identity"]["UID"]} could not be found in local storage or cloud!");
  }
  //Save the new version of the object locally
  await setObjectMethod(newObjectVersion, false, false);

  //Get the changeObjectData job template
  final changeObjectDataJob = await getOpenRALTemplate("changeObjectData");
  //Add Executor
  changeObjectDataJob["executor"] = appUserDoc!;
  changeObjectDataJob["methodState"] = "finished";
  //get method an uuid (for method history entries)
  setObjectMethodUID(changeObjectDataJob, const Uuid().v4());

  // Inputobject = old version of the object
  addInputobject(changeObjectDataJob, oldObjectVersion, "item");

  //save the object a first time to get it the method history change
  await setObjectMethod(changeObjectDataJob, false, false);

  //add the output objects with updated method history to the method
  addOutputobject(changeObjectDataJob, newObjectVersion, "item");

  //update method history in all affected objects (will also tag them for syncing)
  await updateMethodHistories(changeObjectDataJob);

  //again add Outputobjects to generate valid representation including updated method history in the method
  newObjectVersion =
      await getLocalObjectMethod(getObjectMethodUID(newObjectVersion));
  addOutputobject(changeObjectDataJob, newObjectVersion, "item");

  //Step 6: persist process
  await setObjectMethod(
      changeObjectDataJob, true, true); //including signing and syncing to cloud
}

Map<String, dynamic> addLinkedObjectRef(
  Map<String, dynamic> object,
  Map<String, dynamic> linkedObject,
  String role,
) {
  final test = object["linkedObjectRef"].firstWhere(
    (k) => (k["UID"] == linkedObject["identity"]["UID"] && k["role"] == role),
    orElse: () => null,
  );
  if (test == null) {
    // noch nicht verlinked
    object["linkedObjectRef"].add({
      "UID": linkedObject["identity"]["UID"],
      "role": role,
    });
  }
  return object;
}
