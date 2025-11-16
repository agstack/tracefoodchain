import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/helpers/helpers.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import 'package:trace_foodchain_app/screens/peer_transfer_screen.dart';
import 'package:trace_foodchain_app/screens/settings_screen.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/widgets/stepper_first_sale.dart';
import 'package:uuid/uuid.dart';
import '../services/service_functions.dart';
import '../l10n/app_localizations.dart'; // Add this import

Map<String, dynamic> receivingContainer = {};
Map<String, dynamic> field = {};
Map<String, dynamic> seller = {};
Map<String, dynamic> coffee = {};
dynamic transfer_ownership;
dynamic change_container;

class CoffeeInfo {
  String country;
  String species;
  double quantity;
  String weightUnit;
  String processingState;
  List<String> qualityReductionCriteria;

  CoffeeInfo({
    this.country = 'Honduras',
    this.species = "",
    this.quantity = 0.0,
    this.weightUnit = "t",
    this.processingState = "",
    this.qualityReductionCriteria = const [],
  });
}

class SaleInfo {
  CoffeeInfo? coffeeInfo;
  String? geoId;
  String? receivingContainerUID;
}

class StepperSellCoffee {
  Future<void> startProcess(
      BuildContext context,
      Map<String, dynamic> itemToSell,
      Map<String, dynamic> sellerInfo,
      Map<String, dynamic> oldContainer) async {
    coffee = itemToSell; // Set the global coffee variable
    seller = sellerInfo; // Set the global seller variable
    field = oldContainer; // Set the global field variable

    final l10n = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.sellCoffeeDeviceToDevice,
              style: const TextStyle(color: Colors.black)),
          content: const CoffeeSaleStepper(),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel,
                  style: const TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class CoffeeSaleStepper extends StatefulWidget {
  const CoffeeSaleStepper({super.key});

  // final SaleInfo saleInfo;
  // CoffeeSaleStepper({required this.saleInfo});

  @override
  _CoffeeSaleStepperState createState() => _CoffeeSaleStepperState();
}

class _CoffeeSaleStepperState extends State<CoffeeSaleStepper> {
  final ValueNotifier<bool> _isProcessing = ValueNotifier(false);
  int _currentStep = 0;
  SaleInfo saleInfo = SaleInfo();
  List<Step> get _steps {
    final l10n = AppLocalizations.of(context)!;
    return [
      Step(
        title: Text(l10n.scanBuyerInfo,
            style: const TextStyle(color: Colors.black)),
        content: Text(l10n.scanBuyerInfoInstructions,
            style: const TextStyle(color: Colors.black)),
        isActive: _currentStep >= 0,
      ),
      Step(
        title: Text(l10n.presentInfoToBuyer,
            style: const TextStyle(color: Colors.black)),
        content: Text(l10n.presentInfoToBuyerInstructions,
            style: const TextStyle(color: Colors.black)),
        isActive: _currentStep >= 1,
      ),
    ];
  }

