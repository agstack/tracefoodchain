import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../services/open_ral_service.dart';
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

            registrations.add({
              'uid': doc['UID'],
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
            ],
          ),
        ),
      ),
    );
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
}
