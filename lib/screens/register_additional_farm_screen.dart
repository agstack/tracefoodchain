import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../helpers/json_full_double_to_int.dart';
import '../helpers/sort_json_alphabetically.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../repositories/honduras_specifics.dart';
import '../services/open_ral_service.dart';
import '../services/service_functions.dart';

class RegisterAdditionalFarmScreen extends StatefulWidget {
  const RegisterAdditionalFarmScreen({
    super.key,
    required this.farmerDoc,
  });

  final Map<String, dynamic> farmerDoc;

  @override
  State<RegisterAdditionalFarmScreen> createState() =>
      _RegisterAdditionalFarmScreenState();
}

class _RegisterAdditionalFarmScreenState
    extends State<RegisterAdditionalFarmScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _farmIDController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _estimatedAreaController =
      TextEditingController();

  String _selectedAreaUnit = 'ha';
  bool _isSaving = false;

  @override
  void dispose() {
    _farmNameController.dispose();
    _farmIDController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _emailController.dispose();
    _estimatedAreaController.dispose();
    super.dispose();
  }

  Future<void> _saveFarm() async {
    final l10n = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!isLocalStorageInitialized()) {
      await fshowInfoDialog(context, l10n.errorLoadingUserData);
      return;
    }

    setState(() => _isSaving = true);

    try {
      Position? currentPosition;
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          await Geolocator.requestPermission();
        }
        currentPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
          ),
        );
      } catch (_) {
        currentPosition = null;
      }

      final farmUID = const Uuid().v4();
      Map<String, dynamic> farm = await getOpenRALTemplate('farm');
      setObjectMethodUID(farm, farmUID);

      farm['identity']['name'] = _farmNameController.text.trim();
      farm['objectState'] = 'qcPending';

      if (_farmIDController.text.trim().isNotEmpty) {
        farm['identity']['alternateIDs'].add({
          'UID': _farmIDController.text.trim(),
          'issuedBy': 'Farm Registry',
        });
      }

      final farmerUID = widget.farmerDoc['identity']?['UID']?.toString();
      if (farmerUID != null && farmerUID.isNotEmpty) {
        farm['linkedObjectRef'].add({
          'UID': farmerUID,
          'RALType': 'human',
          'role': 'owner',
        });
      }

      if (currentPosition != null) {
        farm['currentGeolocation']['geoCoordinates'] = {
          'latitude': currentPosition.latitude,
          'longitude': currentPosition.longitude,
        };
      }

      farm['currentGeolocation']['postalAddress']['country'] = 'Honduras';
      if (_cityController.text.trim().isNotEmpty) {
        farm['currentGeolocation']['postalAddress']['cityName'] =
            _cityController.text.trim();
      }
      if (_stateController.text.trim().isNotEmpty) {
        farm['currentGeolocation']['postalAddress']['stateName'] =
            _stateController.text.trim();
      }

      farm = setSpecificPropertyJSON(farm, 'farmerCount', 1, 'int');

      final areaText =
          _estimatedAreaController.text.trim().replaceAll(',', '.');
      if (areaText.isNotEmpty) {
        final areaRaw = double.tryParse(areaText);
        if (areaRaw != null) {
          final unitData = areaUnitsHonduras.firstWhere(
            (u) => u['symbol'] == _selectedAreaUnit,
            orElse: () => areaUnitsHonduras.first,
          );
          final factor = (unitData['toHectareFactor'] as num).toDouble();
          final areaHa = areaRaw * factor;
          farm = setSpecificPropertyJSON(
              farm, 'totalAreaEstimatedHa', areaHa, 'double');
        }
      }

      if (_emailController.text.trim().isNotEmpty) {
        farm = setSpecificPropertyJSON(
            farm, 'email', _emailController.text.trim(), 'String');
      }

      if (appUserDoc != null) {
        farm['currentOwners'] = [
          {'UID': getObjectMethodUID(appUserDoc!), 'role': 'registrar'}
        ];
        farm['linkedObjectRef'].add({
          'UID': getObjectMethodUID(appUserDoc!),
          'RALType': 'human',
          'role': 'registrar',
        });
      }

      final processedFarm = jsonFullDoubleToInt(sortJsonAlphabetically(farm))
          as Map<String, dynamic>;
      await generateDigitalSibling(processedFarm);

      if (mounted) {
        await fshowInfoDialog(context, l10n.registrationSuccessful);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        await fshowInfoDialog(context, '${l10n.registrationFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final firstName = getSpecificPropertyfromJSON(widget.farmerDoc, 'firstName')
            ?.toString() ??
        '';
    final lastName =
        getSpecificPropertyfromJSON(widget.farmerDoc, 'lastName')?.toString() ??
            '';
    final farmerName = '$firstName $lastName'.trim().isNotEmpty
        ? '$firstName $lastName'.trim()
        : (widget.farmerDoc['identity']?['name']?.toString() ?? '');

    final units = getAreaUnits(country);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.registerAdditionalFarm,
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${l10n.farmer}: ${farmerName.isEmpty ? l10n.unknown : farmerName}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _farmNameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: l10n.farmName,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.farmNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _farmIDController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: l10n.farmID,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cityController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: l10n.cityName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _stateController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: l10n.stateName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.black),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _estimatedAreaController,
                        style: const TextStyle(color: Colors.black),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: l10n.totalArea,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedAreaUnit,
                      items: units
                          .map(
                            (u) => DropdownMenuItem<String>(
                              value: u['symbol'] as String,
                              child: Text(
                                u['symbol'] as String,
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedAreaUnit = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveFarm,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? l10n.saving : l10n.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
