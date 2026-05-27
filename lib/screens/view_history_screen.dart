import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../helpers/json_full_double_to_int.dart';
import '../helpers/sort_json_alphabetically.dart';
import '../l10n/app_localizations.dart';
import '../services/firebase_storage_service.dart';
import '../services/open_ral_service.dart';
import '../services/service_functions.dart';
import '../utils/file_download.dart';
import '../helpers/field_download_helper.dart';
import '../screens/register_additional_farm_screen.dart';
import '../widgets/field_boundary_recorder.dart';
import '../main.dart';

class ViewHistoryScreen extends StatefulWidget {
  const ViewHistoryScreen({super.key});

  @override
  State<ViewHistoryScreen> createState() => _ViewHistoryScreenState();
}

class _ViewHistoryScreenState extends State<ViewHistoryScreen> {
  List<Map<String, dynamic>> _registrations = [];
  bool _isLoading = true;
  String _filterType = 'all'; // 'all', 'farm', 'human', 'field'

  @override
  void initState() {
    super.initState();
    _loadRegistrations();
  }

  Future<void> _loadRegistrations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final registrations = <Map<String, dynamic>>[];
      final currentAppUserUid = appUserDoc?['identity']?['UID']?.toString();

      if (!isLocalStorageInitialized()) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Durchsuche alle Einträge in localStorage
      for (var key in localStorage!.keys) {
        try {
          final value = localStorage!.get(key);
          if (value is Map) {
            final doc = Map<String, dynamic>.from(value);

            // Prüfe ob es ein registriertes Objekt ist (farm, human, field)
            final objectType = doc['template']["RALType"]?.toString();
            if (objectType == null) continue;

            // Hide the app user's own human profile from registrar history.
            final objectUid = doc['identity']?['UID']?.toString();
            if (objectType == 'human' &&
                currentAppUserUid != null &&
                objectUid == currentAppUserUid) {
              continue;
            }

            // Zeige Objekte mit verschiedenen Status an
            final status = doc['objectState']?.toString();
            if (status != 'active' &&
                status != 'qcPending' &&
                status != 'qcRejected') continue;

            // Extrahiere relevante Informationen
            String displayName = '';
            String objectTypeLabel = '';
            String? idNumber;

            if (objectType == 'farm') {
              objectTypeLabel = 'farm';
              displayName = doc['identity']?['name']?.toString() ??
                  getSpecificPropertyfromJSON(doc, 'farmName') ??
                  'Unnamed Farm';
              // Farm ID ist in identity.alternateIDs gespeichert
              final alternateIDs = doc['identity']?['alternateIDs'] as List?;
              if (alternateIDs != null) {
                for (var altId in alternateIDs) {
                  if (altId['issuedBy'] == 'Farm Registry') {
                    idNumber = altId['UID']?.toString();
                    break;
                  }
                }
              }
            } else if (objectType == 'human') {
              objectTypeLabel = 'farmer';
              final firstName =
                  getSpecificPropertyfromJSON(doc, 'firstName') ?? '';
              final lastName =
                  getSpecificPropertyfromJSON(doc, 'lastName') ?? '';
              displayName = '$firstName $lastName'.trim();
              if (displayName.isEmpty) displayName = 'Unnamed Farmer';
              // National ID ist in identity.alternateIDs gespeichert
              final alternateIDs = doc['identity']?['alternateIDs'] as List?;
              if (alternateIDs != null) {
                for (var altId in alternateIDs) {
                  if (altId['issuedBy'] == 'National ID') {
                    idNumber = altId['UID']?.toString();
                    break;
                  }
                }
              }
            } else if (objectType == 'field' || objectType == 'plot') {
              objectTypeLabel = 'field';
              displayName = doc['identity']?['name']?.toString() ??
                  getSpecificPropertyfromJSON(doc, 'fieldName') ??
                  'Unnamed Field';
            } else {
              continue; // Überspringe andere Objekttypen
            }

            // Hole Registrierungsdatum aus methodHistoryRef
            DateTime? registrationDate;
            final methodHistoryRef = doc['methodHistoryRef'] as List?;
            if (methodHistoryRef != null && methodHistoryRef.isNotEmpty) {
              // Nimm die erste Methode (UID)
              final firstMethodUid = methodHistoryRef.first?["UID"]?.toString();
              if (firstMethodUid != null) {
                // Versuche die Methode aus localStorage zu laden
                final methodDoc = localStorage!.get(firstMethodUid);
                if (methodDoc != null && methodDoc is Map) {
                  final existenceStarts =
                      methodDoc['existenceStarts']?.toString();
                  if (existenceStarts != null) {
                    try {
                      registrationDate = DateTime.parse(existenceStarts);
                    } catch (e) {
                      debugPrint('Error parsing existenceStarts: $e');
                    }
                  }
                }
              }
            }

            // Überspringe Einträge ohne gültiges Registrierungsdatum
            if (registrationDate == null) continue;

            final registrationUid = objectUid ?? doc['UID']?.toString() ?? '';
            if (registrationUid.isEmpty) continue;

            registrations.add({
              'uid': registrationUid,
              'displayName': displayName,
              'objectType': objectTypeLabel,
              'status': status,
              'registrationDate': registrationDate,
              'idNumber': idNumber,
              'rawData': doc,
            });
          }
        } catch (e) {
          // Überspringe fehlerhafte Einträge
          continue;
        }
      }

