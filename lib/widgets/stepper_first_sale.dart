import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/helpers/helpers.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/scanning_service.dart';
import '../services/service_functions.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

    switch (_currentStep) {
      case 0:
        var scannedCode =
            await ScanningService.showScanDialog(context, appState);
        if (scannedCode != null) {
          saleInfo.geoId = scannedCode.replaceAll(RegExp(r'\s+'), '');
          setState(() {
            _currentStep += 1;
          });
        } else {
          await fshowInfoDialog(context, "Please provide a valid seller tag.");
        }
        break;

      case 1:
        CoffeeInfo? coffeeInfo = await _showCoffeeInfoDialog();
        if (coffeeInfo != null) {
          saleInfo.coffeeInfo = coffeeInfo;
          if (widget.receivingContainerUID != null) {
            // If we have a receiving container UID, proceed to finish the sale
            String containerType = "container";
            dynamic container =
                await getContainerByAlternateUID(widget.receivingContainerUID!);
            if (!container.isEmpty) {
              containerType = container["template"]["RALType"];
            }
            await sellCoffee(saleInfo, containerType);
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
              await ScanningService.showScanDialog(context, appState);
          if (scannedCode != null) {
            saleInfo.receivingContainerUID = scannedCode;
            String containerType = "container";
            dynamic container = await getContainerByAlternateUID(scannedCode);
            if (!container.isEmpty) {
              containerType = container["template"]["RALType"];
            }
            await sellCoffee(saleInfo, containerType);
            Navigator.of(context).pop();
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
    return SizedBox(
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
          String buttonText = "NEXT";
          if (_currentStep == 0 ||
              (_currentStep == 2 && widget.receivingContainerUID == null)) {
            buttonText = "SCAN!";
          } else if (_currentStep == 1 &&
              widget.receivingContainerUID != null) {
            buttonText = "START!";
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
                    child: const Text('BACK',
                        style: TextStyle(color: Colors.black)),
                  ),
                ),
            ],
          );
        },
      ),
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
    String? selectedCountry = 'Honduras';
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
                                      .map((state) =>
                                          getLanguageSpecificState(state))
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
                      OverflowBar(
                        overflowAlignment: OverflowBarAlignment.center,
                        children: [
                          TextButton(
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.black87)),
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
                                await fshowInfoDialog(context,
                                    "Please fill all fields correctly");
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
                            child: Text('Confirm'),
                          ),
                        ],
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

String getLanguageSpecificState(Map<String, dynamic> state) {
  dynamic rState;
  rState = state['name']['spanish']; //ToDo specify

  rState ??= state['name']['english'];
  return rState as String;
}

Future<void> sellCoffee(SaleInfo saleInfo, String containerType) async {
  // PROCESS FINISHED - GENERATE AND STORE OBJECTS AND PROCESSES
  //*******  A. load or generate objects of the processes ************

  // 1. Check if receiving container exists. If not generate new one.
  receivingContainer = {};
  receivingContainer = await getObjectOrGenerateNew(
      saleInfo.receivingContainerUID!, containerType, "alternateUid");
  if (getObjectMethodUID(receivingContainer) == "") {
    receivingContainer["identity"]["alternateIDs"]
        .add({"UID": saleInfo.receivingContainerUID, "issuedBy": "owner"});
    receivingContainer["currentOwners"] = [
      {"UID": getObjectMethodUID(appUserDoc!), "role": "owner"}
    ];
    receivingContainer = await setObjectMethod(receivingContainer, true);
  }
  debugPrint("generated container ${getObjectMethodUID(receivingContainer)}");

  // 2. Check if field  (by GeoId) exists. If not generate new one. Also generate new Owner => geoID as tag for owner
  //look for a field that have geoId as alternateIDs
  field = {};
  field =
      await getObjectOrGenerateNew(saleInfo.geoId!, "field", "alternateUid");

  if (getObjectMethodUID(field) == "") {
    field["identity"]["alternateIDs"]
        .add({"UID": saleInfo.geoId, "issuedBy": "Asset Registry"});
    field = await setObjectMethod(field, true);
  }
  debugPrint("generated field ${getObjectMethodUID(field)}");

  //! due to project specifications, field and company are the same for Honduras atm
  seller = {};
  seller =
      await getObjectOrGenerateNew(saleInfo.geoId!, "company", "alternateUid");
  //ToDo: Would be better to have company information
  if (getObjectMethodUID(seller) == "") {
    seller["identity"]["alternateIDs"]
        .add({"UID": saleInfo.geoId, "issuedBy": "Asset Registry"});
    seller = await setObjectMethod(seller, true);
  }
  debugPrint("generated seller ${getObjectMethodUID(seller)}");

  // 3. Generate process "coffee" and put information of the coffee into
  coffee = {};
  coffee = await getOpenRALTemplate("coffee");
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
  coffee = await setObjectMethod(coffee, true);
  debugPrint("generated harvest ${getObjectMethodUID(coffee)}");

  //********* B. Generate process "transfer_ownership" (selling process) *********
  transfer_ownership = {};
  transfer_ownership = await getOpenRALTemplate("changeOwner");
  //Tobject, oldOwner = seller, newOwner = user  => executeRalMethod => currentOwner tauschen

  transfer_ownership = addInputobject(transfer_ownership, coffee, "soldItem");
  transfer_ownership = addInputobject(transfer_ownership, seller, "seller");
  transfer_ownership = addInputobject(transfer_ownership, appUserDoc!, "buyer");
  transfer_ownership =
      addOutputobject(transfer_ownership, coffee, "boughtItem");
  transfer_ownership["executor"] = seller;
  transfer_ownership["methodState"] = "finished";
  transfer_ownership = await setObjectMethod(transfer_ownership, true);

  //"execute method changeOwner"
  coffee["currentOwners"] = [
    {"UID": getObjectMethodUID(appUserDoc!), "role": "owner"}
  ];
  coffee = await setObjectMethod(coffee, true);

  await updateMethodHistories(transfer_ownership);

  //Make sure the sold object is present in post-process form in method!
  transfer_ownership =
      addOutputobject(transfer_ownership, coffee, "boughtItem");
  transfer_ownership = await setObjectMethod(transfer_ownership, true);

  //******* C. Generate process "change_container" (put harvest into container) *********
  change_container = {};
  change_container = await getOpenRALTemplate("changeContainer");
  //coffee neu laden für nächsten Schritt!!!
  coffee = await getObjectMethod(getObjectMethodUID(coffee));

  change_container = addInputobject(change_container, coffee, "item");
  change_container = addInputobject(change_container, field, "oldContainer");
  change_container =
      addInputobject(change_container, receivingContainer, "newContainer");

  //"execute method changeLocation"
  coffee["currentGeolocation"]["container"]["UID"] =
      getObjectMethodUID(receivingContainer);
  change_container = addOutputobject(change_container, coffee, "item");

  change_container["executor"] = appUserDoc!;
  change_container["methodState"] = "finished";
  change_container = await setObjectMethod(change_container, true);

  coffee = await setObjectMethod(coffee, true);

  //an method histories  von field (Ernte), receiving container, coffee anhängen
  await updateMethodHistories(change_container);
  //Make sure the sold object is present in post-process form in method!
  change_container = addOutputobject(change_container, coffee, "item");
  change_container = await setObjectMethod(change_container, true);

  debugPrint("Transfer of ownership finished");
}
