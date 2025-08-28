import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/helpers/helpers.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/screens/settings_screen.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/widgets/add_empty_item_dialog.dart';
import '../l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

class ContainerSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> item; // Neue Property für das Item

  const ContainerSelectionScreen({Key? key, required this.item})
      : super(key: key);

  @override
  State<ContainerSelectionScreen> createState() =>
      _ContainerSelectionScreenState();
}

class _ContainerSelectionScreenState extends State<ContainerSelectionScreen> {
  final DatabaseHelper databaseHelper = DatabaseHelper();
  final ValueNotifier<bool> isProcessing = ValueNotifier(false);
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final List<Map<String, dynamic>> containers =
        databaseHelper.getContainers(appUserDoc!["identity"]["UID"]);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectContainer), // lokalisiert
        actions: [
          IconButton(
              icon: const Icon(Icons.add_box),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return Scaffold(
                      body: AddEmptyItemDialog(
                        onItemAdded: (Map<String, dynamic> newItem) {
                          debugPrint(
                              "New item added: ${newItem["identity"]["UID"]}");
                          setState(() {});
                        },
                      ),
                    );
                  },
                );
              })
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (isTestmode)
                Container(
                  width: double.infinity,
                  height: 50,
                  color: Colors.redAccent,
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: Text(
                      l10n.testModeActive, // Lokalisierter Text, z. B. "Testmodus aktiv"
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: containers.length,
                  itemBuilder: (context, index) {
                    final container = containers[index];
                    return Container(
                      height: 70,
                      child: ListTile(
                        leading: SizedBox(
                          width: 40, // Feste Breite für das führende Element
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: getContainerIcon(
                                container["template"]["RALType"]),
                          ),
                        ),
                        title: Align(
                          alignment: Alignment.topLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 6),
                              Text(
                                (container['identity']["name"] == "")
                                    ? l10n.unnamedObject // lokalisiert
                                    : container['identity']["name"],
                                style: TextStyle(color: Colors.black54),
                              ),
                              Text(
                                "ID: " +
                                    container["identity"]["alternateIDs"][0]
                                        ["UID"],
                                style: TextStyle(
                                    color: Colors.black38, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        onTap: () async {
                          if (widget.item.isNotEmpty) {
                            // an item has been passed to this screen, change it's container
                            isProcessing.value = true;
                            Map<String, dynamic> changeContainerMethod =
                                await getOpenRALTemplate("changeContainer");

                            changeContainerMethod["executor"] = appUserDoc;
                            changeContainerMethod["methodState"] = "finished";
                            addInputobject(
                                changeContainerMethod, widget.item, "item");
                            addInputobject(changeContainerMethod, widget.item,
                                "newContainer");

                            widget.item["currentGeolocation"]["container"]
                                ["UID"] = container["identity"]["UID"];
                            //Step 1: get method an uuid (for method history entries)
                            setObjectMethodUID(
                                changeContainerMethod, const Uuid().v4());
                            //Step 2: save the objects to get it the method history change
                            await setObjectMethod(widget.item, false, false);
                            //Step 3: add the output objects with updated method history to the method
                            addOutputobject(
                                changeContainerMethod, widget.item, "item");
                            //Step 4: update method history in all affected objects (will also tag them for syncing)
                            await updateMethodHistories(changeContainerMethod);
                            //Step 5: again add Outputobjects to generate valid representation in the method
                            final item = await getLocalObjectMethod(
                                getObjectMethodUID(widget.item));
                            addOutputobject(
                                changeContainerMethod, item, "item");
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
                              inbox =
                                  await databaseHelper.getInboxItems(ownerUID);
                              inboxCount.value = inbox.length;
                            }
                          }

                          Navigator.of(context).pop(container);
                        },
                      ),
                    );
                  },
                ),
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
      ),
    );
  }
}