      // Sortiere chronologisch (neueste zuerst)
      registrations.sort((a, b) {
        final dateA = a['registrationDate'] as DateTime;
        final dateB = b['registrationDate'] as DateTime;
        return dateB.compareTo(dateA); // Neueste zuerst
      });

      setState(() {
        _registrations = registrations;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading registrations: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredRegistrations {
    if (_filterType == 'all') return _registrations;
    return _registrations
        .where((reg) => reg['objectType'] == _filterType)
        .toList();
  }

  List<Map<String, String>> _getLinkedFarmsForFarmer(
      Map<String, dynamic> farmerDoc) {
    final farmerUid = farmerDoc['identity']?['UID']?.toString();
    if (farmerUid == null || farmerUid.isEmpty) return [];

    final linkedFarms = <Map<String, String>>[];
    final seenFarmUids = <String>{};

    for (final registration in _registrations) {
      if (registration['objectType'] != 'farm') continue;

      final rawData = registration['rawData'] as Map<String, dynamic>?;
      if (rawData == null) continue;

      final farmUid = rawData['identity']?['UID']?.toString();
      if (farmUid == null ||
          farmUid.isEmpty ||
          seenFarmUids.contains(farmUid)) {
        continue;
      }

      final linkedObjectRef = rawData['linkedObjectRef'] as List?;
      if (linkedObjectRef == null) continue;

      final isLinked = linkedObjectRef.any((ref) {
        if (ref is! Map) return false;
        final uid = ref['UID']?.toString();
        final role = ref['role']?.toString();
        return uid == farmerUid && role == 'owner';
      });

      if (!isLinked) continue;

      final farmName = rawData['identity']?['name']?.toString();
      linkedFarms.add({
        'name': (farmName == null || farmName.trim().isEmpty)
            ? 'Unnamed Farm'
            : farmName,
        'uid': farmUid,
      });
      seenFarmUids.add(farmUid);
    }

    linkedFarms.sort((a, b) => (a['name'] ?? '')
        .toLowerCase()
        .compareTo((b['name'] ?? '').toLowerCase()));
    return linkedFarms;
  }

  List<Map<String, String>> _getLinkedFieldsForFarm(
      Map<String, dynamic> farmDoc) {
    final farmUid = farmDoc['identity']?['UID']?.toString();
    if (farmUid == null || farmUid.isEmpty) return [];

    final linkedFields = <Map<String, String>>[];
    final seenFieldUids = <String>{};

    for (final registration in _registrations) {
      if (registration['objectType'] != 'field') continue;

      final rawData = registration['rawData'] as Map<String, dynamic>?;
      if (rawData == null) continue;

      final fieldUid = rawData['identity']?['UID']?.toString();
      if (fieldUid == null ||
          fieldUid.isEmpty ||
          seenFieldUids.contains(fieldUid)) {
        continue;
      }

      final containerUid =
          rawData['currentGeolocation']?['container']?['UID']?.toString();

      bool isLinked = containerUid == farmUid;
      if (!isLinked) {
        final linkedObjectRef = rawData['linkedObjectRef'] as List?;
        if (linkedObjectRef != null) {
          isLinked = linkedObjectRef.any((ref) {
            if (ref is! Map) return false;
            final uid = ref['UID']?.toString();
            final ralType = ref['RALType']?.toString();
            return uid == farmUid && ralType == 'farm';
          });
        }
      }

      if (!isLinked) continue;

      final fieldName = rawData['identity']?['name']?.toString();
      linkedFields.add({
        'name': (fieldName == null || fieldName.trim().isEmpty)
            ? 'Unnamed Field'
            : fieldName,
        'uid': fieldUid,
      });
      seenFieldUids.add(fieldUid);
    }

    linkedFields.sort((a, b) => (a['name'] ?? '')
        .toLowerCase()
        .compareTo((b['name'] ?? '').toLowerCase()));
    return linkedFields;
  }

  Widget _buildRelationshipSection({
    required String title,
    required IconData icon,
    required List<Map<String, String>> entries,
    required String emptyMessage,
    required String uidLabel,
    required void Function(String uid) onEntryTap,
  }) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: Icon(icon, size: 20, color: Colors.blueGrey[700]),
      title: Text(
        '$title (${entries.length})',
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      children: entries.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  emptyMessage,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ),
            ]
          : entries
              .map(
                (entry) => ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  onTap: () {
                    final uid = entry['uid']?.trim();
                    if (uid != null && uid.isNotEmpty) {
                      onEntryTap(uid);
                    }
                  },
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  title: Text(
                    entry['name'] ?? '',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '$uidLabel: ${entry['uid'] ?? ''}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 11,
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  String _formatDate(DateTime date) {
    return " " + DateFormat('dd.MM.yyyy HH:mm').format(date);
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'qcPending':
        return Colors.orange;
      case 'qcRejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'farm':
        return Icons.agriculture;
      case 'farmer':
        return Icons.person;
      case 'field':
        return Icons.map;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.registrationHistory,
            style: const TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRegistrations,
            tooltip: l10n.retry,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(l10n.all, 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip(l10n.farms, 'farm'),
                  const SizedBox(width: 8),
                  _buildFilterChip(l10n.farmers, 'farmer'),
                  const SizedBox(width: 8),
                  _buildFilterChip(l10n.fields, 'field'),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRegistrations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.noRegistrationsFound,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRegistrations,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredRegistrations.length,
                          itemBuilder: (context, index) {
                            final registration = _filteredRegistrations[index];
                            return _buildRegistrationCard(registration, l10n);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = value;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildRegistrationCard(
      Map<String, dynamic> registration, AppLocalizations l10n) {
    final objectType = registration['objectType'] as String;
    final displayName = registration['displayName'] as String;
    final status = registration['status'] as String?;
    final registrationDate = registration['registrationDate'] as DateTime;

    String typeLabel;
    switch (objectType) {
      case 'farm':
        typeLabel = l10n.farm;
        break;
      case 'farmer':
        typeLabel = l10n.farmer;
        break;
      case 'field':
        typeLabel = l10n.field;
        break;
      default:
        typeLabel = objectType;
    }

    final rawData = registration['rawData'] as Map<String, dynamic>;
    final linkedFarms = objectType == 'farmer'
        ? _getLinkedFarmsForFarmer(rawData)
        : const <Map<String, String>>[];
    final linkedFields = objectType == 'farm'
        ? _getLinkedFieldsForFarm(rawData)
        : const <Map<String, String>>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Optional: Navigation zu Detail-Screen
          _showRegistrationDetails(registration, l10n);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header mit Icon und Name
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTypeIcon(objectType),
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (registration['idNumber'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${registration['idNumber']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getStatusColor(status),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      status ?? 'UNKNOWN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Registrierungsinformationen
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    l10n.registeredOn(_formatDate(
                        registration['registrationDate'] as DateTime)),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    _formatDate(registrationDate),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),

              if (objectType == 'farmer') ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                _buildRelationshipSection(
                  title: l10n.farms,
                  icon: Icons.agriculture,
                  entries: linkedFarms,
                  emptyMessage: l10n.noFarmsRegisteredYet,
                  uidLabel: l10n.uid,
                  onEntryTap: (uid) =>
                      _showLinkedRegistrationDetails(uid, l10n),
                ),
              ],

              if (objectType == 'farm') ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                _buildRelationshipSection(
                  title: l10n.fields,
                  icon: Icons.map,
                  entries: linkedFields,
                  emptyMessage: l10n.noRegistrationsFound,
                  uidLabel: l10n.uid,
                  onEntryTap: (uid) =>
                      _showLinkedRegistrationDetails(uid, l10n),
                ),
              ],

              // Download-Aktionen nur für Felder
              if (objectType == 'field') ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        final rawData =
                            registration['rawData'] as Map<String, dynamic>;
                        final boundariesRaw =
                            getSpecificPropertyfromJSON(rawData, 'boundaries');
                        final area =
                            getSpecificPropertyfromJSON(rawData, 'area')
                                    ?.toString() ??
                                '';
                        FieldDownloadHelper.downloadGeoJSON(
                          context,
                          name:
                              registration['displayName'] as String? ?? 'field',
                          boundariesJson: boundariesRaw?.toString(),
                          l10n: l10n,
                          area: area,
                        );
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label:
                          const Text('GeoJSON', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () {
                        final rawData =
                            registration['rawData'] as Map<String, dynamic>;
                        final boundariesRaw =
                            getSpecificPropertyfromJSON(rawData, 'boundaries');
                        final area =
                            getSpecificPropertyfromJSON(rawData, 'area')
                                    ?.toString() ??
                                '';
                        FieldDownloadHelper.downloadKML(
                          context,
                          name:
                              registration['displayName'] as String? ?? 'Field',
                          boundariesJson: boundariesRaw?.toString(),
                          l10n: l10n,
                          area: area,
                        );
                      },
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('KML', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange[700],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],

              // Edit-Schaltfläche für Farm/Farmer innerhalb der 24h-Frist
              if (objectType == 'farmer') ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _openAdditionalFarmRegistration(
                        registration['rawData']),
                    icon: const Icon(Icons.agriculture, size: 16),
                    label: Text(
                      l10n.addFarmToFarmer,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green[700],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],

              if (objectType == 'farm') ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        _openFieldRegistrationForFarm(registration['rawData']),
                    icon: const Icon(Icons.add_location_alt, size: 16),
                    label: Text(
                      l10n.addFieldToFarm,
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.teal[700],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],

              if ((objectType == 'farm' || objectType == 'farmer') &&
                  _isWithin24Hours(registration)) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.within24hEdit(_hoursRemaining(registration)),
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showEditDialog(registration, l10n),
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(l10n.editEntry,
                            style: const TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAdditionalFarmRegistration(
      Map<String, dynamic> farmerDoc) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => RegisterAdditionalFarmScreen(
          farmerDoc: Map<String, dynamic>.from(farmerDoc),
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadRegistrations();
    }
  }

  Future<void> _openFieldRegistrationForFarm(
      Map<String, dynamic> farmDoc) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FieldBoundaryRecorder(
          initialFarm: Map<String, dynamic>.from(farmDoc),
        ),
      ),
    );

    if (mounted) {
      await _loadRegistrations();
    }
  }

  void _showLinkedRegistrationDetails(String uid, AppLocalizations l10n) {
    final linkedRegistration = _registrations
        .where((registration) {
          final regUid = registration['uid']?.toString();
          if (regUid == uid) return true;

          final rawData = registration['rawData'] as Map<String, dynamic>?;
          final identityUid = rawData?['identity']?['UID']?.toString();
          final rootUid = rawData?['UID']?.toString();
          return identityUid == uid || rootUid == uid;
        })
        .cast<Map<String, dynamic>>()
        .firstOrNull;

    if (linkedRegistration == null) return;
    _showRegistrationDetails(linkedRegistration, l10n);
  }

  void _showRegistrationDetails(
      Map<String, dynamic> registration, AppLocalizations l10n) {
    final rawData = registration['rawData'] as Map<String, dynamic>;
    final uid = registration['uid'] as String?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          registration['displayName'] as String,
          style: const TextStyle(color: Colors.black),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(l10n.type, registration['objectType']),
              _buildDetailRow(l10n.status, registration['status']),
              _buildDetailRow('UID', uid ?? 'N/A'),
              _buildDetailRow(
                l10n.registeredOn(
                    _formatDate(registration['registrationDate'] as DateTime)),
                _formatDate(registration['registrationDate'] as DateTime),
              ),

              // Zusätzliche Informationen basierend auf Objekttyp
              if (registration['objectType'] == 'farm') ...[
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                _buildDetailRow(
                  l10n.country,
                  getSpecificPropertyfromJSON(rawData, 'country') ?? 'N/A',
                ),
                _buildDetailRow(
                  l10n.totalArea,
                  '${getSpecificPropertyfromJSON(rawData, 'totalArea') ?? 'N/A'} ha',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                Text(l10n.close, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // 24h Edit helpers
  // ──────────────────────────────────────────────────────────────

  bool _isWithin24Hours(Map<String, dynamic> registration) {
    final regDate = registration['registrationDate'] as DateTime?;
    if (regDate == null) return false;
    return DateTime.now().difference(regDate).inHours < 24;
  }

  int _hoursRemaining(Map<String, dynamic> registration) {
    final regDate = registration['registrationDate'] as DateTime;
    final diff = 24 - DateTime.now().difference(regDate).inHours;
    return diff.clamp(0, 24).toInt();
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[700]),
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _applyEditChanges(
    Map<String, dynamic> doc,
    String objectType,
    Map<String, TextEditingController> controllers,
    XFile? nationalIdPhotoFile,
    XFile? consentFormPhotoFile,
    XFile? consentFormPhoto2File,
  ) async {
    if (objectType == 'farmer') {
      var updated = setSpecificPropertyJSON(
          doc, 'firstName', controllers['firstName']!.text.trim(), 'String');
      updated = setSpecificPropertyJSON(
          updated, 'lastName', controllers['lastName']!.text.trim(), 'String');
      updated = setSpecificPropertyJSON(updated, 'phoneNumber',
          controllers['phoneNumber']!.text.trim(), 'String');
      updated = setSpecificPropertyJSON(
          updated, 'email', controllers['email']!.text.trim(), 'String');

      final farmerPostalAddress =
          updated['currentGeolocation']?['postalAddress'] as Map?;
      if (farmerPostalAddress != null) {
        farmerPostalAddress['cityName'] = controllers['cityName']!.text.trim();
        farmerPostalAddress['stateName'] =
            controllers['stateName']!.text.trim();
      }

      // Update full display name
      updated['identity']['name'] =
          '${controllers['firstName']!.text.trim()} ${controllers['lastName']!.text.trim()}'
              .trim();
      // Update National ID in alternateIDs
      final altIds = updated['identity']?['alternateIDs'] as List?;
      if (altIds != null) {
        bool found = false;
        for (var i = 0; i < altIds.length; i++) {
          if (altIds[i]['issuedBy'] == 'National ID') {
            altIds[i]['UID'] = controllers['nationalID']!.text.trim();
            found = true;
            break;
          }
        }
        if (!found && controllers['nationalID']!.text.trim().isNotEmpty) {
          altIds.add({
            'issuedBy': 'National ID',
            'UID': controllers['nationalID']!.text.trim()
          });
        }
      }

      if (nationalIdPhotoFile != null) {
        await _replaceLinkedImageByRole(
          updated,
          role: 'nationalIDPhoto',
          imageName:
              'National ID - ${updated['identity']?['name']?.toString() ?? 'Farmer'}',
          file: nationalIdPhotoFile,
        );
      }

      final processedDoc = jsonFullDoubleToInt(sortJsonAlphabetically(updated))
          as Map<String, dynamic>;
      await changeObjectData(processedDoc);
    } else {
      // farm – start from passed doc (already deep-copied)
      doc['identity']['name'] = controllers['farmName']!.text.trim();
      final altIds = doc['identity']?['alternateIDs'] as List?;
      if (altIds != null) {
        bool found = false;
        for (var i = 0; i < altIds.length; i++) {
          if (altIds[i]['issuedBy'] == 'Farm Registry') {
            altIds[i]['UID'] = controllers['farmID']!.text.trim();
            found = true;
            break;
          }
        }
        if (!found && controllers['farmID']!.text.trim().isNotEmpty) {
          altIds.add({
            'issuedBy': 'Farm Registry',
            'UID': controllers['farmID']!.text.trim()
          });
        }
      }
      final postalAddress = doc['currentGeolocation']?['postalAddress'] as Map?;
      if (postalAddress != null) {
        postalAddress['cityName'] = controllers['cityName']!.text.trim();
        postalAddress['stateName'] = controllers['stateName']!.text.trim();
      }
      doc = setSpecificPropertyJSON(
          doc, 'email', controllers['email']!.text.trim(), 'String');
      final areaText =
          controllers['totalArea']!.text.trim().replaceAll(',', '.');
      if (areaText.isNotEmpty) {
        final areaVal = double.tryParse(areaText);
        if (areaVal != null) {
          doc = setSpecificPropertyJSON(
              doc, 'totalAreaEstimatedHa', areaVal, 'double');
        }
      }

      if (consentFormPhotoFile != null) {
        await _replaceLinkedImageByRole(
          doc,
          role: 'consentFormPhoto',
          imageName:
              'Consent Form - ${doc['identity']?['name']?.toString() ?? 'Farm'}',
          file: consentFormPhotoFile,
        );
      }

      if (consentFormPhoto2File != null) {
        await _replaceLinkedImageByRole(
          doc,
          role: 'consentFormPhoto2',
          imageName:
              'Consent Form 2 - ${doc['identity']?['name']?.toString() ?? 'Farm'}',
          file: consentFormPhoto2File,
        );
      }

      final processedDoc = jsonFullDoubleToInt(sortJsonAlphabetically(doc))
          as Map<String, dynamic>;
      await changeObjectData(processedDoc);
    }
  }

  String? _getLinkedImagePathByRole(Map<String, dynamic> doc, String role) {
    final linkedObjectRef = doc['linkedObjectRef'] as List?;
    if (linkedObjectRef == null) return null;

    for (final ref in linkedObjectRef) {
      if (ref is! Map) continue;
      final refRole = ref['role']?.toString();
      final refType = ref['RALType']?.toString();
      final refUid = ref['UID']?.toString();
      if (refRole != role || refType != 'image' || refUid == null) continue;

      final imageObjRaw = localStorage?.get(refUid);
      if (imageObjRaw is! Map) continue;

      final imageObj = Map<String, dynamic>.from(imageObjRaw);
      final cloudUrl = getSpecificPropertyfromJSON(imageObj, 'downloadURL');
      if (cloudUrl != null &&
          cloudUrl.toString().isNotEmpty &&
          cloudUrl.toString() != '-no data found-') {
        return cloudUrl.toString();
      }

      final localUrl =
          getSpecificPropertyfromJSON(imageObj, 'localDownloadURL');
      if (localUrl != null &&
          localUrl.toString().isNotEmpty &&
          localUrl.toString() != '-no data found-') {
        return localUrl.toString();
      }
    }

    return null;
  }

  Future<void> _replaceLinkedImageByRole(
    Map<String, dynamic> doc, {
    required String role,
    required String imageName,
    required XFile file,
  }) async {
    final imageObj = await createImageObject(
      localPath: file.path,
      position: null,
      imageName: imageName,
    );

    final processedImage = jsonFullDoubleToInt(sortJsonAlphabetically(imageObj))
        as Map<String, dynamic>;
    await generateDigitalSibling(processedImage);

    final newImageUid = getObjectMethodUID(processedImage);

    final linkedRefs = (doc['linkedObjectRef'] as List?) ?? <dynamic>[];
    linkedRefs.removeWhere((ref) {
      if (ref is! Map) return false;
      return ref['RALType']?.toString() == 'image' &&
          ref['role']?.toString() == role;
    });
    linkedRefs.add({
      'UID': newImageUid,
      'RALType': 'image',
      'role': role,
    });
    doc['linkedObjectRef'] = linkedRefs;
  }

  Future<void> _showEditDialog(
      Map<String, dynamic> registration, AppLocalizations l10n) async {
    final objectType = registration['objectType'] as String;
    final rawData = registration['rawData'] as Map<String, dynamic>;

    // Deep copy so we never mutate the displayed data
    final doc = jsonDecode(jsonEncode(rawData)) as Map<String, dynamic>;

    final formKey = GlobalKey<FormState>();
    late final Map<String, TextEditingController> controllers;

    if (objectType == 'farmer') {
      String nationalId = '';
      final altIds = doc['identity']?['alternateIDs'] as List?;
      if (altIds != null) {
        for (final altId in altIds) {
          if (altId['issuedBy'] == 'National ID') {
            nationalId = altId['UID']?.toString() ?? '';
            break;
          }
        }
      }
      controllers = {
        'firstName': TextEditingController(
            text: getSpecificPropertyfromJSON(doc, 'firstName') ?? ''),
        'lastName': TextEditingController(
            text: getSpecificPropertyfromJSON(doc, 'lastName') ?? ''),
        'phoneNumber': TextEditingController(
            text: getSpecificPropertyfromJSON(doc, 'phoneNumber') ?? ''),
        'email': TextEditingController(
            text: getSpecificPropertyfromJSON(doc, 'email') ?? ''),
        'cityName': TextEditingController(
            text: doc['currentGeolocation']?['postalAddress']?['cityName']
                    ?.toString() ??
                ''),
        'stateName': TextEditingController(
            text: doc['currentGeolocation']?['postalAddress']?['stateName']
                    ?.toString() ??
                ''),
        'nationalID': TextEditingController(text: nationalId),
      };
    } else {
      // farm
      String farmId = '';
      final altIds = doc['identity']?['alternateIDs'] as List?;
      if (altIds != null) {
        for (final altId in altIds) {
          if (altId['issuedBy'] == 'Farm Registry') {
            farmId = altId['UID']?.toString() ?? '';
            break;
          }
        }
      }
      controllers = {
        'farmName': TextEditingController(
            text: doc['identity']?['name']?.toString() ?? ''),
        'farmID': TextEditingController(text: farmId),
        'email': TextEditingController(
            text: getSpecificPropertyfromJSON(doc, 'email') ?? ''),
        'cityName': TextEditingController(
            text: doc['currentGeolocation']?['postalAddress']?['cityName']
                    ?.toString() ??
                ''),
        'stateName': TextEditingController(
            text: doc['currentGeolocation']?['postalAddress']?['stateName']
                    ?.toString() ??
                ''),
        'totalArea': TextEditingController(
            text:
                getSpecificPropertyfromJSON(doc, 'totalAreaEstimatedHa') ?? ''),
      };
    }

    final title =
        objectType == 'farmer' ? l10n.editFarmerTitle : l10n.editFarmTitle;
    bool isSaving = false;
    bool isUploadingPhoto = false;
    bool saved = false;
    XFile? newNationalIdPhoto;
    XFile? newConsentFormPhoto;
    XFile? newConsentFormPhoto2;
    String? nationalIdPhotoPath = objectType == 'farmer'
        ? _getLinkedImagePathByRole(doc, 'nationalIDPhoto')
        : null;
    String? consentFormPhotoPath = objectType == 'farm'
        ? _getLinkedImagePathByRole(doc, 'consentFormPhoto')
        : null;
    String? consentFormPhoto2Path = objectType == 'farm'
        ? _getLinkedImagePathByRole(doc, 'consentFormPhoto2')
        : null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title, style: const TextStyle(color: Colors.black)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (objectType == 'farmer') ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: (isSaving || isUploadingPhoto)
                            ? null
                            : () async {
                                setDialogState(() => isUploadingPhoto = true);
                                try {
                                  final picked = await FirebaseStorageService
                                      .showImageSourceDialog(ctx);
                                  if (picked != null) {
                                    setDialogState(() {
                                      newNationalIdPhoto = picked;
                                      nationalIdPhotoPath = picked.path;
                                    });
                                  }
                                } finally {
                                  setDialogState(
                                      () => isUploadingPhoto = false);
                                }
                              },
                        icon: isUploadingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                (newNationalIdPhoto != null ||
                                        (nationalIdPhotoPath != null &&
                                            nationalIdPhotoPath!.isNotEmpty))
                                    ? Icons.refresh
                                    : Icons.camera_alt,
                              ),
                        label: Text(
                          (newNationalIdPhoto != null ||
                                  (nationalIdPhotoPath != null &&
                                      nationalIdPhotoPath!.isNotEmpty))
                              ? l10n.retakeIDPhoto
                              : l10n.takeIDPhoto,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildEditField(l10n.firstName, controllers['firstName']!),
                    const SizedBox(height: 12),
                    _buildEditField(l10n.lastName, controllers['lastName']!),
                    const SizedBox(height: 12),
                    _buildEditField(
                        l10n.phoneNumber, controllers['phoneNumber']!,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    _buildEditField(l10n.email, controllers['email']!,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _buildEditField(l10n.cityName, controllers['cityName']!),
                    const SizedBox(height: 12),
                    _buildEditField(l10n.stateName, controllers['stateName']!),
                    const SizedBox(height: 12),
                    _buildEditField(
                        l10n.nationalID, controllers['nationalID']!),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: (isSaving || isUploadingPhoto)
                            ? null
                            : () async {
                                setDialogState(() => isUploadingPhoto = true);
                                try {
                                  final picked = await FirebaseStorageService
                                      .showImageSourceDialog(ctx);
                                  if (picked != null) {
                                    setDialogState(() {
                                      newConsentFormPhoto = picked;
                                      consentFormPhotoPath = picked.path;
                                    });
                                  }
                                } finally {
                                  setDialogState(
                                      () => isUploadingPhoto = false);
                                }
                              },
                        icon: isUploadingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                (newConsentFormPhoto != null ||
                                        (consentFormPhotoPath != null &&
                                            consentFormPhotoPath!.isNotEmpty))
                                    ? Icons.refresh
                                    : Icons.camera_alt,
                              ),
                        label: Text(
                          (newConsentFormPhoto != null ||
                                  (consentFormPhotoPath != null &&
                                      consentFormPhotoPath!.isNotEmpty))
                              ? l10n.retakeConsentFormPhoto
                              : l10n.takeConsentFormPhoto,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: (isSaving || isUploadingPhoto)
                            ? null
                            : () async {
                                setDialogState(() => isUploadingPhoto = true);
                                try {
                                  final picked = await FirebaseStorageService
                                      .showImageSourceDialog(ctx);
                                  if (picked != null) {
                                    setDialogState(() {
                                      newConsentFormPhoto2 = picked;
                                      consentFormPhoto2Path = picked.path;
                                    });
                                  }
                                } finally {
                                  setDialogState(
                                      () => isUploadingPhoto = false);
                                }
                              },
                        icon: isUploadingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                (newConsentFormPhoto2 != null ||
                                        (consentFormPhoto2Path != null &&
                                            consentFormPhoto2Path!.isNotEmpty))
                                    ? Icons.refresh
                                    : Icons.camera_alt,
                              ),
                        label: Text(
                          (newConsentFormPhoto2 != null ||
                                  (consentFormPhoto2Path != null &&
                                      consentFormPhoto2Path!.isNotEmpty))
                              ? l10n.retakeConsentFormPhoto2
                              : l10n.takeConsentFormPhoto2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildEditField(l10n.farmName, controllers['farmName']!),
                    const SizedBox(height: 12),
                    _buildEditField(l10n.farmID, controllers['farmID']!),
                    const SizedBox(height: 12),
                    _buildEditField(l10n.email, controllers['email']!,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _buildEditField(l10n.cityName, controllers['cityName']!),
                    const SizedBox(height: 12),
                    _buildEditField(l10n.stateName, controllers['stateName']!),
                    const SizedBox(height: 12),
                    _buildEditField(l10n.totalArea, controllers['totalArea']!,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSaving ? null : () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel,
                  style: const TextStyle(color: Colors.black87)),
            ),
            TextButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await _applyEditChanges(
                          doc,
                          objectType,
                          controllers,
                          newNationalIdPhoto,
                          newConsentFormPhoto,
                          newConsentFormPhoto2,
                        );
                        saved = true;
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (e) {
                        debugPrint('Edit save error: $e');
                        setDialogState(() => isSaving = false);
                        if (ctx.mounted) {
                          await fshowInfoDialog(ctx, 'Error: $e');
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.save,
                      style: const TextStyle(color: Colors.black87)),
            ),
          ],
        ),
      ),
    );

    for (final c in controllers.values) {
      c.dispose();
    }

    if (saved && mounted) {
      await fshowInfoDialog(context, l10n.changesSaved);
      await _loadRegistrations();
    }
  }
}