  void _nextStep() async {
    switch (_currentStep) {
      case 0:
        
        break;
      case 1:

break;
      // case 2:
      //   

      //   break;

      // case 2:

      //   break;
      default:
    }
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep += 1;
      });
      // Here you would trigger the actual actions for each step
    } else {
      Navigator.of(context).pop(); // Close the dialog when done
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final l10n = AppLocalizations.of(context)!;
    final DatabaseHelper databaseHelper = DatabaseHelper();
    return Stack(
      children: [
        SizedBox(
          height: 500,
          width: 300,
          child: Stepper(
            currentStep: _currentStep,
            onStepContinue: _nextStep,
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() {
                  _currentStep -= 1;
                });
              }
            },
            steps: _steps,
            controlsBuilder: (BuildContext context, ControlsDetails details) {
              String firstButtonText;
              switch (_currentStep) {
                case 0:
                  firstButtonText = l10n.scan;
                  break;
                case 1:
                  firstButtonText = l10n.present;
                  break;
                default:
                  firstButtonText = l10n.next;
              }
              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        switch (_currentStep) {
                          case 0:
                            //Scan Movie or NFC from buyer
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PeerTransferScreen(
                                      transferMode: "receive",
                                      transferredDataOutgoing: [])),
                            ).then((receivedJobs) async {
                              try {
                                transfer_ownership = receivedJobs.firstWhere(
                                    (job) =>
                                        job["template"]["RALType"] ==
                                        "changeOwner");
                                change_container = receivedJobs.firstWhere(
                                    (job) =>
                                        job["template"]["RALType"] ==
                                        "changeContainer");
                              } catch (e) {}
                              if (transfer_ownership == null ||
                                  change_container == null) {
                                await fshowInfoDialog(context,
                                    l10n.errorIncorrectData //"ERROR: The received data are not valid!"
                                    );
                              } else {
                                _nextStep();
                              } //Present finished job to buyer
                            });
                            break;
                          case 1:
                            //*********** A. Change Ownership ***************
                            _isProcessing.value = true;
                            Map<String, dynamic> buyer =
                                transfer_ownership["inputObjects"]
                                    .firstWhere((io) => io["role"] == "buyer");
                            transfer_ownership = addInputobject(
                                transfer_ownership, coffee, "soldItem"); //!!!!

                            transfer_ownership = addInputobject(
                                transfer_ownership, seller, "seller");

                            //"execute method changeOwner"
                            coffee["currentOwners"] = [
                              {
                                //use the buyer's UID from the transfer ownership job!
                                "UID": getObjectMethodUID(buyer),
                                "role": "owner"
                              }
                            ];

                            transfer_ownership["executor"] = seller;
                            transfer_ownership["methodState"] = "finished";

                            //Step 1: NO UUID, since we take over from seller
                            //Step 2: save the objectsto get it the method history change
                            await setObjectMethod(coffee, false, false);
                            //Step 3: add the output objects with updated method history to the method
                            transfer_ownership = addOutputobject(
                                transfer_ownership, coffee, "boughtItem");
                            //Step 4: update method history in all affected objects (will also tag them for syncing)
                            await updateMethodHistories(transfer_ownership);
                            //Step 5: again add Outputobjects to generate valid representation in the method
                            coffee = await getLocalObjectMethod(
                                getObjectMethodUID(coffee));
                            transfer_ownership = addOutputobject(
                                transfer_ownership, coffee, "boughtItem");
                            //Step 6: persist process
                            await setObjectMethod(
                                transfer_ownership, true, true); //sign it!

                            //*********** B. Change Container ***************
                            change_container = addInputobject(
                                change_container,
                                coffee,
                                "item"); //The item that goes into the new container
                            if (field.isNotEmpty) {
                              change_container = addInputobject(
                                  change_container, field, "oldContainer");
                            }

                            //"execute method changeContainer" => change container of coffee or other containers
                            receivingContainer =
                                change_container["inputObjects"].firstWhere(
                                    (io) => io["role"] == "newContainer");
                            final rcuid =
                                getObjectMethodUID(receivingContainer);
                            coffee["currentGeolocation"]["container"]["UID"] =
                                rcuid;

                            change_container["methodState"] = "finished";
                            //no executor change here - is prefilled from buyer

                            //Step 1:  NO UUID, since we take over from seller
                            //Step 2: save the objectsto get it the method history change
                            await setObjectMethod(coffee, false, false);
                            //Step 3: add the output objects with updated method history to the method
                            addOutputobject(change_container, coffee, "item");
                            //Step 4: update method history in all affected objects (will also tag them for syncing)
                            await updateMethodHistories(change_container);
                            //Step 5: again add Outputobjects to generate valid representation in the method
                            coffee = await getLocalObjectMethod(
                                getObjectMethodUID(coffee));
                            addOutputobject(change_container, coffee, "item");
                            //Step 6: persist process
                            await setObjectMethod(
                                change_container, true, true); //sign it!

                            List<Map<String, dynamic>> transmittedList = [];
                            transmittedList.add(transfer_ownership);
                            transmittedList.add(change_container);
                            transmittedList.add(coffee);
                            //Add first method from method history for coffee objects as it contains the field info

                            //!CAVE all nested objects of the container must be transmitted too

                            final containedItemsList =
                                await databaseHelper.getNestedContainedItems(
                                    getObjectMethodUID(coffee));
                            //ToDo owner of all nestd objects must be receiver
                            for (final item in containedItemsList) {
                              if (item["template"]["RALType"] == "coffee" &&
                                  item["methodHistoryRef"] != null &&
                                  item["methodHistoryRef"].isNotEmpty) {
                                final firstContainerMethod =
                                    item["methodHistoryRef"].firstWhere(
                                  (method) =>
                                      method["RALType"] == "changeContainer",
                                  orElse: () => null,
                                );
                                if (firstContainerMethod != null) {
                                  final firstContainerJobUID =
                                      firstContainerMethod["UID"];
                                  final firstJob = await getLocalObjectMethod(
                                      firstContainerJobUID);
                                  transmittedList.add(
                                      firstJob); //This adds the first container change job of the coffee to the transfer which contains the field info
                                }
                              }

                              if (item["currentOwners"] != null) {
                                item["currentOwners"] = [
                                  {
                                    "UID": getObjectMethodUID(buyer),
                                    "role": "owner"
                                  }
                                ];
                                await setObjectMethod(item, false, false);
                              }

                              transmittedList.add(item);
                            }

                            //Present Movie and/or NFC to buyer
                            _isProcessing.value = false;

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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PeerTransferScreen(
                                      transferMode: "send",
                                      transferredDataOutgoing:
                                          transmittedList)),
                            ).then((result) async {
                              final transSuccess = await fshowQuestionDialog(
                                  context,
                                  l10n.confirmTransfer, //"Did the buyer receive the information correctly?",
                                  l10n.yes,
                                  l10n.no);
                              if (transSuccess == true) {
                                _nextStep();
                              } else {
                                //Container and Owner back to old state
                                for (final item in transmittedList) {
                                  if (item["currentOwners"] != null) {
                                    item["currentOwners"] = [
                                      {
                                        "UID": getObjectMethodUID(appUserDoc!),
                                        "role": "owner"
                                      }
                                    ];
                                  }
                                }

                                if (field.isEmpty) {
                                  coffee["currentGeolocation"]["container"]
                                      ["UID"] = "unknown";
                                } else {
                                  coffee["currentGeolocation"]["container"]
                                      ["UID"] = getObjectMethodUID(field);
                                }

                                await setObjectMethod(coffee, false, true);

                                //Jobs als cancelled markieren
                                transfer_ownership["methodState"] = "cancelled";

                                transfer_ownership = await setObjectMethod(
                                    transfer_ownership, true, true);

                                Navigator.of(context).pop();
                              }
                            });
                            break;
                          default:
                        }
                      },
                      child: Text(firstButtonText,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                  // const SizedBox(height: 8),
                  // if (_currentStep != 0)
                  //   Padding(
                  //     padding: const EdgeInsets.all(8.0),
                  //     child: TextButton(
                  //       onPressed: details.onStepCancel,
                  //       child: Text('back',
                  //           style: TextStyle(
                  //               color: Colors
                  //                   .black)), // Umbenennen des "Cancel"-Buttons
                  //     ),
                  //   ),
                  // if (_currentStep == 2) const SizedBox(height: 8),
                  // if (_currentStep == 2)
                  //   Padding(
                  //     padding: const EdgeInsets.all(8.0),
                  //     child: TextButton(
                  //       onPressed: () {
                  //         _nextStep();
                  //       },
                  //       child: Text('skip',
                  //           style: TextStyle(
                  //               color: Colors
                  //                   .black)), // Umbenennen des "Cancel"-Buttons
                  //     ),
                  //   ),
                ],
              );
            },
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _isProcessing,
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
                                l10n.processing, // Assuming processing is a valid localized string
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
  }

  Future<CoffeeInfo?> _showCoffeeInfoDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final countries = ['Honduras', 'Colombia', 'Brazil', 'Ethiopia', 'Vietnam'];
    final coffeeSpecies = loadCoffeeSpecies();
    String? selectedCountry = country;
    String? selectedSpecies;
    double quantity = 0.0;
    String? selectedUnit;
    String? selectedProcessingState;
    List<String> selectedQualityCriteria = [];

    return showDialog<CoffeeInfo>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              List<Map<String, dynamic>> weightUnits = selectedCountry != null
                  ? getWeightUnits(selectedCountry!)
                  : [];
              final processingStates = selectedCountry != null
                  ? getProcessingStates(selectedCountry!)
                  : [];
              final qualityCriteria = selectedCountry != null
                  ? getQualityReductionCriteria(selectedCountry!)
                  : [];

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 55,
                        width: MediaQuery.of(context).size.width * 0.9,
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF35DB00),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Text(
                          l10n.coffeeInformation,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDropdownField(
                                  label: l10n.countryOfOrigin,
                                  value: selectedCountry,
                                  items: countries,
                                  hintText: l10n.selectCountry,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedCountry = newValue;
                                      selectedUnit = null;
                                      selectedProcessingState = null;
                                      selectedQualityCriteria = [];
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildDropdownField(
                                  label: l10n.species,
                                  value: selectedSpecies,
                                  items: coffeeSpecies,
                                  hintText: l10n.selectSpecies,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedSpecies = newValue;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildQuantityField(
                                  quantity: quantity,
                                  selectedUnit: selectedUnit,
                                  weightUnits: weightUnits,
                                  onQuantityChanged: (value) {
                                    String parseValue =
                                        value.replaceAll(',', '.');
                                    quantity =
                                        double.tryParse(parseValue) ?? 0.0;
                                  },
                                  onUnitChanged: (String? newValue) {
                                    setState(() {
                                      selectedUnit = newValue;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildDropdownField(
                                  label: l10n.processingState,
                                  value: selectedProcessingState,
                                  items: processingStates
                                      .map((state) => getLanguageSpecificState(
                                          state, context))
                                      .toList(),
                                  hintText: l10n.selectProcessingState,
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedProcessingState = newValue;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  l10n.qualityReductionCriteria,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ...qualityCriteria.map((criteria) {
                                  return CheckboxListTile(
                                    title: Text(criteria,
                                        style: const TextStyle(
                                            color: Colors.black87)),
                                    value: selectedQualityCriteria
                                        .contains(criteria),
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedQualityCriteria.add(criteria);
                                        } else {
                                          selectedQualityCriteria
                                              .remove(criteria);
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xFF35DB00),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                        child: OverflowBar(
                          overflowAlignment: OverflowBarAlignment.center,
                          children: [
                            TextButton(
                              child: Text(l10n.cancel,
                                  style:
                                      const TextStyle(color: Colors.black87)),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF35DB00),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                if (selectedCountry == null ||
                                    selectedSpecies == null ||
                                    quantity <= 0 ||
                                    selectedUnit == null ||
                                    selectedProcessingState == null) {
                                  await fshowInfoDialog(
                                      context, l10n.fillInReminder);
                                } else {
                                  Navigator.of(context).pop(CoffeeInfo(
                                    country: selectedCountry!,
                                    species: selectedSpecies!,
                                    quantity: quantity,
                                    weightUnit: selectedUnit!,
                                    processingState: selectedProcessingState!,
                                    qualityReductionCriteria:
                                        selectedQualityCriteria,
                                  ));
                                }
                              },
                              child: Text(l10n.confirm,
                                  style: const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        });
  }
}

Widget _buildDropdownField({
  required String label,
  required String? value,
  required List<String> items,
  required String hintText,
  required void Function(String?) onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      (items.isEmpty)
          ? const Text("Please select country first!",
              style: TextStyle(color: Colors.red))
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: value,
                hint: Text(hintText,
                    style: const TextStyle(color: Colors.black87)),
                isExpanded: true,
                underline: const SizedBox(),
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item,
                        style: const TextStyle(color: Colors.black87)),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
    ],
  );
}

// Anpassung des Mengenfeldes
Widget _buildQuantityField({
  required double quantity,
  required String? selectedUnit,
  required List<Map<String, dynamic>> weightUnits,
  required void Function(String) onQuantityChanged,
  required void Function(String?) onUnitChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Quantity",
        style: TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      (weightUnits.isEmpty)
          ? const Text("Please select country first!",
              style: TextStyle(color: Colors.red))
          : Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.black87),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter quantity',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        DecimalTextInputFormatter(),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onChanged: onQuantityChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: selectedUnit,
                    hint: const Text("Unit",
                        style: TextStyle(color: Colors.black87)),
                    underline: const SizedBox(),
                    items: weightUnits.map((unit) {
                      return DropdownMenuItem<String>(
                        value: unit['name'],
                        child: Text(unit['name'],
                            style: const TextStyle(color: Colors.black87)),
                      );
                    }).toList(),
                    onChanged: onUnitChanged,
                  ),
                ),
              ],
            ),
    ],
  );
}

Future<Map<String, dynamic>> getObjectOrGenerateNew(
    String uid, type, field) async {
  Map<String, dynamic> rDoc = {};
  //check all items with this type: do they have the id on the field?
  List<Map<dynamic, dynamic>> candidates = localStorage!.values
      .where((candidate) => candidate['template']["RALType"] == type)
      .toList();
  for (dynamic candidate in candidates) {
    Map<String, dynamic> candidate2 = Map<String, dynamic>.from(candidate);
    bool allow = false;
    if ((isTestmode && candidate2.containsKey("isTestmode")) ||
        (!isTestmode && !candidate2.containsKey("isTestmode"))) allow = true;
    switch (field) {
      case "uid":
        if (candidate2["identity"]["UID"] == uid && allow) rDoc = candidate2;
        break;
      case "alternateUid":
        if (candidate2["identity"]["alternateIDs"].length != 0 && allow) {
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
    
  }
  return rDoc;
}
