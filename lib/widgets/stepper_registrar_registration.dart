import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:camera/camera.dart' as camera_plugin;
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/open_ral_service.dart';
import '../services/firebase_storage_service.dart';
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
  final TextEditingController _farmIDController = TextEditingController();
  final TextEditingController _farmCityController = TextEditingController();
  final TextEditingController _farmStateController = TextEditingController();
  final TextEditingController _farmEmailController = TextEditingController();

  // Position cache
  Position? _currentPosition;

  // National ID Photo
  XFile? _nationalIDPhoto;
  String? _nationalIDPhotoLocalPath;
  final ImagePicker _imagePicker = ImagePicker();
  camera_plugin.CameraController? _cameraController;
  List<camera_plugin.CameraDescription>? _cameras;
  bool _showCameraPreview = false;

  @override
  void initState() {
    super.initState();
    _initializeAndCheckStorage();
    _getCurrentPosition();
  }

  /// Prüfe und warte auf localStorage-Initialisierung
  Future<void> _initializeAndCheckStorage() async {
    // Warte bis zu 5 Sekunden auf localStorage-Initialisierung
    int attempts = 0;
    while (!isLocalStorageInitialized() && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (!isLocalStorageInitialized()) {
      debugPrint('WARNING: localStorage still not initialized after waiting');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorLoadingUserData),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      debugPrint('localStorage is initialized and ready for registration');
    }
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
    // Validate National ID Photo is taken (only mandatory in release mode)
    if (!kDebugMode && _nationalIDPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.nationalIDPhotoRequired),
          backgroundColor: Colors.orange,
        ),
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

      // CRITICAL: Check if localStorage is initialized before proceeding
      if (!isLocalStorageInitialized()) {
        debugPrint('ERROR: localStorage not initialized');
        throw Exception(
            'localStorage not initialized. User must be logged in.');
      }
      debugPrint('localStorage is initialized and ready');

      // Photos are stored locally and will be uploaded during cloud sync
      debugPrint(
          'National ID Photo stored locally: $_nationalIDPhotoLocalPath');

      //* ****************  1. Erstelle Farmer (Human) *****************

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

      // Save local photo path - will be replaced with cloud URL during sync
      if (_nationalIDPhotoLocalPath != null &&
          _nationalIDPhotoLocalPath!.isNotEmpty) {
        debugPrint('Setting local nationalIDPhotoPath...');
        farmer = setSpecificPropertyJSON(farmer, 'nationalIDPhotoLocalPath',
            _nationalIDPhotoLocalPath!, 'String');
        debugPrint('nationalIDPhotoLocalPath set: $_nationalIDPhotoLocalPath');
      } else {
        debugPrint('No national ID photo path to save');
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
      farmer['currentGeolocation']['postalAddress']['country'] =
          'Honduras'; //ToDo: Make dynamic
      if (_farmCityController.text.isNotEmpty) {
        farmer['currentGeolocation']['postalAddress']['cityName'] =
            _farmCityController.text;
      }
      if (_farmStateController.text.isNotEmpty) {
        farmer['currentGeolocation']['postalAddress']['stateName'] =
            _farmStateController.text;
      }
      debugPrint('Farmer geolocation complete');

      // Add registrar as currentOwner and in linkedObjectRef
      debugPrint(
          'Adding registrar to farmer currentOwners and linkedObjectRef...');
      farmer['currentOwners'] = [
        {"UID": getObjectMethodUID(appUserDoc!), "role": "registrar"}
      ];
      farmer['linkedObjectRef'].add({
        'UID': getObjectMethodUID(appUserDoc!),
        'RALType': 'user',
        'role': 'registrar',
      });
      debugPrint('Registrar added to farmer');

      //*  ************** 2. Erstelle Farm  **************

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

      // Add Farm ID to alternateIDs if provided
      if (_farmIDController.text.isNotEmpty) {
        debugPrint('Setting farm ID in alternateIDs...');
        farm['identity']['alternateIDs'].add({
          'UID': _farmIDController.text,
          'issuedBy': 'Farm Registry',
        });
        debugPrint('Farm ID set: ${_farmIDController.text}');
      }

      // Link Farmer zu Farm
      debugPrint('Linking farmer to farm...');
      farm['linkedObjectRef'].add({
        'UID': farmerUID,
        'RALType': 'human',
        'role': 'owner',
      });
      debugPrint('Farmer linked to farm');

      // Farm Position
      debugPrint('Setting farm geolocation = current location of registrar...');
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

      // Add registrar as currentOwner and in linkedObjectRef
      debugPrint(
          'Adding registrar to farm currentOwners and linkedObjectRef...');
      farm['currentOwners'] = [
        {"UID": getObjectMethodUID(appUserDoc!), "role": "registrar"}
      ];
      farm['linkedObjectRef'].add({
        'UID': getObjectMethodUID(appUserDoc!),
        'RALType': 'user',
        'role': 'registrar',
      });
      debugPrint('Registrar added to farm');

      //* ****************  3. Erstelle generateDigitalSibling Methode für FARMER (EXAKTE SEQUENZ WIE IN STEPPER_FIRST_SALE) *****************
      debugPrint('Step 3: Creating generateDigitalSibling method for FARMER');
      Map<String, dynamic> farmerRegisterMethod =
          await getOpenRALTemplate('generateDigitalSibling');
      debugPrint('Farmer method template loaded successfully');

      farmerRegisterMethod['identity']['name'] =
          'Farmer Registration - ${_farmerFirstNameController.text} ${_farmerLastNameController.text}';
      farmerRegisterMethod['methodState'] = 'finished';
      farmerRegisterMethod['executor'] = appUserDoc!;
      farmerRegisterMethod['existenceStarts'] =
          DateTime.now().toUtc().toIso8601String();

      //Step 1: get method an uuid (for method history entries)
      setObjectMethodUID(farmerRegisterMethod, const Uuid().v4());
      debugPrint('Farmer Method UID set');

      //Step 2: save the objects a first time to get it the method history change
      await setObjectMethod(farmer, false, false);
      debugPrint('Farmer saved first time');

      //Step 3: add the output objects with updated method history to the method
      addOutputobject(farmerRegisterMethod, farmer, 'farmer');
      debugPrint('Farmer added to method');

      //Step 4: update method history in all affected objects (will also tag them for syncing)
      await updateMethodHistories(farmerRegisterMethod);
      debugPrint('Farmer method history updated');

      //Step 5: again add Outputobjects to generate valid representation in the method
      farmer = await getLocalObjectMethod(getObjectMethodUID(farmer));
      addOutputobject(farmerRegisterMethod, farmer, 'farmer');
      debugPrint('Farmer re-added to method with updated history');

      //Step 6: persist process
      await setObjectMethod(farmerRegisterMethod, true, true); //sign it!
      debugPrint('Farmer method saved and signed successfully');

      //* ****************  4. Erstelle generateDigitalSibling Methode für FARM (EXAKTE SEQUENZ WIE IN STEPPER_FIRST_SALE) *****************
      debugPrint('Step 4: Creating generateDigitalSibling method for FARM');
      Map<String, dynamic> farmRegisterMethod =
          await getOpenRALTemplate('generateDigitalSibling');
      debugPrint('Farm method template loaded successfully');

      farmRegisterMethod['identity']['name'] =
          'Farm Registration - ${_farmNameController.text}';
      farmRegisterMethod['methodState'] = 'finished';
      farmRegisterMethod['executor'] = appUserDoc!;
      farmRegisterMethod['existenceStarts'] =
          DateTime.now().toUtc().toIso8601String();

      //Step 1: get method an uuid (for method history entries)
      setObjectMethodUID(farmRegisterMethod, const Uuid().v4());
      debugPrint('Farm Method UID set');

      //Step 2: save the objects a first time to get it the method history change
      await setObjectMethod(farm, false, false);
      debugPrint('Farm saved first time');

      //Step 3: add the output objects with updated method history to the method
      addOutputobject(farmRegisterMethod, farm, 'farm');
      debugPrint('Farm added to method');

      //Step 4: update method history in all affected objects (will also tag them for syncing)
      await updateMethodHistories(farmRegisterMethod);
      debugPrint('Farm method history updated');

      //Step 5: again add Outputobjects to generate valid representation in the method
      farm = await getLocalObjectMethod(getObjectMethodUID(farm));
      addOutputobject(farmRegisterMethod, farm, 'farm');
      debugPrint('Farm re-added to method with updated history');

      //Step 6: persist process
      await setObjectMethod(farmRegisterMethod, true, true); //sign it!
      debugPrint('Farm method saved and signed successfully');

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

  Future<void> _takeIDPhoto() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      if (kIsWeb) {
        // Web: Open camera preview in dialog
        await _showWebCameraDialog();
      } else {
        // Mobile: Use image_picker for native camera
        final XFile? photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (photo != null) {
          await _savePhoto(photo);
        }
      }
    } catch (e) {
      debugPrint('Error taking ID photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePhoto(XFile photo) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      debugPrint('National ID Photo taken: ${photo.path}');

      // Save photo locally for offline access
      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            'nationalID_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final localPath = '${appDir.path}/nationalIDs/$fileName';

        // Create directory if it doesn't exist
        final directory = Directory('${appDir.path}/nationalIDs');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        // Copy file to local storage
        final File localFile = File(localPath);
        await localFile.writeAsBytes(await photo.readAsBytes());

        setState(() {
          _nationalIDPhoto = photo;
          _nationalIDPhotoLocalPath = localPath;
        });

        debugPrint('National ID Photo saved locally: $localPath');
      } else {
        // Web: Just store the XFile
        setState(() {
          _nationalIDPhoto = photo;
          _nationalIDPhotoLocalPath = photo.name;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.idPhotoTaken),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showWebCameraDialog() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      // Initialize cameras
      _cameras = await camera_plugin.availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      // Use front camera if available, otherwise use first camera
      final camera_plugin.CameraDescription selectedCamera =
          _cameras!.firstWhere(
        (cam) => cam.lensDirection == camera_plugin.CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = camera_plugin.CameraController(
        selectedCamera,
        camera_plugin.ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      // Show camera preview in dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return Dialog(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.takeIDPhoto,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: camera_plugin.CameraPreview(_cameraController!),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        icon: const Icon(Icons.close),
                        label: Text(l10n.cancel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final image =
                                await _cameraController!.takePicture();
                            Navigator.of(dialogContext).pop();
                            await _savePhoto(image);
                          } catch (e) {
                            debugPrint('Error capturing photo: $e');
                          }
                        },
                        icon: const Icon(Icons.camera),
                        label: Text(l10n.capture),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Cleanup camera controller
      await _cameraController?.dispose();
      _cameraController = null;
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
    _farmIDController.dispose();
    _farmCityController.dispose();
    _farmStateController.dispose();
    _farmEmailController.dispose();
    _cameraController?.dispose();
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
        _farmIDController.text.isNotEmpty ||
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

        // National ID Photo Button (Mandatory)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: _nationalIDPhoto == null
                  ? (kDebugMode ? Colors.orange : Colors.red)
                  : Colors.green,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _nationalIDPhoto == null
                        ? Icons.camera_alt
                        : Icons.check_circle,
                    color: _nationalIDPhoto == null
                        ? (kDebugMode ? Colors.orange : Colors.red)
                        : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.nationalIDPhoto,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _nationalIDPhoto == null
                              ? (kDebugMode
                                  ? '${l10n.nationalIDPhotoRequired} (Debug: Optional)'
                                  : l10n.nationalIDPhotoRequired)
                              : l10n.idPhotoTaken,
                          style: TextStyle(
                            color: _nationalIDPhoto == null
                                ? (kDebugMode ? Colors.orange : Colors.red)
                                : Colors.green[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _takeIDPhoto,
                  icon: Icon(_nationalIDPhoto == null
                      ? Icons.camera_alt
                      : Icons.refresh),
                  label: Text(_nationalIDPhoto == null
                      ? l10n.takeIDPhoto
                      : l10n.retakeIDPhoto),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _nationalIDPhoto == null
                        ? (kDebugMode ? Colors.orange : Colors.red)
                        : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_nationalIDPhoto != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? Image.network(
                          _nationalIDPhoto!.path,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(_nationalIDPhoto!.path),
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
              ],
            ],
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
          controller: _farmIDController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            labelText: l10n.farmID,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.tag),
            hintText: 'e.g., FARM-2025-001',
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
