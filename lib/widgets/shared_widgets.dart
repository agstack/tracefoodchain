// lib/widgets/shared_dialogs.dart
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import 'package:trace_foodchain_app/screens/peer_transfer_screen.dart';
import 'package:trace_foodchain_app/services/aggregate_items.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/scanning_service.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import 'package:trace_foodchain_app/widgets/coffee_processing_state_selector.dart';
import 'package:trace_foodchain_app/widgets/stepper_buy_coffee.dart' show StepperBuyCoffee;
import 'package:trace_foodchain_app/widgets/stepper_first_sale.dart' show FirstSaleProcess;
import '../l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

Future<void> showBuyCoffeeOptions(BuildContext context,
    {String? receivingContainerUID}) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      final l10n = AppLocalizations.of(context)!;
      return AlertDialog(
        title: Text(
          l10n.selectBuyCoffeeOption,
          style: const TextStyle(color: Colors.black),
          textAlign: TextAlign.center,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildOptionButton(
                        context,
                        icon: Icons.credit_card,
                        label: l10n.ciatFirstSale,
                        onTap: () async {
                          Navigator.of(context).pop();
                          FirstSaleProcess buyCoffeeProcess =
                              FirstSaleProcess();
                          if (receivingContainerUID == null) {
                            await buyCoffeeProcess.startProcess(context);
                          } else {
                            await buyCoffeeProcess.startProcess(context,
                                receivingContainerUID: receivingContainerUID);
                          }
                          repaintContainerList.value = true;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildOptionButton(
                        context,
                        icon: Icons.devices,
                        label: l10n.deviceToDevice,
                        onTap: () async {
                          Navigator.of(context).pop();
                          // Implement device-to-device process

                          StepperBuyCoffee buyCoffeeProcess =
                              StepperBuyCoffee();
                          if (receivingContainerUID == null) {
                            await buyCoffeeProcess.startProcess(context);
                          } else {
                            await buyCoffeeProcess.startProcess(context,
                                receivingContainerUID: receivingContainerUID);
                          }

                          repaintContainerList.value = true;
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildOptionButton(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: Icon(icon, size: 40, color: Theme.of(context).primaryColor),
        onPressed: onTap,
      ),
      const SizedBox(height: 8),
      Text(
        label,
        style: const TextStyle(color: Colors.black),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

Future<void> showAggregateItemsDialog(
    BuildContext context, Set<String> selectedItemUIDs) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      final l10n = AppLocalizations.of(context)!;
      return AlertDialog(
        title: Text(l10n.aggregateItems,
            style: const TextStyle(color: Colors.black)),
        content: Text(l10n.scanSelectFutureContainer,
            style: const TextStyle(color: Colors.black)),
        actions: <Widget>[
          TextButton(
            child: Text(l10n.cancel),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          ElevatedButton(
            child: Text(l10n.startScanning),
            onPressed: () {
              Navigator.of(context).pop();
              aggregateItems(context, selectedItemUIDs);
            },
          ),
        ],
      );
    },
  );
}

Future<void> showChangeContainerDialog(
    BuildContext context, Map<String, dynamic> item,
    {Map<String, dynamic>? preexistingChangeContainer}) async {
  final ValueNotifier<bool> isProcessing = ValueNotifier(false);
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      final l10n = AppLocalizations.of(context)!;
      return Stack(
        children: [
          AlertDialog(
            title: Text(
              l10n.changeLocation,
              style: const TextStyle(color: Colors.black54),
            ),
            content: Text(l10n.scanContainerInstructions,
                style: const TextStyle(color: Colors.black54)),
            actions: <Widget>[
              TextButton(
                child: Text(l10n.cancel),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                child: Text(l10n.start),
                onPressed: () async {
                  Map<String, dynamic>? newContainer;
                  String? receivingContainerUID =
                      await ScanningService.showScanDialog(
                    context,
                    Provider.of<AppState>(context, listen: false),
                    true,
                  );

                  if (receivingContainerUID == null) {
                    await fshowInfoDialog(context, l10n.noDeliveryHistory);
                  } else {
                    isProcessing.value = true;
                    newContainer =
                        await getContainerByAlternateUID(receivingContainerUID);

                    if (newContainer.isEmpty) {
                      await fshowInfoDialog(context,
                          l10n.noDeliveryHistory); // Use appropriate translation
                    } else

                    //4. Change container
                    {
                      Map<String, dynamic>? changeContainerMethod;
                      if (preexistingChangeContainer != null) {
                        //in case this is a running method now being finished
                        changeContainerMethod = preexistingChangeContainer;
                      } else {
                        changeContainerMethod =
                            await getOpenRALTemplate("changeContainer");
                      }

                      changeContainerMethod["executor"] = appUserDoc;
                      changeContainerMethod["methodState"] = "finished";
                      changeContainerMethod["inputObjects"] = [
                        item,
                        newContainer
                      ];
                      item["currentGeolocation"]["container"]["UID"] =
                          newContainer["identity"]["UID"];
                      //Step 1: get method an uuid (for method history entries)
                      setObjectMethodUID(
                          changeContainerMethod, const Uuid().v4());
                      //Step 2: save the objects to get it the method history change
                      await setObjectMethod(item, false, false);
                      //Step 3: add the output objects with updated method history to the method
                      addOutputobject(changeContainerMethod, item, "item");
                      //Step 4: update method history in all affected objects (will also tag them for syncing)
                      await updateMethodHistories(changeContainerMethod);
                      //Step 5: again add Outputobjects to generate valid representation in the method
                      item =
                          await getLocalObjectMethod(getObjectMethodUID(item));
                      addOutputobject(changeContainerMethod, item, "item");
                      //Step 6: persist process
                      await setObjectMethod(
                          changeContainerMethod, true, true); //sign it!
                      isProcessing.value = false;
                      final databaseHelper = DatabaseHelper();
                      //Repaint Container list
                      repaintContainerList.value = true;
                      //Repaint Inbox count
                      if (FirebaseAuth.instance.currentUser != null) {
                        String ownerUID =
                            FirebaseAuth.instance.currentUser!.uid;
                        inbox = await databaseHelper.getInboxItems(ownerUID);
                        inboxCount.value = inbox.length;
                      }
                    }
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: isProcessing,
            builder: (context, isProcessing, child) {
              return isProcessing
                  ? Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.changeLocation,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            },
          ),
        ],
      );
    },
  );
}

Future<void> showProcessingStateDialog(
    Map<String, dynamic> coffee, BuildContext context) async {
  String currentState = getSpecificPropertyfromJSON(coffee, "processingState");
  List<String> currentQualityCriteria =
      (getSpecificPropertyfromJSON(coffee, "qualityState") as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          <String>[];

  Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (BuildContext context) {
      final l10n = AppLocalizations.of(context)!;
      return Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text(
                //   'Select Processing State and Quality Criteria',
                //   style: TextStyle(
                //     fontSize: 18,
                //     fontWeight: FontWeight.bold,
                //   ),
                // ),
                // SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: CoffeeProcessingStateSelector(
                      currentState: currentState,
                      currentQualityCriteria: currentQualityCriteria,
                      onSelectionChanged: (state, criteria) {
                        Navigator.of(context).pop({
                          'state': state,
                          'criteria': criteria,
                        });
                      },
                      country: getSpecificPropertyfromJSON(coffee, "country") ??
                          country,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text(l10n.cancel),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (result != null &&
      (result["state"] != currentState ||
          result["criteria"] != currentQualityCriteria)) {
    // Changes are saved in case state or qc critera changed
    // Template changeProcessingState holen
    Map<String, dynamic> changeProcessingState = {};
    changeProcessingState = await getOpenRALTemplate("changeProcessingState");
    addInputobject(changeProcessingState, coffee, "item");

    coffee = setSpecificPropertyJSON(
        coffee, "processingState", result["state"], "String");
    coffee = setSpecificPropertyJSON(
        coffee, "qualityState", result["criteria"], "stringlist"); //ToDo Check!

    changeProcessingState["executor"] = appUserDoc!;
    changeProcessingState["methodState"] = "finished";
    //Step 1: get method an uuid (for method history entries)
    setObjectMethodUID(changeProcessingState, const Uuid().v4());
    //Step 2: persist object changes
    await setObjectMethod(coffee, false, false);
    //Step 3: add the output objects with updated method history to the method
    addOutputobject(changeProcessingState, coffee, "item");
    //Step 4: update method history in all affected objects (will also tag them for syncing)
    await updateMethodHistories(changeProcessingState);
    //Step 5: again add Outputobjects to generate valid representation in the method
    coffee = await getLocalObjectMethod(getObjectMethodUID(coffee));
    addOutputobject(changeProcessingState, coffee, "item");
    //Step 6: persist process
    await setObjectMethod(changeProcessingState, true, true); //sign it!
  }
}
