import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:camera/camera.dart' as camera_plugin;
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/open_ral_service.dart';
import '../helpers/json_full_double_to_int.dart';
import '../helpers/sort_json_alphabetically.dart';
import 'polygon_recorder_widget.dart';
import 'stepper_registrar_registration.dart';

/// Widget für die Feldgrenzen-Aufzeichnung mit Pflicht-Verknüpfung zu einer Farm
class FieldBoundaryRecorder extends StatefulWidget {
  const FieldBoundaryRecorder({super.key});

  @override
  State<FieldBoundaryRecorder> createState() => _FieldBoundaryRecorderState();
}

class _FieldBoundaryRecorderState extends State<FieldBoundaryRecorder> {
  Map<String, dynamic>? _selectedFarm;
  List<Map<String, dynamic>> _availableFarms = [];
  bool _isLoadingFarms = true;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _drafts = [];
  String? _selectedDraftKey;
  bool _showFarmSelector = true;

  // Field Photo
  XFile? _fieldPhoto;
  String? _fieldPhotoLocalPath;
  Position? _fieldPhotoPosition;
  bool _isFieldPhotoValid = true;
  final ImagePicker _imagePicker = ImagePicker();
  camera_plugin.CameraController? _cameraController;
  List<camera_plugin.CameraDescription>? _cameras;

