import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import 'package:trace_foodchain_app/screens/peer_transfer_screen.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/scanning_service.dart';
import '../l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui';

Map<String, dynamic> receivingContainer = {};
Map<String, dynamic> field = {};
Map<String, dynamic> seller = {};
Map<String, dynamic> coffee = {};
Map<String, dynamic> transfer_ownership = {};
Map<String, dynamic> change_container = {};
String receivingContainerUID = "";

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

class StepperBuyCoffee {
  Future<void> startProcess(BuildContext context,
      {String? receivingContainerUID}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return BuyCoffeeStepper(receivingContainerUID: receivingContainerUID);
      },
    );
  }
}

class BuyCoffeeStepper extends StatefulWidget {
  // final SaleInfo saleInfo;
  // CoffeeSaleStepper({required this.saleInfo});
  final String? receivingContainerUID;
  const BuyCoffeeStepper({super.key, this.receivingContainerUID});

  @override
  _BuyCoffeeStepperState createState() => _BuyCoffeeStepperState();
}

class _BuyCoffeeStepperState extends State<BuyCoffeeStepper> {
  int _currentStep = 0;
  final ValueNotifier<bool> _isProcessing = ValueNotifier(false);
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
    List<Step> steps = [];

    if (widget.receivingContainerUID == null) {
      steps.add(Step(
        title: Text(l10n.scanSelectFutureContainer,
            style: const TextStyle(color: Colors.black)),
        content: Text(l10n.scanContainerInstructions,
            style: const TextStyle(color: Colors.black)),
        isActive: _currentStep >= 0,
      ));
    }

    steps.addAll([
      Step(
        title: Text(l10n.presentInfoToSeller,
            style: const TextStyle(color: Colors.black)),
        content: Text(l10n.presentInfoToSellerInstructions,
            style: const TextStyle(color: Colors.black)),
        isActive:
            _currentStep >= (widget.receivingContainerUID == null ? 1 : 0),
      ),
      Step(
        title: Text(l10n.receiveDataFromSeller,
            style: const TextStyle(color: Colors.black)),
        content: Text(l10n.receiveDataFromSellerInstructions,
            style: const TextStyle(color: Colors.black)),
        isActive:
            _currentStep >= (widget.receivingContainerUID == null ? 2 : 1),
      ),
    ]);

