import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../l10n/app_localizations.dart';
import '../services/firebase_storage_service.dart';
import '../services/object_correction_service.dart';

/// Ergebnis des Korrekturdialogs: nur die geänderten Werte, die neu gewählten
/// Fotos je Rolle und der Grund.
class QcCorrectionResult {
  const QcCorrectionResult({
    required this.values,
    required this.photos,
    required this.reason,
  });

  final Map<String, String> values;
  final Map<String, XFile> photos;
  final String reason;
}

/// Korrektur der Daten eines Farmers, einer Farm oder eines Feldes im QC.
///
/// Gespeichert wird erst mit Grund und mindestens einer Änderung; der Aufrufer
/// schreibt das Ergebnis über [saveObjectCorrection].
class QcCorrectionDialog extends StatefulWidget {
  const QcCorrectionDialog({
    super.key,
    required this.object,
    required this.linkedPhotoRoles,
  });

  final Map<String, dynamic> object;

  /// Fotorollen, für die das Objekt bereits ein Foto verknüpft hat.
  final Set<String> linkedPhotoRoles;

  @override
  State<QcCorrectionDialog> createState() => _QcCorrectionDialogState();
}

class _QcCorrectionDialogState extends State<QcCorrectionDialog> {
  late final String _ralType =
      widget.object['template']?['RALType']?.toString() ?? '';
  late final List<String> _fields = correctableFields[_ralType] ?? const [];
  late final List<String> _photoRoles = photoRolesByType[_ralType] ?? const [];

  late final Map<String, String> _original = {
    for (final key in _fields) key: readCorrectableValue(widget.object, key),
  };
  late final Map<String, TextEditingController> _controllers = {
    for (final key in _fields) key: TextEditingController(text: _original[key]),
  };
  final TextEditingController _reason = TextEditingController();

  final Map<String, XFile> _photos = {};
  final Map<String, Uint8List> _previews = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  Map<String, String> get _changedValues => {
        for (final key in _fields)
          if (_controllers[key]!.text.trim() != _original[key]!.trim())
            key: _controllers[key]!.text.trim(),
      };

  bool get _canSave =>
      _reason.text.trim().isNotEmpty &&
      (_changedValues.isNotEmpty || _photos.isNotEmpty);

  String _fieldLabel(String key, AppLocalizations l10n) => switch (key) {
        'firstName' => l10n.firstName,
        'lastName' => l10n.lastName,
        'nationalID' => l10n.nationalID,
        'phoneNumber' => l10n.phoneNumber,
        'farmName' => l10n.farmName,
        'farmID' => l10n.farmID,
        'stateName' => l10n.stateName,
        'municipalityName' => l10n.municipalityName,
        'cityName' => l10n.cityName,
        'fieldName' => l10n.fieldName,
        _ => key,
      };

  String _photoLabel(String role, AppLocalizations l10n) => switch (role) {
        'nationalIDPhoto' => l10n.nationalIDPhoto,
        'consentFormPhoto' => l10n.consentFormPhoto,
        'consentFormPhoto2' => l10n.consentFormPhoto2,
        'fieldRegistrationPhoto' => l10n.fieldPhoto,
        _ => role,
      };

  Future<void> _pickPhoto(String role) async {
    final file = await FirebaseStorageService.showImageSourceDialog(context);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photos[role] = file;
      _previews[role] = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.object['identity']?['name']?.toString() ?? '';

    // Kann über einer Google-Map liegen (Web) - siehe PointerInterceptor im QC.
    return PointerInterceptor(
      child: AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          l10n.qcCorrectionTitle(name),
          style: const TextStyle(color: Colors.black),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.qcCorrectionInfo,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(height: 16),
                for (final key in _fields) ...[
                  TextField(
                    controller: _controllers[key],
                    style: const TextStyle(color: Colors.black),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _fieldLabel(key, l10n),
                      labelStyle: const TextStyle(color: Colors.black87),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      // Geänderte Felder sichtbar machen, samt altem Wert.
                      helperText: _changedValues.containsKey(key)
                          ? l10n.qcCorrectionPreviousValue(
                              _original[key]!.isEmpty ? '-' : _original[key]!)
                          : null,
                      helperStyle: TextStyle(color: Colors.orange[900]),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_photoRoles.isNotEmpty) ...[
                  const Divider(height: 24),
                  for (final role in _photoRoles) _buildPhotoRow(role, l10n),
                ],
                const Divider(height: 24),
                TextField(
                  controller: _reason,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.black),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.qcCorrectionReason,
                    hintText: l10n.qcCorrectionReasonHint,
                    labelStyle: const TextStyle(color: Colors.black87),
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: _canSave
                ? () => Navigator.pop(
                      context,
                      QcCorrectionResult(
                        values: _changedValues,
                        photos: Map.of(_photos),
                        reason: _reason.text.trim(),
                      ),
                    )
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoRow(String role, AppLocalizations l10n) {
    final linked = widget.linkedPhotoRoles.contains(role);
    final picked = _photos.containsKey(role);
    final missingRequired = !linked && requiredPhotoRoles.contains(role);

    final (String status, Color color) = picked
        ? (l10n.qcPhotoSelected, Colors.green[800]!)
        : linked
            ? (l10n.qcPhotoOnRecord, Colors.black54)
            : (l10n.qcPhotoNotOnRecord,
                missingRequired ? Colors.red[700]! : Colors.black54);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (_previews[role] case final bytes?)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(bytes,
                    width: 48, height: 48, fit: BoxFit.cover),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_photoLabel(role, l10n),
                    style: const TextStyle(color: Colors.black)),
                Text(status, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _pickPhoto(role),
            icon: Icon(linked || picked ? Icons.swap_horiz : Icons.upload,
                size: 18),
            label: Text(linked || picked ? l10n.qcPhotoReplace : l10n.qcPhotoUpload),
          ),
        ],
      ),
    );
  }
}