  @override
  void initState() {
    super.initState();
    _loadAvailableFarms();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableFarms() async {
    setState(() => _isLoadingFarms = true);

    try {
      List<Map<String, dynamic>> farms = [];

      if (localStorage != null) {
        // Durchsuche localStorage nach Farm-Objekten
        for (var key in localStorage!.keys) {
          final doc = localStorage!.get(key);
          if (doc != null) {
            final Map<String, dynamic> obj = Map<String, dynamic>.from(doc);
            // debugPrint(obj['template']?['RALType']);
            // Prüfe ob es eine Farm ist und der Status nicht qcRejected ist
            if (obj['template']?['RALType'] == 'farm') {
              final status = obj['objectState'];
              if (status != 'qcRejected') {
                farms.add(obj);
              }
            }
          }
        }
      }

      // Sortiere nach Name
      farms.sort((a, b) {
        final aName = a['identity']?['name'] ?? '';
        final bName = b['identity']?['name'] ?? '';
        return aName.compareTo(bName);
      });

      setState(() {
        _availableFarms = farms;
        _isLoadingFarms = false;
      });
    } catch (e) {
      debugPrint('Error loading farms: $e');
      setState(() => _isLoadingFarms = false);
    }
  }

  Future<void> _loadDraftsForFarm(String? farmId) async {
    if (farmId == null) {
      setState(() => _drafts = []);
      return;
    }

    final drafts = await PolygonRecorderWidget.getDraftsForFarm(farmId);
    setState(() => _drafts = drafts);
  }

  void _showPhotoDialog() {
    final l10n = AppLocalizations.of(context)!;

    // Wenn noch kein Foto vorhanden, direkt zur Kamera
    if (_fieldPhoto == null) {
      _takeFieldPhoto();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.fieldPhoto,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              if (_fieldPhoto != null) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: _showFullScreenPhoto,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb
                          ? Image.network(
                              _fieldPhoto!.path,
                              fit: BoxFit.contain,
                            )
                          : Image.file(
                              File(_fieldPhoto!.path),
                              fit: BoxFit.contain,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isFieldPhotoValid
                      ? l10n.fieldPhotoTaken
                      : l10n.fieldPhotoInvalid,
                  style: TextStyle(
                    color: _isFieldPhotoValid
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.photo_camera,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _takeFieldPhoto();
                    },
                    icon: Icon(
                      _fieldPhoto == null ? Icons.camera_alt : Icons.refresh,
                      size: 20,
                    ),
                    label: Text(
                      _fieldPhoto == null
                          ? l10n.takeFieldPhoto
                          : l10n.retakeFieldPhoto,
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    label: Text(
                      l10n.close,
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenPhoto() {
    if (_fieldPhoto == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: kIsWeb
                    ? Image.network(
                        _fieldPhoto!.path,
                        fit: BoxFit.contain,
                      )
                    : Image.file(
                        File(_fieldPhoto!.path),
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDraftSelectionDialog() async {
    final l10n = AppLocalizations.of(context)!;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.continueOrStartNew,
          style: const TextStyle(color: Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.unfinishedFieldRecordings,
              style: const TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ..._drafts.map((draft) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.crop_square, color: Colors.orange),
                  title: Text(
                    '${draft['pointCount']} ${l10n.points}',
                    style: const TextStyle(color: Colors.black),
                  ),
                  subtitle: Text(
                    DateTime.parse(draft['timestamp'])
                        .toLocal()
                        .toString()
                        .substring(0, 16),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, draft['key']),
                )),
            const Divider(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.add, color: Colors.green),
              title: Text(
                l10n.startNewField,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
              onTap: () => Navigator.pop(context, 'new'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedDraftKey = result == 'new' ? null : result;
      });
    }
  }

  Future<void> _createNewFarm() async {
    // Öffne Registrierungs-Dialog
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StepperRegistrarRegistration(),
      ),
    );

    // Reload farms nach Rückkehr
    if (result != null || mounted) {
      await _loadAvailableFarms();
    }
  }

  Future<void> _takeFieldPhoto() async {
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
          await _saveFieldPhoto(photo);
        }
      }
    } catch (e) {
      debugPrint('Error taking field photo: $e');
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

  Future<void> _saveFieldPhoto(XFile photo) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      debugPrint('Field Photo taken: ${photo.path}');

      // Get current GPS position when photo is taken
      Position? photoPosition;
      try {
        photoPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 10),
          ),
        );
        debugPrint(
            'Photo GPS: ${photoPosition.latitude}, ${photoPosition.longitude}');
      } catch (e) {
        debugPrint('Warning: Could not get GPS position for photo: $e');
      }

      await _saveFieldPhotoWithPosition(photo, photoPosition);
    } catch (e) {
      debugPrint('Error saving field photo: $e');
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

  Future<void> _saveFieldPhotoWithPosition(
      XFile photo, Position? photoPosition) async {
    final l10n = AppLocalizations.of(context)!;

    try {
      debugPrint(
          'Saving field photo with position: ${photoPosition != null ? "${photoPosition.latitude}, ${photoPosition.longitude}" : "no GPS"}');

      // Save photo locally for offline access
      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'field_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final localPath = '${appDir.path}/fieldPhotos/$fileName';

        // Create directory if it doesn't exist
        final directory = Directory('${appDir.path}/fieldPhotos');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        // Copy file to local storage
        final File localFile = File(localPath);
        await localFile.writeAsBytes(await photo.readAsBytes());

        setState(() {
          _fieldPhoto = photo;
          _fieldPhotoLocalPath = localPath;
          _fieldPhotoPosition = photoPosition;
          _isFieldPhotoValid = true; // Reset validation state
        });

        debugPrint('Field Photo saved locally: $localPath');
        if (photoPosition != null) {
          debugPrint(
              'Photo GPS stored: ${photoPosition.latitude}, ${photoPosition.longitude}');
        }
      } else {
        // Web: Just store the XFile (use path which contains the blob URL)
        setState(() {
          _fieldPhoto = photo;
          _fieldPhotoLocalPath = photo.path;
          _fieldPhotoPosition = photoPosition;
          _isFieldPhotoValid = true; // Reset validation state
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.photoTaken),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving field photo: $e');
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

      // Use back camera if available, otherwise use first camera
      final camera_plugin.CameraDescription selectedCamera =
          _cameras!.firstWhere(
        (cam) => cam.lensDirection == camera_plugin.CameraLensDirection.back,
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
                    l10n.takeFieldPhoto,
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
                      child: ValueListenableBuilder<camera_plugin.CameraValue>(
                        valueListenable: _cameraController!,
                        builder: (context, value, child) {
                          if (_cameraController == null ||
                              !_cameraController!.value.isInitialized) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return camera_plugin.CameraPreview(
                              _cameraController!);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            debugPrint('=== CAMERA CAPTURE START ===');
                            final image =
                                await _cameraController!.takePicture();
                            debugPrint('Image captured: ${image.path}');

                            // Capture GPS position BEFORE closing dialog
                            Position? photoPosition;
                            try {
                              debugPrint('Fetching GPS position...');
                              photoPosition =
                                  await Geolocator.getCurrentPosition(
                                locationSettings: const LocationSettings(
                                  accuracy: LocationAccuracy.best,
                                  timeLimit: Duration(seconds: 10),
                                ),
                              );
                              debugPrint(
                                  'Photo GPS captured: ${photoPosition.latitude}, ${photoPosition.longitude}');
                            } catch (e) {
                              debugPrint(
                                  'Warning: Could not get GPS position for photo: $e');
                            }

                            // Dispose camera and close dialog
                            debugPrint('Disposing camera...');
                            await _cameraController?.dispose();
                            _cameraController = null;
                            debugPrint('Camera disposed');

                            if (mounted) {
                              debugPrint('Closing dialog...');
                              Navigator.of(dialogContext).pop();
                            }

                            // Save photo with GPS position AFTER dialog is closed
                            debugPrint('Saving photo... mounted=$mounted');
                            if (mounted) {
                              await _saveFieldPhotoWithPosition(
                                  image, photoPosition);
                              debugPrint('Photo saved successfully');
                            } else {
                              debugPrint(
                                  'ERROR: Widget not mounted, cannot save photo');
                            }
                            debugPrint('=== CAMERA CAPTURE END ===');
                          } catch (e) {
                            debugPrint('ERROR in camera capture: $e');
                            if (mounted) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.camera, size: 20),
                        label: Text(
                          l10n.capture,
                          style: const TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _cameraController?.dispose();
                          _cameraController = null;
                          if (mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        icon: const Icon(Icons.close, size: 20),
                        label: Text(
                          l10n.cancel,
                          style: const TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
      // Cleanup on error
      await _cameraController?.dispose();
      _cameraController = null;
    }
  }

  Future<void> _saveField(
      List<List<double>> polygon, double area, List<double> accuracies) async {
    final l10n = AppLocalizations.of(context)!;

    if (_selectedFarm == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.farmName} must be selected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // PFLICHT: Validate that field photo was taken
    if (_fieldPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.fieldPhotoRequired),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Validate field photo location (only enforce in release mode)
    if (_fieldPhoto != null && _fieldPhotoPosition != null) {
      final isPhotoValid =
          _validateFieldPhotoLocation(polygon, toleranceMeters: 50.0);
      if (!isPhotoValid) {
        setState(() => _isFieldPhotoValid = false);

        if (kDebugMode) {
          // Debug mode: Show warning but allow registration
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'DEBUG: ${l10n.fieldPhotoNotInPolygon} (allowed in debug mode)'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
          debugPrint(
              'DEBUG MODE: Field photo validation failed but registration is allowed');
        } else {
          // Release mode: Block registration
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.fieldPhotoNotInPolygon),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return; // Refuse registration
        }
      }
    }

    setState(() => _isProcessing = true);

    try {
      debugPrint('=== SAVE FIELD START ===');
      final farmUID = _selectedFarm!['identity']['UID'];
      debugPrint('Farm UID: $farmUID');

      // Erstelle Field
      final fieldUID = const Uuid().v4();
      debugPrint('Field UID: $fieldUID');

      Map<String, dynamic> field = await getOpenRALTemplate('field');
      debugPrint('Field template loaded');

      setObjectMethodUID(field, fieldUID);
      debugPrint('Field UID set');

      // Auto-generiere Feldname mit Datum/Uhrzeit
      final now = DateTime.now();
      final fieldName =
          'Field ${now.day}.${now.month}.${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      field['identity']['name'] = fieldName;
      field['objectState'] = 'qcPending';
      debugPrint('Field name: $fieldName');

      // Polygon boundaries speichern (als JSON String für Firestore Kompatibilität)
      debugPrint('Setting boundaries with ${polygon.length} points');
      final boundariesJson = jsonEncode({"coordinates": polygon});
      field = setSpecificPropertyJSON(
          field, 'boundaries', boundariesJson, 'String');
      debugPrint('Boundaries set as JSON String');

      debugPrint('Setting area: $area (type: ${area.runtimeType})');
      field = setSpecificPropertyJSON(field, 'area', area, 'double');
      debugPrint('Area set');

      // GPS Boundary Accuracies speichern (als JSON String für Firestore Kompatibilität)
      debugPrint('Setting boundary accuracies: ${accuracies.length} values');
      final accuraciesJson = jsonEncode(accuracies);
      field = setSpecificPropertyJSON(
          field, 'boundaryAccuracies', accuraciesJson, 'String');
      debugPrint('Boundary accuracies set');

      // Berechne GPS-Qualitätsstatistiken für Logging
      if (accuracies.isNotEmpty) {
        final avgAccuracy =
            accuracies.reduce((a, b) => a + b) / accuracies.length;
        final maxAccuracy = accuracies.reduce((a, b) => a > b ? a : b);
        final minAccuracy = accuracies.reduce((a, b) => a < b ? a : b);
        debugPrint(
            'GPS Quality - Avg: ${avgAccuracy.toStringAsFixed(1)}m, Min: ${minAccuracy.toStringAsFixed(1)}m, Max: ${maxAccuracy.toStringAsFixed(1)}m');

        if (maxAccuracy > 10.0) {
          debugPrint(
              'WARNING: Poor GPS quality detected (max: ${maxAccuracy.toStringAsFixed(1)}m)');
        }
      }

      // PFLICHT-Verknüpfung zur Farm
      debugPrint('Setting geolocation container');
      field['currentGeolocation']['container']['UID'] = farmUID;
      field['linkedObjectRef'].add({
        'UID': farmUID,
        'RALType': 'farm',
        'role': 'location',
      });
      debugPrint('Farm link added');

      // Berechne Centroid für geoCoordinates
      final centroid = _calculateCentroid(polygon);
      debugPrint('Centroid: ${centroid[0]}, ${centroid[1]}');
      field['currentGeolocation']['geoCoordinates'] = {
        'latitude': centroid[0],
        'longitude': centroid[1],
      };
      field['currentGeolocation']['postalAddress']['country'] = 'Honduras';
      debugPrint('Geolocation set');

      // Create image object for Field Photo
      Map<String, dynamic>? fieldImage;
      if (_fieldPhotoLocalPath != null && _fieldPhotoLocalPath!.isNotEmpty) {
        debugPrint('Creating image object for Field photo...');
        fieldImage = await createImageObject(
          localPath: _fieldPhotoLocalPath!,
          position: _fieldPhotoPosition,
          imageName: 'Field Photo - $fieldName',
        );

        // Link image to field
        field['linkedObjectRef'].add({
          'UID': getObjectMethodUID(fieldImage),
          'RALType': 'image',
          'role': 'fieldRegistrationPhoto',
        });
        debugPrint('Field image object created and linked to field');
      } else {
        debugPrint('No field photo to create image object for');
      }

      // Add registrar as currentOwner and in linkedObjectRef
      debugPrint(
          'Adding registrar to field currentOwners and linkedObjectRef...');
      field['currentOwners'] = [
        {"UID": getObjectMethodUID(appUserDoc!), "role": "registrar"}
      ];
      field['linkedObjectRef'].add({
        'UID': getObjectMethodUID(appUserDoc!),
        'RALType': 'user',
        'role': 'registrar',
      });
      debugPrint('Registrar added to field');

//************ Update Farm mit neuem Field-Link ZUERST (bevor Methode erstellt wird) ***
//ToDo: changed Farm needs persistence via changeObject Method!!!
      debugPrint('Updating farm with field link');
      Map<String, dynamic> updatedFarm =
          Map<String, dynamic>.from(_selectedFarm!);
      updatedFarm['linkedObjectRef'].add({
        'UID': fieldUID,
        'RALType': 'field',
        'role': 'parcel', //TODo: Check if correct
      });

      // Aktualisiere totalAreaHa der Farm
      final currentAreaRaw =
          getSpecificPropertyfromJSON(updatedFarm, 'totalAreaHa');
      debugPrint(
          'Current farm area raw: $currentAreaRaw (type: ${currentAreaRaw.runtimeType})');

      // Parse current area - handle "-no data found-" string
      double currentArea = 0.0;
      if (currentAreaRaw != null && currentAreaRaw is num) {
        currentArea = currentAreaRaw.toDouble();
      } else if (currentAreaRaw is String &&
          currentAreaRaw != '-no data found-') {
        currentArea = double.tryParse(currentAreaRaw) ?? 0.0;
      }

      debugPrint('Current farm area parsed: $currentArea, adding: $area');
      final newTotalArea = currentArea + area;
      debugPrint('New total area: $newTotalArea');

      updatedFarm = setSpecificPropertyJSON(
          updatedFarm, 'totalAreaHa', newTotalArea, 'double');
      debugPrint('Farm area updated');

//ToDo: ChangeObject Methode aufrufen um Farm zu speichern

      // Erstelle generateDigitalSibling Methode (EXAKTE SEQUENZ WIE IN STEPPER_FIRST_SALE)
      debugPrint('Creating generateDigitalSibling method for field');
      Map<String, dynamic> fieldRegisterMethod =
          await getOpenRALTemplate('generateDigitalSibling');

      fieldRegisterMethod['identity']['name'] =
          'Field Registration - $fieldName';
      fieldRegisterMethod['methodState'] = 'finished';
      fieldRegisterMethod['executor'] = appUserDoc!;
      fieldRegisterMethod['existenceStarts'] =
          DateTime.now().toUtc().toIso8601String();
      debugPrint('Method properties set');

      //Step 1: get method an uuid (for method history entries)
      setObjectMethodUID(fieldRegisterMethod, const Uuid().v4());
      debugPrint('Method UID set');

      //Step 2: save the objects a first time to get it the method history change
      await setObjectMethod(field, false, false);
      debugPrint('Field saved first time');

      //Step 3: add the output objects with updated method history to the method
      addOutputobject(fieldRegisterMethod, field, 'field');
      debugPrint('Field added to method');

      //Step 4: update method history in all affected objects (will also tag them for syncing)
      await updateMethodHistories(fieldRegisterMethod);
      debugPrint('Method history updated in all objects');

      //Step 5: again add Outputobjects to generate valid representation in the method
      field = await getLocalObjectMethod(getObjectMethodUID(field));
      addOutputobject(fieldRegisterMethod, field, 'field');
      debugPrint('Field re-added to method with updated history');

      //Step 6: persist process
      await setObjectMethod(fieldRegisterMethod, true, true); //sign it!
      debugPrint(
          'Method ${getObjectMethodUID(fieldRegisterMethod)} to register a field saved and signed');

      // Create separate generateDigitalSibling method for Field Image
      if (fieldImage != null) {
        debugPrint(
            'Creating separate generateDigitalSibling method for Field Image');
        Map<String, dynamic> fieldImageMethod =
            await getOpenRALTemplate('generateDigitalSibling');

        fieldImageMethod['identity']['name'] = 'Field Image - $fieldName';
        fieldImageMethod['methodState'] = 'finished';
        fieldImageMethod['executor'] = appUserDoc!;
        fieldImageMethod['existenceStarts'] =
            DateTime.now().toUtc().toIso8601String();

        setObjectMethodUID(fieldImageMethod, const Uuid().v4());
        debugPrint('Field Image Method UID set');

        await setObjectMethod(fieldImage, false, false);
        debugPrint('Field Image saved first time');

        addOutputobject(fieldImageMethod, fieldImage, 'image');
        debugPrint('Field Image added to method');

        await updateMethodHistories(fieldImageMethod);
        debugPrint('Field Image method history updated');

        fieldImage = await getLocalObjectMethod(getObjectMethodUID(fieldImage));
        addOutputobject(fieldImageMethod, fieldImage, 'image');
        debugPrint('Field Image re-added to method with updated history');

        await setObjectMethod(fieldImageMethod, true, true);
        debugPrint(
            'Field Image method ${getObjectMethodUID(fieldImageMethod)} saved and signed successfully');
      }
//**************************************************************** */

      // UI aktualisieren
      repaintContainerList.value = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${l10n.registerField} "$fieldName" ${l10n.registrationSuccessful}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigiere zurück zum Registrar Dashboard
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('Error saving field: $e');
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

  List<double> _calculateCentroid(List<List<double>> polygon) {
    double sumLat = 0.0;
    double sumLon = 0.0;
    for (final point in polygon) {
      sumLat += point[0];
      sumLon += point[1];
    }
    return [sumLat / polygon.length, sumLon / polygon.length];
  }

  /// Check if a point is inside a polygon using ray-casting algorithm
  bool _isPointInPolygon(double lat, double lon, List<List<double>> polygon) {
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      final v1 = polygon[i];
      final v2 = polygon[(i + 1) % polygon.length];

      if (_rayIntersectsSegment(lat, lon, v1[0], v1[1], v2[0], v2[1])) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  bool _rayIntersectsSegment(
      double px, double py, double x1, double y1, double x2, double y2) {
    if (y1 > y2) {
      // Swap points
      final tempX = x1;
      final tempY = y1;
      x1 = x2;
      y1 = y2;
      x2 = tempX;
      y2 = tempY;
    }

    if (py < y1 || py > y2) return false;
    if (px >= (x1 > x2 ? x1 : x2)) return false;

    if (px < (x1 < x2 ? x1 : x2)) return true;

    final slope = (py - y1) / (y2 - y1);
    final x = x1 + slope * (x2 - x1);
    return px < x;
  }

  /// Calculate distance in meters between two GPS coordinates
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Validate if photo was taken within or near the polygon
  bool _validateFieldPhotoLocation(List<List<double>> polygon,
      {double toleranceMeters = 50.0}) {
    if (_fieldPhotoPosition == null) {
      debugPrint('No GPS position for field photo - cannot validate');
      return false; // No GPS = invalid
    }

    final photoLat = _fieldPhotoPosition!.latitude;
    final photoLon = _fieldPhotoPosition!.longitude;

    debugPrint('Validating photo position: $photoLat, $photoLon');
    debugPrint('Polygon has ${polygon.length} points');

    // Check if photo is inside polygon
    if (_isPointInPolygon(photoLat, photoLon, polygon)) {
      debugPrint('Photo is INSIDE polygon - VALID');
      return true;
    }

    // Photo is outside - check if within tolerance distance from polygon edges
    double minDistance = double.infinity;
    for (final point in polygon) {
      final distance =
          _calculateDistance(photoLat, photoLon, point[0], point[1]);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    debugPrint(
        'Photo is outside polygon. Minimum distance: ${minDistance.toStringAsFixed(1)}m (tolerance: ${toleranceMeters}m)');

    if (minDistance <= toleranceMeters) {
      debugPrint('Photo within tolerance - VALID');
      return true;
    }

    debugPrint('Photo too far from polygon - INVALID');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: _selectedFarm != null && !_showFarmSelector
            ? Row(
                children: [
                  const Icon(Icons.agriculture, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedFarm!['identity']['name'] ?? 'Unnamed',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(l10n.recordFieldBoundary),
        actions: [
          if (_selectedFarm != null && !_showFarmSelector) ...[
            // Field Photo Badge
            IconButton(
              icon: Badge(
                backgroundColor: _fieldPhoto == null
                    ? Colors.orange
                    : (_isFieldPhotoValid ? Colors.green : Colors.red),
                label: Icon(
                  _fieldPhoto == null
                      ? Icons.warning_amber
                      : (_isFieldPhotoValid ? Icons.check : Icons.close),
                  size: 12,
                  color: Colors.white,
                ),
                child: const Icon(Icons.photo_camera),
              ),
              tooltip: l10n.fieldPhoto,
              onPressed: _showPhotoDialog,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: l10n.changeFarm,
              onPressed: () {
                setState(() => _showFarmSelector = true);
              },
            ),
          ],
        ],
        elevation: 2,
      ),
      body: _isLoadingFarms
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Farm-Auswahl (PFLICHT) - nur anzeigen wenn keine Farm gewählt oder Selector aktiv
                    if (_selectedFarm == null || _showFarmSelector)
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.agriculture,
                                        color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${l10n.farmName} *',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.fieldMustBeLinkedToFarm,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_availableFarms.isEmpty)
                                  Column(
                                    children: [
                                      Text(
                                        l10n.noFarmsRegisteredYet,
                                        style:
                                            TextStyle(color: Colors.grey[700]),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: _createNewFarm,
                                        icon: const Icon(Icons.add),
                                        label: Text(l10n.registerFarm),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      DropdownButtonFormField<
                                          Map<String, dynamic>>(
                                        value: _selectedFarm,
                                        decoration: InputDecoration(
                                          labelText: l10n.farmName,
                                          border: const OutlineInputBorder(),
                                          prefixIcon:
                                              const Icon(Icons.home_work),
                                        ),
                                        items: _availableFarms.map((farm) {
                                          final name = farm['identity']
                                                  ['name'] ??
                                              'Unnamed';
                                          // Suche Farm-ID in alternateIDs (vom Benutzer eingegeben)
                                          String farmId = '';
                                          final alternateIDs = farm['identity']
                                              ?['alternateIDs'] as List?;
                                          if (alternateIDs != null) {
                                            for (var altId in alternateIDs) {
                                              if (altId['issuedBy'] ==
                                                  'Farm Registry') {
                                                farmId = altId['UID'] ?? '';
                                                break;
                                              }
                                            }
                                          }
                                          final city =
                                              farm['currentGeolocation']
                                                          ?['postalAddress']
                                                      ?['cityName'] ??
                                                  '';
                                          // E-Mail aus specificProperties holen (wie im Registrierungsstepper gespeichert)
                                          final emailFromSpecific =
                                              getSpecificPropertyfromJSON(
                                                  farm, 'email');
                                          final email =
                                              (emailFromSpecific != null &&
                                                      emailFromSpecific !=
                                                          '-no data found-')
                                                  ? emailFromSpecific.toString()
                                                  : '';

                                          return DropdownMenuItem(
                                            value: farm,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                                if (farmId.isNotEmpty ||
                                                    city.isNotEmpty ||
                                                    email.isNotEmpty)
                                                  Text(
                                                    [
                                                      if (farmId.isNotEmpty)
                                                        farmId.length > 12
                                                            ? '${farmId.substring(0, 12)}...'
                                                            : farmId,
                                                      if (city.isNotEmpty) city,
                                                      if (email.isNotEmpty)
                                                        email,
                                                    ]
                                                        .where(
                                                            (s) => s.isNotEmpty)
                                                        .join(' • '),
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 11,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (farm) async {
                                          setState(() {
                                            _selectedFarm = farm;
                                            if (farm != null) {
                                              _showFarmSelector = false;
                                            }
                                          });
                                          // Lade Drafts für ausgewählte Farm
                                          await _loadDraftsForFarm(
                                              farm?['identity']?['UID']);
                                          // Zeige Draft-Auswahl wenn welche vorhanden
                                          if (_drafts.isNotEmpty && mounted) {
                                            await _showDraftSelectionDialog();
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: _createNewFarm,
                                          icon: const Icon(Icons.add),
                                          label: Text(l10n.registerFarm),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Polygon Recorder - nimmt verfügbaren Platz ein mit Warning Banner
                    if (_selectedFarm != null && !_showFarmSelector)
                      Expanded(
                        child: Stack(
                          children: [
                            PolygonRecorderWidget(
                              key: ValueKey(_selectedDraftKey ?? 'new'),
                              onPolygonComplete: _saveField,
                              minDistanceMeters: 10,
                              farmId: _selectedFarm?['identity']?['UID'],
                              draftKey: _selectedDraftKey,
                              onCancel: () {},
                            ),
                            // Warning Banner für ungültiges Foto
                            if (_fieldPhoto != null && !_isFieldPhotoValid)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Material(
                                  color: Colors.red.shade700,
                                  elevation: 4,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            l10n.fieldPhotoNotInPolygon,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            setState(() =>
                                                _isFieldPhotoValid = true);
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
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
    );
  }
}
