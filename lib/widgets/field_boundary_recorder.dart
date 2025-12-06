import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAvailableFarms();
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

            // Prüfe ob es eine Farm ist
            if (obj['template']?['RALType'] == 'farm') {
              farms.add(obj);
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

  Future<void> _saveField(List<List<double>> polygon, double area) async {
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

    setState(() => _isProcessing = true);

    try {
      final farmUID = _selectedFarm!['identity']['UID'];

      // Erstelle Field
      final fieldUID = const Uuid().v4();
      Map<String, dynamic> field = await getOpenRALTemplate('field');
      setObjectMethodUID(field, fieldUID);
      // Auto-generiere Feldname mit Datum/Uhrzeit
      final now = DateTime.now();
      final fieldName =
          'Field ${now.day}.${now.month}.${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      field['identity']['name'] = fieldName;
      field['objectState'] = 'qcPending';

      // Polygon boundaries
      field =
          setSpecificPropertyJSON(field, 'boundaries', polygon, 'vector_list');
      field = setSpecificPropertyJSON(field, 'area', area, 'double');

      // Recorded by
      if (appUserDoc != null) {
        field = setSpecificPropertyJSON(
            field, 'recordedBy', getObjectMethodUID(appUserDoc!), 'String');
      }

      // PFLICHT-Verknüpfung zur Farm
      field['currentGeolocation']['container']['UID'] = farmUID;
      field['linkedObjectRef'].add({
        'UID': farmUID,
        'RALType': 'farm',
        'role': 'location',
      });

      // Berechne Centroid für geoCoordinates
      final centroid = _calculateCentroid(polygon);
      field['currentGeolocation']['geoCoordinates'] = {
        'latitude': centroid[0],
        'longitude': centroid[1],
      };
      field['currentGeolocation']['postalAddress']['country'] = 'Honduras';

      // Erstelle generateDigitalSibling Methode
      Map<String, dynamic> registerMethod =
          await getOpenRALTemplate('generateDigitalSibling');
      final methodUID = const Uuid().v4();
      setObjectMethodUID(registerMethod, methodUID);
      registerMethod['identity']['name'] = 'Field Registration - $fieldName';
      registerMethod['methodState'] = 'finished';
      registerMethod['executor'] = appUserDoc!;
      registerMethod['existenceStarts'] =
          DateTime.now().toUtc().toIso8601String();

      // Input: Farm (Kontext)
      addInputobject(registerMethod, _selectedFarm!, 'farm');

      // Output: Field
      addOutputobject(registerMethod, field, 'field');

      // Update method history
      field['methodHistoryRef'].add({
        'UID': methodUID,
        'RALType': 'generateDigitalSibling',
      });

      // Update Farm mit neuem Field-Link
      Map<String, dynamic> updatedFarm =
          Map<String, dynamic>.from(_selectedFarm!);
      updatedFarm['linkedObjectRef'].add({
        'UID': fieldUID,
        'RALType': 'field',
        'role': 'parcel',
      });

      // Aktualisiere totalAreaHa der Farm
      final currentArea =
          getSpecificPropertyfromJSON(updatedFarm, 'totalAreaHa') ?? 0.0;
      updatedFarm = setSpecificPropertyJSON(
          updatedFarm, 'totalAreaHa', currentArea + area, 'double');

      // Speichere Objekte
      field = jsonFullDoubleToInt(sortJsonAlphabetically(field));
      await setObjectMethod(field, false, false);

      updatedFarm = jsonFullDoubleToInt(sortJsonAlphabetically(updatedFarm));
      await setObjectMethod(updatedFarm, false, false);

      registerMethod =
          jsonFullDoubleToInt(sortJsonAlphabetically(registerMethod));
      await setObjectMethod(registerMethod, true, true); // Signieren und syncen

      // UI aktualisieren
      repaintContainerList.value = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${l10n.registerField} "$fieldName" ${l10n.registrationSuccessful}'),
            backgroundColor: Colors.green,
          ),
        );
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

  @override
  void dispose() {
    super.dispose();
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
          if (_selectedFarm != null && !_showFarmSelector)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: l10n.changeFarm,
              onPressed: () {
                setState(() => _showFarmSelector = true);
              },
            ),
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
                                          final city =
                                              farm['currentGeolocation']
                                                          ?['postalAddress']
                                                      ?['cityName'] ??
                                                  '';
                                          return DropdownMenuItem(
                                            value: farm,
                                            child: Text(
                                              '$name ${city.isNotEmpty ? "($city)" : ""}',
                                              style: const TextStyle(
                                                  color: Colors.black),
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

                    // Polygon Recorder - nimmt verfügbaren Platz ein
                    if (_selectedFarm != null)
                      Expanded(
                        child: PolygonRecorderWidget(
                          key: ValueKey(_selectedDraftKey ?? 'new'),
                          onPolygonComplete: _saveField,
                          minDistanceMeters: 10,
                          farmId: _selectedFarm?['identity']?['UID'],
                          draftKey: _selectedDraftKey,
                          onCancel: () {
                            // Optional: Navigiere zurück oder zeige Meldung
                          },
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
