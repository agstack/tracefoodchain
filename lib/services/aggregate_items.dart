import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import 'package:trace_foodchain_app/services/scanning_service.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';

Future<void> aggregateItems(
    BuildContext context, Set<String> selectedItemUIDs) async {
  // Step 1: Scan for receiving container
  String? receivingContainerUID = await ScanningService.showScanDialog(
    context,
    Provider.of<AppState>(context, listen: false),
  );

  if (receivingContainerUID == null) {
    await fshowInfoDialog(
        context, "No receiving container selected. Aggregation cancelled.");
    return;
  }

  // Step 2: Get or create the receiving container object
  Map<String, dynamic> receivingContainer = await getObjectOrGenerateNew(
      receivingContainerUID, ["container","bag","building","transportVehicle"], "alternateUid");

  if (getObjectMethodUID(receivingContainer).isEmpty) {
    receivingContainer["identity"]["alternateIDs"] ??= [];
    receivingContainer["identity"]["alternateIDs"]
        .add({"UID": receivingContainerUID, "issuedBy": "owner"});
    receivingContainer["currentOwners"] = [
      {"UID": getObjectMethodUID(appUserDoc!), "role": "owner"}
    ];
    receivingContainer = await setObjectMethod(receivingContainer, true);
  }

  // Step 3: Process each selected item
  for (String itemUID in selectedItemUIDs) {
    Map<String, dynamic> item = await getObjectMethod(itemUID);

    if (item.isNotEmpty) {
      // Create changeContainer process
      Map<String, dynamic> changeContainerProcess =
          await getOpenRALTemplate("changeContainer");
      changeContainerProcess =
          addInputobject(changeContainerProcess, item, "item");
      changeContainerProcess = addInputobject(
          changeContainerProcess, receivingContainer, "newContainer");

      // Update item's currentGeolocation
      item["currentGeolocation"]["container"]["UID"] =
          getObjectMethodUID(receivingContainer);
      changeContainerProcess =
          addOutputobject(changeContainerProcess, item, "item");

      changeContainerProcess["executor"] = appUserDoc;
      changeContainerProcess["methodState"] = "finished";

      // Persist changes
      await setObjectMethod(item, true);
      await setObjectMethod(changeContainerProcess, true);
      await updateMethodHistories(changeContainerProcess);
    }
  }

  // Step 4: Show completion dialog
  // await fshowInfoDialog(context,
  //     "Aggregation complete. ${selectedItemUIDs.length} items moved to the new container.");
}
