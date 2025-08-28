import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/widgets/custom_text_field.dart';
import 'package:trace_foodchain_app/services/scanning_service.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import '../l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui';

//ToDo: Offer to add 1-n additional ID tags like GeoId

class AddEmptyItemDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onItemAdded;

  const AddEmptyItemDialog({super.key, required this.onItemAdded});

  @override
  _AddEmptyItemDialogState createState() => _AddEmptyItemDialogState();
}

class _AddEmptyItemDialogState extends State<AddEmptyItemDialog> {
  String? _capacityError;
  String? _selectedType;
  String? _selectedUnit;
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _uidController = TextEditingController();
  // Neuer Controller für "Name des Container"
  final TextEditingController _containerNameController =
      TextEditingController();
  late List<Map<String, dynamic>> _weightUnits;
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  String? _latitudeError;
  String? _longitudeError;
  String? _uidError; // Add this line
  final ValueNotifier<bool> _isProcessing = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);

    _weightUnits = getWeightUnits(country);
    if (_weightUnits.isNotEmpty) {
      _selectedUnit = _weightUnits[0]['name'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final l10n = AppLocalizations.of(context)!;
    Widget dialogContent = AlertDialog(
      title: Text(
        l10n.addEmptyItem,
        style: const TextStyle(color: Colors.black),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTypeSelector(),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _capacityController,
              hintText: l10n.maxCapacity,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                DecimalTextInputFormatter(),
                LengthLimitingTextInputFormatter(10),
              ],
              validator: _validateCapacity,
              errorText: _capacityError,
            ),
            const SizedBox(height: 8),
            _buildUnitDropdown(),
            // Neuer Eingabebereich für "Name des Container"
            const SizedBox(height: 16),
            CustomTextField(
              controller: _containerNameController,
              hintText: l10n.setItemName,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _uidController,
                    hintText: l10n.uid,
                    // Remove errorText here
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: l10n.scanQRCode,
                  onPressed: _scanUID,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.geolocation,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _latitudeController,
                    hintText: l10n.latitude,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalTextInputFormatter()],
                    errorText: _latitudeError,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomTextField(
                    controller: _longitudeController,
                    hintText: l10n.longitude,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalTextInputFormatter()],
                    errorText: _longitudeError,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (appState.hasGPS)
              ElevatedButton(
                onPressed: _getCurrentLocation,
                child: Center(
                  child: Text(
                    l10n.useCurrentLocation,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _addItem,
          child: Text(l10n.add),
        ),
      ],
    );

    return Stack(
      children: [
        dialogContent,
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
                                l10n.generatingItem, // Stelle sicher, dass ein entsprechender String im AppLocalizations existiert
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

  String? _validateCapacity(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)!.fieldRequired;
    }
    if (double.tryParse(value) == null) {
      return AppLocalizations.of(context)!.invalidNumber;
    }
    return null;
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      setState(() {
        _latitudeController.text = position.latitude.toString();
        _longitudeController.text = position.longitude.toString();
      });
    } catch (e) {
      await fshowInfoDialog(
        context,
        AppLocalizations.of(context)!.locationError,
      );
    }
  }

  String? _validateCoordinate(String? value, bool isLatitude) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)!.fieldRequired;
    }
    double? coordinate = double.tryParse(value);
    if (coordinate == null) {
      return AppLocalizations.of(context)!.invalidNumber;
    }
    if (isLatitude && (coordinate < -90 || coordinate > 90)) {
      return AppLocalizations.of(context)!.invalidLatitude;
    }
    if (!isLatitude && (coordinate < -180 || coordinate > 180)) {
      return AppLocalizations.of(context)!.invalidLongitude;
    }
    return null;
  }

  Widget _buildTypeSelector() {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTypeOption('bag', Icons.shopping_bag, l10n.bag),
        _buildTypeOption('container', Icons.inventory_2, l10n.container),
        _buildTypeOption('building', Icons.business, l10n.building),
        _buildTypeOption(
            'transportVehicle', Icons.local_shipping, l10n.transportVehicle),
      ],
    );
  }

  Widget _buildTypeOption(String type, IconData icon, String label) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 32,
                color:
                    isSelected ? Theme.of(context).primaryColor : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitDropdown() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedUnit,
        decoration: InputDecoration(
          labelText: l10n.unit,
          border: const OutlineInputBorder(),
        ),
        items: _weightUnits.map((unit) {
          return DropdownMenuItem<String>(
            value: unit['name'],
            child: Text(
              unit['name'],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedUnit = newValue;
          });
        },
      ),
    );
  }

  Future<void> _scanUID() async {
    final scannedCode = await ScanningService.showScanDialog(
        context, Provider.of<AppState>(context, listen: false), true);
    if (scannedCode != null) {
      final isUIDTaken = await checkAlternateIDExists(scannedCode);
      if (isUIDTaken) {
        _uidController.text = '';
        await fshowInfoDialog(
          context,
          AppLocalizations.of(context)!.uidAlreadyExists,
        );
      } else {
        setState(() {
          _uidController.text = scannedCode;
        });
      }
    }
  }

  Future<void> _addItem() async {
    final l10n = AppLocalizations.of(context)!;

    final isUIDTaken = await checkAlternateIDExists(_uidController.text);
    if (isUIDTaken) {
      await fshowInfoDialog(
        context,
        l10n.uidAlreadyExists,
      );
      _uidController.text = '';
      return;
    }

    setState(() {
      _capacityError = _validateCapacity(_capacityController.text);
    });

    if (_selectedType == null ||
        _capacityController.text.isEmpty ||
        _selectedUnit == null ||
        _uidController.text.isEmpty) {
      await fshowInfoDialog(context, l10n.pleaseCompleteAllFields);
      return;
    }
    _isProcessing.value = true;
    try {
      Map<String, dynamic> newItem = await getOpenRALTemplate(_selectedType!);
      setObjectMethodUID(newItem, const Uuid().v4());
      newItem["identity"]["name"] = _containerNameController.text;
      newItem["identity"]["alternateIDs"] = [
        {"UID": _uidController.text, "issuedBy": "owner"}
      ];
      newItem = setSpecificPropertyJSON(
          newItem,
          "max capacity",
          double.parse(_capacityController.text.replaceAll(",", ".")),
          _selectedUnit!);
      newItem["currentOwners"] = [
        {"UID": getObjectMethodUID(appUserDoc!), "role": "owner"}
      ];

      if (_latitudeController.text != "" && _longitudeController.text != "") {
        newItem["currentGeolocation"]["geoCoordinates"] = {
          "latitude":
              double.parse(_latitudeController.text.replaceAll(",", ".")),
          "longitude":
              double.parse(_longitudeController.text.replaceAll(",", ".")),
        };
      }

      final addItem = await getOpenRALTemplate("generateDigitalSibling");
      //Add Executor
      addItem["executor"] = appUserDoc;
      addItem["methodState"] = "finished";
      //Step 1: get method an uuid (for method history entries)
      setObjectMethodUID(addItem, const Uuid().v4());
      //Step 2: save the objects a first time to get it the method history change
      await setObjectMethod(newItem, false, false);
      //Step 3: add the output objects with updated method history to the method
      addOutputobject(addItem, newItem, "item");
      //Step 4: update method history in all affected objects (will also tag them for syncing)
      await updateMethodHistories(addItem);
      //Step 5: again add Outputobjects to generate valid representation in the method
      newItem = await getLocalObjectMethod(getObjectMethodUID(newItem));
      addOutputobject(addItem, newItem, "item");
      //Step 6: persist process
      await setObjectMethod(addItem, true, true); //sign it!

      final savedItem = await getLocalObjectMethod(getObjectMethodUID(
          newItem)); //Reload new item with correct method history
      widget.onItemAdded(savedItem);
    } catch (e) {}
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

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required String hintText,
    required void Function(String?) onChanged,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        (items.isEmpty)
            ? Text(l10n.selectCountryFirst,
                style: const TextStyle(color: Colors.red))
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: DropdownButton<String>(
                  value: value,
                  hint: Text(hintText),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: items.map((String item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    );
                  }).toList(),
                  onChanged: onChanged,
                ),
              ),
      ],
    );
  }
}