    return steps;
  }

  void _nextStep() async {
    switch (_currentStep) {
      case 0:
        if (widget.receivingContainerUID == null) {
          // Scan or select container
          var scannedCode = await ScanningService.showScanDialog(
              context, Provider.of<AppState>(context, listen: false), true);
          if (scannedCode != null) {
            saleInfo.receivingContainerUID = scannedCode;
            setState(() {
              _currentStep += 1;
            });
          }
        } else {
          // If container UID is provided, move directly to presenting information
          _presentInformationToSeller();
        }
        break;
      case 1:
        if (widget.receivingContainerUID == null) {
          _presentInformationToSeller();
        } else {
          _receiveDataFromSeller();
        }
        break;
      case 2:
        _receiveDataFromSeller();
        break;
      default:
        Navigator.of(context).pop();
    }
  }

  void _presentInformationToSeller() async {
    _isProcessing.value = true;
    final transmittedList =
        await initBuyCoffee(saleInfo.receivingContainerUID!);
    _isProcessing.value = false;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PeerTransferScreen(
          transferMode: "send",
          transferredDataOutgoing: transmittedList,
        ),
      ),
    ).then((result) {
      setState(() {
        _currentStep += 1;
      });
    });
  }

  void _receiveDataFromSeller() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PeerTransferScreen(
          transferMode: "receive",
          transferredDataOutgoing: [],
        ),
      ),
    ).then((receivedData) async {
      if (receivedData != null) {
        _isProcessing.value = true;
        await finishBuyCoffee(receivedData);
      }
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget mainContent = AlertDialog(
      title: Text(l10n.buyCoffeeDeviceToDevice,
          style: const TextStyle(color: Colors.black)),
      content: SizedBox(
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
            String buttonText;
            if (widget.receivingContainerUID != null) {
              buttonText = _currentStep == 0 ? l10n.present : l10n.receive;
            } else {
              switch (_currentStep) {
                case 0:
                  buttonText = l10n.scan;
                  break;
                case 1:
                  buttonText = l10n.present;
                  break;
                case 2:
                  buttonText = l10n.receive;
                  break;
                default:
                  buttonText = l10n.next;
              }
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
                      child: Text(l10n.back,
                          style: const TextStyle(color: Colors.black)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(l10n.cancel, style: const TextStyle(color: Colors.black)),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );

    return Stack(
      children: [
        mainContent,
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
                                l10n.coffeeIsBought,
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
}

Future<List<Map<String, dynamic>>> initBuyCoffee(
    String receivingContainerUID) async {
  List<Map<String, dynamic>> rList = [];

  receivingContainer = await getObjectOrGenerateNew(receivingContainerUID,
      ["container", "bag", "building", "transportVehicle"], "alternateUid");
  if (getObjectMethodUID(receivingContainer) == "") {
    //This is a new container!!!
    receivingContainer["identity"]["alternateIDs"]
        .add({"UID": receivingContainerUID, "issuedBy": "owner"});
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
  }");

  transfer_ownership = await getOpenRALTemplate("changeOwner");
  setObjectMethodUID(transfer_ownership, const Uuid().v4());
  transfer_ownership = addInputobject(transfer_ownership, appUserDoc!, "buyer");
  //do not add executor, since this will be the seller
  transfer_ownership["methodState"] =
      "planned"; //ARE NOT PERSISTED, JUST SENT TO SELLER!

  change_container = await getOpenRALTemplate("changeContainer");
  setObjectMethodUID(change_container, const Uuid().v4());
  change_container =
      addInputobject(change_container, receivingContainer, "newContainer");
  change_container["executor"] = appUserDoc!;
  change_container["methodState"] =
      "planned"; //ARE NOT PERSISTED, JUST SENT TO SELLER!

//Sign both methods before sending them to the seller
  List<String> pathsToSign = [
    //sales process buyer side, we know the new container but do not know what will be inside
    "\$.identity.UID",
    "\$.inputObjects[?(@.role=='newContainer')]",
    "\$.executor"
  ];
  String signingObject = createSigningObject(pathsToSign, change_container);
  if (kDebugMode) {
    //await Share.share(signingObject);
  }
  final signature = await digitalSignature.generateSignature(signingObject);
  if (change_container["digitalSignatures"] == null) {
    change_container["digitalSignatures"] = [];
  }
  change_container["digitalSignatures"].add({
    "signature": signature,
    "signerUID": FirebaseAuth.instance.currentUser?.uid,
    "signedContent": pathsToSign
  });

  pathsToSign = [
    "\$.identity.UID",
    "\$.inputObjects[?(@.role=='buyer')]" //At this time, we only know the buyer
  ];
  signingObject = createSigningObject(pathsToSign, transfer_ownership);
  if (kDebugMode) {
    //await Share.share(signingObject);
  }
  final signature2 = await digitalSignature.generateSignature(signingObject);
  if (transfer_ownership["digitalSignatures"] == null) {
    transfer_ownership["digitalSignatures"] = [];
  }
  transfer_ownership["digitalSignatures"].add({
    "signature": signature2,
    "signerUID": FirebaseAuth.instance.currentUser?.uid,
    "signedContent": pathsToSign
  });

  rList.add(transfer_ownership);
  rList.add(change_container);

  return rList;
}

Future<void> finishBuyCoffee(dynamic receivedData) async {
  // This function persists all outputobjects and jobs in local database
  //The jobs are received in finished form from the seller

  // First, persist all non-job objects
  List<dynamic> jobItems = [];
  for (final jobOrObject in receivedData) {
    final isJob = jobOrObject["methodHistoryRef"] != null;
    if (!isJob) {
      // If it is an object, change ownership!
      if (jobOrObject["currentOwners"] != null) {
        jobOrObject["currentOwners"] = [
          {"UID": getObjectMethodUID(appUserDoc!), "role": "owner"}
        ];
      }
      jobOrObject.remove('needsSync');
      await setObjectMethod(jobOrObject, false, false);
    } else {
      jobItems.add(jobOrObject);
    }
  }

  // Next, persist all jobs (methods)
  for (final jobOrObject in jobItems) {
    await setObjectMethod(
        jobOrObject, false, true); //Do NOT sign again after return!!!
  }
}
