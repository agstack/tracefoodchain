import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/open_ral_service.dart';
import '../helpers/json_full_double_to_int.dart';
import '../helpers/sort_json_alphabetically.dart';

/// Multi-Step Stepper für die Registrierung von Farmer, Farm und Feldern
/// Speichert alle Daten mit objectState "qcPending" und verwendet generateDigitalSibling
class StepperRegistrarRegistration extends StatefulWidget {
  const StepperRegistrarRegistration({super.key});

  @override
  State<StepperRegistrarRegistration> createState() =>
      _StepperRegistrarRegistrationState();
}

class _StepperRegistrarRegistrationState
    extends State<StepperRegistrarRegistration> {
  int _currentStep = 0;
  bool _isProcessing = false;

  // Farmer Daten
  final TextEditingController _farmerFirstNameController =
      TextEditingController();
  final TextEditingController _farmerLastNameController =
      TextEditingController();
  final TextEditingController _farmerNationalIDController =
      TextEditingController();
  final TextEditingController _farmerPhoneController = TextEditingController();
  final TextEditingController _farmerEmailController = TextEditingController();

  // Farm Daten
  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _farmCityController = TextEditingController();
  final TextEditingController _farmStateController = TextEditingController();
  final TextEditingController _farmEmailController = TextEditingController();

  // Position cache
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentPosition();
  }

  Future<void> _getCurrentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint('Error getting position: $e');
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validiere Farmer-Daten
      if (!_validateFarmerData()) return;
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      // Validiere Farm-Daten und registriere
      if (!_validateFarmData()) return;
      _completeRegistration();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  bool _validateFarmerData() {
    final l10n = AppLocalizations.of(context)!;
    if (_farmerFirstNameController.text.trim().isEmpty ||
        _farmerLastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${l10n.firstName} and ${l10n.lastName} required')),
      );
      return false;
    }
    return true;
  }

  bool _validateFarmData() {
    final l10n = AppLocalizations.of(context)!;
    if (_farmNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.farmName} required')),
      );
      return false;
    }
    return true;
  }

  Future<void> _completeRegistration() async {
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isProcessing = true);

    try {
      debugPrint('=== START REGISTRATION ===');

      // 1. Erstelle Farmer (Human)
      debugPrint('Step 1: Creating farmer template');
      final farmerUID = const Uuid().v4();
      debugPrint('Farmer UID: $farmerUID');

      Map<String, dynamic> farmer = await getOpenRALTemplate('human');
      debugPrint('Farmer template loaded successfully');

      setObjectMethodUID(farmer, farmerUID);
      debugPrint('Farmer UID set');

      farmer['identity']['name'] =
          '${_farmerFirstNameController.text} ${_farmerLastNameController.text}';
      debugPrint('Farmer name set: ${farmer['identity']['name']}');

      farmer['objectState'] = 'qcPending';
      debugPrint('Farmer objectState set');

      // Farmer specificProperties
      debugPrint('Setting farmer specific properties...');
      farmer = setSpecificPropertyJSON(
          farmer, 'firstName', _farmerFirstNameController.text, 'String');
      debugPrint('firstName set');

      farmer = setSpecificPropertyJSON(
          farmer, 'lastName', _farmerLastNameController.text, 'String');
      debugPrint('lastName set');

      farmer = setSpecificPropertyJSON(farmer, 'userRole', 'Farmer', 'String');
      debugPrint('userRole set');

      if (_farmerNationalIDController.text.isNotEmpty) {
        debugPrint('Setting nationalID...');
        farmer = setSpecificPropertyJSON(
            farmer, 'nationalID', _farmerNationalIDController.text, 'String');
        // Auch in alternateIDs
        farmer['identity']['alternateIDs'].add({
          'UID': _farmerNationalIDController.text,
          'issuedBy': 'National ID',
        });
        debugPrint('nationalID set');
      }

      if (_farmerPhoneController.text.isNotEmpty) {
        debugPrint('Setting phoneNumber...');
        farmer = setSpecificPropertyJSON(
            farmer, 'phoneNumber', _farmerPhoneController.text, 'String');
        debugPrint('phoneNumber set');
      }

      if (_farmerEmailController.text.isNotEmpty) {
        debugPrint('Setting farmer email...');
        farmer = setSpecificPropertyJSON(
            farmer, 'email', _farmerEmailController.text, 'String');
        debugPrint('farmer email set');
      }

      // Position
      debugPrint('Setting farmer geolocation...');
      if (_currentPosition != null) {
        farmer['currentGeolocation']['geoCoordinates'] = {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        };
        debugPrint('Farmer coordinates set');
      }
      farmer['currentGeolocation']['postalAddress']['country'] = 'Honduras';
      if (_farmCityController.text.isNotEmpty) {
        farmer['currentGeolocation']['postalAddress']['cityName'] =
            _farmCityController.text;
      }
      if (_farmStateController.text.isNotEmpty) {
        farmer['currentGeolocation']['postalAddress']['stateName'] =
            _farmStateController.text;
      }
      debugPrint('Farmer geolocation complete');

      // 2. Erstelle Farm
      debugPrint('Step 2: Creating farm template');
      final farmUID = const Uuid().v4();
      debugPrint('Farm UID: $farmUID');

      Map<String, dynamic> farm = await getOpenRALTemplate('farm');
      debugPrint('Farm template loaded successfully');

      setObjectMethodUID(farm, farmUID);
      debugPrint('Farm UID set');

      farm['identity']['name'] = _farmNameController.text;
      debugPrint('Farm name set: ${farm['identity']['name']}');

      farm['objectState'] = 'qcPending';
      debugPrint('Farm objectState set');

      // Link Farmer zu Farm
      debugPrint('Linking farmer to farm...');
      farm['linkedObjectRef'].add({
        'UID': farmerUID,
        'RALType': 'human',
        'role': 'farmer',
      });
      debugPrint('Farmer linked to farm');

      // Farm Position
      debugPrint('Setting farm geolocation...');
      if (_currentPosition != null) {
        farm['currentGeolocation']['geoCoordinates'] = {
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        };
        debugPrint('Farm coordinates set');
      }
      farm['currentGeolocation']['postalAddress']['country'] = 'Honduras';
      if (_farmCityController.text.isNotEmpty) {
        farm['currentGeolocation']['postalAddress']['cityName'] =
            _farmCityController.text;
      }
      if (_farmStateController.text.isNotEmpty) {
        farm['currentGeolocation']['postalAddress']['stateName'] =
            _farmStateController.text;
      }
      debugPrint('Farm geolocation complete');

      debugPrint('Setting farm specific properties...');
      farm = setSpecificPropertyJSON(farm, 'farmerCount', 1, 'int');
      debugPrint('farmerCount set');

      if (_farmEmailController.text.isNotEmpty) {
        debugPrint('Setting farm email...');
        farm = setSpecificPropertyJSON(
            farm, 'email', _farmEmailController.text, 'String');
        debugPrint('farm email set');
      }

      // 3. Erstelle generateDigitalSibling Methode
      debugPrint('Step 3: Creating generateDigitalSibling method');
      Map<String, dynamic> registerMethod =
          await getOpenRALTemplate('generateDigitalSibling');
      debugPrint('Method template loaded successfully');

      final methodUID = const Uuid().v4();
      debugPrint('Method UID: $methodUID');

      setObjectMethodUID(registerMethod, methodUID);
      debugPrint('Method UID set');

      registerMethod['identity']['name'] =
          'Farm Registration - ${_farmNameController.text}';
      debugPrint('Method name set');

      registerMethod['methodState'] = 'finished';
      debugPrint('Method state set');

      debugPrint(
          'Setting executor (appUserDoc type: ${appUserDoc.runtimeType})');
      registerMethod['executor'] = appUserDoc!;
      debugPrint('Executor set');

      registerMethod['existenceStarts'] =
          DateTime.now().toUtc().toIso8601String();
      debugPrint('existenceStarts set');

      // Output objects: Farmer, Farm
      debugPrint('Step 4: Adding output objects');
      debugPrint(
          'Adding farmer to method (farmer type: ${farmer.runtimeType})');
      addOutputobject(registerMethod, farmer, 'farmer');
      debugPrint('Farmer added to method');

      debugPrint('Adding farm to method (farm type: ${farm.runtimeType})');
      addOutputobject(registerMethod, farm, 'farm');
      debugPrint('Farm added to method');

      // 4. Update method histories
      debugPrint('Step 5: Updating method histories');
      farmer['methodHistoryRef'].add({
        'UID': methodUID,
        'RALType': 'generateDigitalSibling',
      });
      debugPrint('Farmer method history updated');

      farm['methodHistoryRef'].add({
        'UID': methodUID,
        'RALType': 'generateDigitalSibling',
      });
      debugPrint('Farm method history updated');

      // 5. Speichere alle Objekte (sortieren und konvertieren)
      debugPrint('Step 6: Saving farmer object');
      debugPrint('Farmer before sort (type: ${farmer.runtimeType})');
      farmer = jsonFullDoubleToInt(sortJsonAlphabetically(farmer));
      debugPrint(
          'Farmer after jsonFullDoubleToInt (type: ${farmer.runtimeType})');
      await setObjectMethod(farmer, false, false);
      debugPrint('Farmer saved successfully');

      debugPrint('Step 7: Saving farm object');
      debugPrint('Farm before sort (type: ${farm.runtimeType})');
      farm = jsonFullDoubleToInt(sortJsonAlphabetically(farm));
      debugPrint('Farm after jsonFullDoubleToInt (type: ${farm.runtimeType})');
      await setObjectMethod(farm, false, false);
      debugPrint('Farm saved successfully');

      // 6. Speichere und signiere Methode
      debugPrint('Step 8: Saving and signing method');
      debugPrint('Method before sort (type: ${registerMethod.runtimeType})');
      registerMethod =
          jsonFullDoubleToInt(sortJsonAlphabetically(registerMethod));
      debugPrint(
          'Method after jsonFullDoubleToInt (type: ${registerMethod.runtimeType})');
      await setObjectMethod(
          registerMethod, true, true); // Signieren und für Sync markieren
      debugPrint('Method saved and signed successfully');

      // Aktualisiere UI
      debugPrint('Step 9: Updating UI');
      repaintContainerList.value = true;
      rebuildSpeedDial.value = true;
      debugPrint('UI updated');

      debugPrint('=== REGISTRATION COMPLETED SUCCESSFULLY ===');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.registrationSuccessful),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e, stackTrace) {
      debugPrint('=== REGISTRATION ERROR ===');
      debugPrint('Registration error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.registrationFailed}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _farmerFirstNameController.dispose();
    _farmerLastNameController.dispose();
    _farmerNationalIDController.dispose();
    _farmerPhoneController.dispose();
    _farmerEmailController.dispose();
    _farmNameController.dispose();
    _farmCityController.dispose();
    _farmStateController.dispose();
    _farmEmailController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final l10n = AppLocalizations.of(context)!;

    // Prüfe ob Daten eingegeben wurden
    final hasData = _farmerFirstNameController.text.isNotEmpty ||
        _farmerLastNameController.text.isNotEmpty ||
        _farmerNationalIDController.text.isNotEmpty ||
        _farmerPhoneController.text.isNotEmpty ||
        _farmerEmailController.text.isNotEmpty ||
        _farmNameController.text.isNotEmpty ||
        _farmCityController.text.isNotEmpty ||
        _farmStateController.text.isNotEmpty ||
        _farmEmailController.text.isNotEmpty;

    if (!hasData || _isProcessing) {
      return true; // Erlaube Zurück wenn keine Daten oder während Processing
    }

    // Zeige Bestätigungsdialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.cancelRegistration,
          style: const TextStyle(color: Colors.black),
        ),
        content: Text(
          l10n.cancelRegistrationMessage,
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n.continueRegistration,
              style: const TextStyle(color: Colors.blue),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(l10n.discardData),
          ),
        ],
      ),
    );

    return result ?? false; // Default: nicht verlassen
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.registerFarmFarmer),
          elevation: 2,
        ),
        body: Stack(
          children: [
            Stepper(
              currentStep: _currentStep,
              onStepContinue: _isProcessing ? null : _nextStep,
              onStepCancel: _currentStep > 0 ? _previousStep : null,
              controlsBuilder: (context, details) {
                final l10n = AppLocalizations.of(context)!;
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: Text(_currentStep == 1
                            ? l10n.completeRegistration
                            : l10n.next),
                      ),
                      const SizedBox(width: 8),
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: Text(l10n.back),
                        ),
                    ],
                  ),
                );
              },
              steps: [
                // Schritt 1: Farmer Information
                Step(
                  title: Text(
                    l10n.farmerInformation,
                    style: const TextStyle(color: Colors.black),
                  ),
                  subtitle: Text(
                    _farmerFirstNameController.text.isEmpty
                        ? l10n.farmerDetails
                        : '${_farmerFirstNameController.text} ${_farmerLastNameController.text}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  isActive: _currentStep >= 0,
                  state:
                      _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: _buildFarmerForm(),
                ),

                // Schritt 2: Farm Information
                Step(
                  title: Text(
                    l10n.farmInformation,
                    style: const TextStyle(color: Colors.black),
                  ),
                  subtitle: Text(
                    _farmNameController.text.isEmpty
                        ? l10n.farmDetails
                        : _farmNameController.text,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  isActive: _currentStep >= 1,
                  state: StepState.indexed,
                  content: _buildFarmForm(),
                ),
              ],
            ),

            // Loading Overlay
            if (_isProcessing)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            l10n.recordingInProgress,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerForm() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _farmerFirstNameController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: l10n.firstName,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _farmerLastNameController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: l10n.lastName,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _farmerNationalIDController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: l10n.nationalID,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.badge),
            hintText: 'e.g., 0801-1990-12345',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _farmerPhoneController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: l10n.phoneNumber,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.phone),
            hintText: '+504-9999-8888',
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _farmerEmailController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: l10n.email,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.email),
            hintText: 'farmer@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  Widget _buildFarmForm() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _farmNameController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: l10n.farmName,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.agriculture),
            hintText: 'e.g., Finca Santa Ana',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _farmCityController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: l10n.cityName,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.location_city),
            hintText: 'e.g., Marcala',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _farmStateController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: l10n.stateName,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.map),
            hintText: 'e.g., La Paz',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _farmEmailController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: l10n.email,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.email),
            hintText: 'farm@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }
}
