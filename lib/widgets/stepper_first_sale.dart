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
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/scanning_service.dart';
import 'package:uuid/uuid.dart';
import '../services/service_functions.dart';
import '../l10n/app_localizations.dart';

Map<String, dynamic> receivingContainer = {};
Map<String, dynamic> field = {};
Map<String, dynamic> seller = {};
Map<String, dynamic> coffee = {};
Map<String, dynamic> transfer_ownership = {};
Map<String, dynamic> change_container = {};

class CoffeeInfo {
  String country;
  String species;
  double quantity;
  String weightUnit;
  String processingState;
  List<String> qualityReductionCriteria;

  CoffeeInfo({
    this.country = 'Honduras', //ToDo: enable other countries if needed
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

class FirstSaleProcess {
  Future<void> startProcess(BuildContext context,
      {String? receivingContainerUID}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.buyCoffeeCiatFirstSale,
              style: const TextStyle(color: Colors.black)),
          content:
              CoffeeSaleStepper(receivingContainerUID: receivingContainerUID),
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
  // final SaleInfo saleInfo;
  // CoffeeSaleStepper({required this.saleInfo});
  final String? receivingContainerUID;

  const CoffeeSaleStepper({super.key, this.receivingContainerUID});

  @override
  _CoffeeSaleStepperState createState() => _CoffeeSaleStepperState();
}

class _CoffeeSaleStepperState extends State<CoffeeSaleStepper> {
  int _currentStep = 0;
  SaleInfo saleInfo = SaleInfo();
  // Ersetze _isProcessing als bool durch einen ValueNotifier<bool>
  final ValueNotifier<bool> _isProcessing = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    if (widget.receivingContainerUID != null) {
      saleInfo.receivingContainerUID = widget.receivingContainerUID;
    }
  }

  List<Step> get _steps {
    final l10n = AppLocalizations.of(context)!;
    return [
      Step(
        title: Text(l10n.scanSellerTag,
            style: const TextStyle(color: Colors.black)),
        content: Text(l10n.scanSellerTagInstructions,
            style: const TextStyle(color: Colors.black)),
        isActive: _currentStep >= 0,
      ),
      Step(
        title: Text(l10n.enterCoffeeInfo,
            style: const TextStyle(color: Colors.black)),
        content: Text(l10n.enterCoffeeInfoInstructions,
            style: const TextStyle(color: Colors.black)),
        isActive: _currentStep >= 1,
      ),
      if (widget.receivingContainerUID == null)
        Step(
          title: Text(l10n.scanReceivingContainer,
              style: const TextStyle(color: Colors.black)),
          content: Text(l10n.scanReceivingContainerInstructions,
              style: const TextStyle(color: Colors.black)),
          isActive: _currentStep >= 2,
        ),
    ];
  }

  void _nextStep() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    switch (_currentStep) {
      case 0:
        var scannedCode =
            await ScanningService.showScanDialog(context, appState, false);
        if (scannedCode != null) {
          saleInfo.geoId = scannedCode.replaceAll(RegExp(r'\s+'), '');
          setState(() {
            _currentStep += 1;
          });
        } else {
          await fshowInfoDialog(context, l10n.provideValidSellerTag);
        }
        break;

      case 1:
        CoffeeInfo? coffeeInfo = await _showCoffeeInfoDialog();
        if (coffeeInfo != null) {
          saleInfo.coffeeInfo = coffeeInfo;
          if (widget.receivingContainerUID != null) {
            // Overlay vor dem Verkauf ohne setState
            _isProcessing.value = true;
            String containerType = "container";
            dynamic container =
                await getContainerByAlternateUID(widget.receivingContainerUID!);
            if (!container.isEmpty) {
              containerType = container["template"]["RALType"];
            }
            await sellCoffee(saleInfo, containerType);
            _isProcessing.value = false;
            final databaseHelper = DatabaseHelper();
            //Repaint Container list
            repaintContainerList.value = true;
            //Repaint Inbox count
            if (FirebaseAuth.instance.currentUser != null) {
              String ownerUID = FirebaseAuth.instance.currentUser!.uid;
              inbox = await databaseHelper.getInboxItems(ownerUID);
              inboxCount.value = inbox.length;
            }
            Navigator.of(context).pop();
          } else {
            setState(() {
              _currentStep += 1;
            });
          }
        } else {
          await fshowInfoDialog(
              context, "Input of additional information is mandatory!");
        }
        break;

      case 2:
        if (widget.receivingContainerUID == null) {
          var scannedCode =
              await ScanningService.showScanDialog(context, appState, true);
          if (scannedCode != null) {
            final isUIDTaken = await checkAlternateIDExists(scannedCode);
            if (isUIDTaken) {
              await fshowInfoDialog(
                context,
                AppLocalizations.of(context)!.uidAlreadyExists,
              );
            } else {
              saleInfo.receivingContainerUID = scannedCode;
              String containerType = "container";
              dynamic container = await getContainerByAlternateUID(scannedCode);
              if (!container.isEmpty) {
                containerType = container["template"]["RALType"];
              }
              _isProcessing.value = true;
              await sellCoffee(saleInfo, containerType);
              _isProcessing.value = false;
              final databaseHelper = DatabaseHelper();
              //Repaint Container list
              repaintContainerList.value = true;
              //Repaint Inbox count
              if (FirebaseAuth.instance.currentUser != null) {
                String ownerUID = FirebaseAuth.instance.currentUser!.uid;
                inbox = await databaseHelper.getInboxItems(ownerUID);
                inboxCount.value = inbox.length;
              }
              Navigator.of(context).pop();
            }
          } else {
            await fshowInfoDialog(
                context, "Please provide a valid receiving container tag.");
          }
        }
        break;

      default:
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        // Basis-Widget
        Center(
          child: SizedBox(
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
                final l10n = AppLocalizations.of(context)!;
                String buttonText = l10n.buttonNext;
                if (_currentStep == 0 ||
                    (_currentStep == 2 &&
                        widget.receivingContainerUID == null)) {
                  buttonText = l10n.buttonScan;
                } else if (_currentStep == 1 &&
                    widget.receivingContainerUID != null) {
                  buttonText = l10n.buttonStart;
                }

                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton(
                        onPressed: _nextStep,
                        child: Text(buttonText,
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    if (_currentStep != 0)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextButton(
                          onPressed: details.onStepCancel,
                          child: Text(l10n.buttonBack,
                              style: const TextStyle(color: Colors.black)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        // Overlay bei laufender Verarbeitung per ValueListenableBuilder.
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
                              Text(l10n.coffeeIsBought,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
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

  @override
  void dispose() {
    super.dispose();
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
                    maxWidth: 400,
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
                                  context: context,
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
                                    title: Text(
                                        getLanguageSpecificState(
                                            criteria, context),
                                        style: const TextStyle(
                                            color: Colors.black87)),
                                    value: selectedQualityCriteria.contains(
                                        getLanguageSpecificState(
                                            criteria, context)),
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedQualityCriteria.add(
                                              getLanguageSpecificState(
                                                  criteria, context));
                                        } else {
                                          selectedQualityCriteria.remove(
                                              getLanguageSpecificState(
                                                  criteria, context));
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
  required BuildContext context,
  required double quantity,
  required String? selectedUnit,
  required List<Map<String, dynamic>> weightUnits,
  required void Function(String) onQuantityChanged,
  required void Function(String?) onUnitChanged,
}) {
  final l10n = AppLocalizations.of(context)!;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l10n.quantity,
        //  "Quantity",
        style: const TextStyle(
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
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: l10n.enterQuantity, //'Enter quantity',
                        hintStyle: const TextStyle(color: Colors.grey),
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
                    hint: Text(l10n.unit, // "Unit",
                        style: const TextStyle(color: Colors.black87)),
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

String getLanguageSpecificState(
    Map<String, dynamic> state, BuildContext context) {
  dynamic rState;
  final currentLocale = Localizations.localeOf(context).toString();
  if (currentLocale.startsWith('es')) {
    rState = state['name']['spanish'];
  } else if (currentLocale.startsWith('fr')) {
    rState = state['name']['french'];
  } else if (currentLocale.startsWith('de')) {
    rState = state['name']['german'];
  } else {
    rState = state['name']['english'];
  }

  rState ??= state['name']['english'];
  return rState as String;
}

Future<void> sellCoffee(SaleInfo saleInfo, String containerType) async {
  // PROCESS FINISHED - GENERATE AND STORE OBJECTS AND PROCESSES
  //*******  A. load or generate objects of the processes ************

  // 1. Check if receiving container exists. If not generate new one.
  receivingContainer = {};
  receivingContainer = await getObjectOrGenerateNew(
      saleInfo.receivingContainerUID!, [containerType], "alternateUid");
  if (getObjectMethodUID(receivingContainer) == "") {
    setObjectMethodUID(receivingContainer, const Uuid().v4());
    receivingContainer["identity"]["alternateIDs"]
        .add({"UID": saleInfo.receivingContainerUID, "issuedBy": "owner"});
    receivingContainer["currentOwners"] = [
      {"UID": getObjectMethodUID(appUserDoc!), "role": "owner"}
    ];

    final addItem = await getOpenRALTemplate("generateDigitalSibling");
    //Add Executor
    addItem["executor"] = appUserDoc!;
    addItem["methodState"] = "finished";
    //Step 1: get method an uuid (for method history entries)
    setObjectMethodUID(addItem, const Uuid().v4());
    //Step 2: save the objects a first time to get it the method history change
    await setObjectMethod(receivingContainer, false, false);
    //Step 3: add the output objects with updated method history to the method
    addOutputobject(addItem, receivingContainer, "item");
    //Step 4: update method history in all affected objects (will also tag them for syncing)
    await updateMethodHistories(addItem);
    //Step 5: again add Outputobjects to generate valid representation in the method
    receivingContainer =
        await getLocalObjectMethod(getObjectMethodUID(receivingContainer));
    addOutputobject(addItem, receivingContainer, "item");
    //Step 6: persist process
    await setObjectMethod(addItem, true, true); //sign it!

    receivingContainer =
        await getLocalObjectMethod(getObjectMethodUID(receivingContainer));
  }


  // 2. Check if field  (by GeoId) exists. If not generate new one. Also generate new Owner => geoID as tag for owner
  //look for a field that have geoId as alternateIDs
  field = {};
  field =
      await getObjectOrGenerateNew(saleInfo.geoId!, ["field"], "alternateUid");

  if (getObjectMethodUID(field) == "") {
    setObjectMethodUID(field, const Uuid().v4());
    field["identity"]["alternateIDs"]
        .add({"UID": saleInfo.geoId, "issuedBy": "Asset Registry"});

    final addItem = await getOpenRALTemplate("generateDigitalSibling");
    //Add Executor
    addItem["executor"] = appUserDoc!;
    addItem["methodState"] = "finished";
    //Step 1: get method an uuid (for method history entries)
    setObjectMethodUID(addItem, const Uuid().v4());
    //Step 2: save the objects a first time to get it the method history change
    await setObjectMethod(field, false, false);
    //Step 3: add the output objects with updated method history to the method
    addOutputobject(addItem, field, "item");
    //Step 4: update method history in all affected objects (will also tag them for syncing)
    await updateMethodHistories(addItem);
    //Step 5: again add Outputobjects to generate valid representation in the method
    field = await getLocalObjectMethod(getObjectMethodUID(field));
    addOutputobject(addItem, field, "item");
    //Step 6: persist process
    await setObjectMethod(addItem, true, true); //sign it!

    field = await getLocalObjectMethod(getObjectMethodUID(field));
  }


  //! due to project specifications, field and company are the same for Honduras atm
  seller = {};
  seller = await getObjectOrGenerateNew(
      saleInfo.geoId!, ["company"], "alternateUid");
  //ToDo: Would be better to have company information
  if (getObjectMethodUID(seller) == "") {
    setObjectMethodUID(seller, const Uuid().v4());
    seller["identity"]["alternateIDs"]
        .add({"UID": saleInfo.geoId, "issuedBy": "Asset Registry"});

    final addItem = await getOpenRALTemplate("generateDigitalSibling");
    //Add Executor
    addItem["executor"] = appUserDoc!;
    addItem["methodState"] = "finished";
    //Step 1: get method an uuid (for method history entries)
    setObjectMethodUID(addItem, const Uuid().v4());
    //Step 2: save the objects a first time to get it the method history change
    await setObjectMethod(seller, false, false);
    //Step 3: add the output objects with updated method history to the method
    addOutputobject(addItem, seller, "item");
    //Step 4: update method history in all affected objects (will also tag them for syncing)
    await updateMethodHistories(addItem);
    //Step 5: again add Outputobjects to generate valid representation in the method
    seller = await getLocalObjectMethod(getObjectMethodUID(seller));
    addOutputobject(addItem, seller, "item");
    //Step 6: persist process
    await setObjectMethod(addItem, true, true); //sign it!

    seller = await getLocalObjectMethod(getObjectMethodUID(seller));
  }


  // 3. Generate process "coffee" and put information of the coffee into
  coffee = {};
  coffee = await getOpenRALTemplate("coffee");
  setObjectMethodUID(coffee, const Uuid().v4());
  coffee = setSpecificPropertyJSON(
      coffee, "species", saleInfo.coffeeInfo!.species, "String");
  coffee = setSpecificPropertyJSON(
      coffee, "country", saleInfo.coffeeInfo!.country, "String");
  coffee = setSpecificPropertyJSON(coffee, "amount",
      saleInfo.coffeeInfo!.quantity, saleInfo.coffeeInfo!.weightUnit);
  // coffee = setSpecificPropertyJSON(
  //     coffee, "amountUnit", saleInfo.coffeeInfo!.weightUnit, "String");
  coffee = setSpecificPropertyJSON(coffee, "processingState",
      saleInfo.coffeeInfo!.processingState, "String");
  coffee = setSpecificPropertyJSON(
      coffee,
      "qualityState",
      saleInfo.coffeeInfo!.qualityReductionCriteria,
      "stringlist"); //ToDo Check!

  final addItem = await getOpenRALTemplate("generateDigitalSibling");
  //Add Executor
  addItem["executor"] = appUserDoc!;
  addItem["methodState"] = "finished";
  //Step 1: get method an uuid (for method history entries)
  setObjectMethodUID(addItem, const Uuid().v4());
  //Step 2: save the objects a first time to get it the method history change
  await setObjectMethod(coffee, false, false);
  //Step 3: add the output objects with updated method history to the method
  addOutputobject(addItem, coffee, "item");
  //Step 4: update method history in all affected objects (will also tag them for syncing)
  await updateMethodHistories(addItem);
  //Step 5: again add Outputobjects to generate valid representation in the method
  coffee = await getLocalObjectMethod(getObjectMethodUID(coffee));
  addOutputobject(addItem, coffee, "item");
  //Step 6: persist process
  await setObjectMethod(addItem, true, true); //sign it!



  //********* B. Generate process "transfer_ownership" (selling process) *********
  transfer_ownership = {};
  transfer_ownership = await getOpenRALTemplate("changeOwner");
  //Tobject, oldOwner = seller, newOwner = user  => executeRalMethod => currentOwner tauschen

  transfer_ownership = addInputobject(transfer_ownership, coffee, "soldItem");
  transfer_ownership = addInputobject(transfer_ownership, seller, "seller");
  transfer_ownership = addInputobject(transfer_ownership, appUserDoc!, "buyer");

  //"execute method changeOwner"
  coffee["currentOwners"] = [
    {"UID": getObjectMethodUID(appUserDoc!), "role": "owner"}
  ];

  transfer_ownership["executor"] = seller;
  transfer_ownership["methodState"] = "finished";
  //Step 1: get method an uuid (for method history entries)
  setObjectMethodUID(transfer_ownership, const Uuid().v4());
  //Step 2: save the objects a first time to get it the method history change
  await setObjectMethod(coffee, false, false);
  //Step 3: add the output objects with updated method history to the method

  addOutputobject(transfer_ownership, coffee, "boughtItem");
  //Step 4: update method history in all affected objects (will also tag them for syncing)
  await updateMethodHistories(transfer_ownership);
  //Step 5: again add Outputobjects to generate valid representation in the method
  coffee = await getLocalObjectMethod(getObjectMethodUID(coffee));
  addOutputobject(transfer_ownership, coffee, "boughtItem");
  //Step 6: persist process
  await setObjectMethod(transfer_ownership, true, true); //sign it!

  //******* C. Generate process "change_container" (put harvest into container) *********
  change_container = {};
  change_container = await getOpenRALTemplate("changeContainer");
  //coffee neu laden für nächsten Schritt!!!
  coffee = await getLocalObjectMethod(getObjectMethodUID(coffee));

  change_container = addInputobject(change_container, coffee, "item");
  change_container = addInputobject(change_container, field, "oldContainer");
  change_container =
      addInputobject(change_container, receivingContainer, "newContainer");

  //"execute method changeLocation"
  coffee["currentGeolocation"]["container"]["UID"] =
      getObjectMethodUID(receivingContainer);

  change_container["executor"] = appUserDoc!;
  change_container["methodState"] = "finished";
  //Step 1: get method an uuid (for method history entries)
  setObjectMethodUID(change_container, const Uuid().v4());
  //Step 2: save the objectsto get it the method history change
  await setObjectMethod(coffee, false, false);
  //Step 3: add the output objects with updated method history to the method
  addOutputobject(change_container, coffee, "item");
  //Step 4: update method history in all affected objects (will also tag them for syncing)
  await updateMethodHistories(change_container);
//Step 5: again add Outputobjects to generate valid representation in the method
  coffee = await getLocalObjectMethod(getObjectMethodUID(coffee));
  addOutputobject(change_container, coffee, "item");
  //Step 6: persist process
  await setObjectMethod(change_container, true, true); //sign it!
  
}
