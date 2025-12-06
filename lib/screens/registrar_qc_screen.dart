import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/open_ral_service.dart';
import '../helpers/json_full_double_to_int.dart';
import '../helpers/sort_json_alphabetically.dart';

/// Screen für QC-Review und Genehmigung von registrierten Farmen, Farmern und Feldern
class RegistrarQCScreen extends StatefulWidget {
  const RegistrarQCScreen({super.key});

  @override
  State<RegistrarQCScreen> createState() => _RegistrarQCScreenState();
}

class _RegistrarQCScreenState extends State<RegistrarQCScreen> {
  List<Map<String, dynamic>> _pendingRegistrations = [];
  bool _isLoading = true;
  String _filterType = 'all'; // all, farm, human, field

  @override
  void initState() {
    super.initState();
    _loadPendingRegistrations();
  }

  Future<void> _loadPendingRegistrations() async {
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> allPending = [];

      if (localStorage != null) {
        // Durchsuche alle Objekte im localStorage
        for (var key in localStorage!.keys) {
          final doc = localStorage!.get(key);
          if (doc != null) {
            final Map<String, dynamic> obj = Map<String, dynamic>.from(doc);

            // Prüfe auf qcPending Status
            if (obj['objectState'] == 'qcPending') {
              // Bestimme Objekttyp
              final ralType = obj['template']?['RALType'] ?? 'unknown';

              // Filter nur relevante Typen
              if (ralType == 'farm' ||
                  ralType == 'human' ||
                  ralType == 'field') {
                allPending.add(obj);
              }
            }
          }
        }
      }

      // Sortiere nach Erstellungsdatum (neueste zuerst)
      allPending.sort((a, b) {
        final aTime = a['methodHistoryRef']?.isNotEmpty == true
            ? (a['methodHistoryRef'][0]['timestamp'] ?? '')
            : '';
        final bTime = b['methodHistoryRef']?.isNotEmpty == true
            ? (b['methodHistoryRef'][0]['timestamp'] ?? '')
            : '';
        return bTime.compareTo(aTime);
      });

      setState(() {
        _pendingRegistrations = allPending;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading pending registrations: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRegistrations {
    if (_filterType == 'all') return _pendingRegistrations;
    return _pendingRegistrations.where((obj) {
      final ralType = obj['template']?['RALType'] ?? '';
      return ralType == _filterType;
    }).toList();
  }

  Future<void> _approveRegistration(Map<String, dynamic> object) async {
    final l10n = AppLocalizations.of(context)!;

    // Zeige Bestätigungs-Dialog
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => _ApprovalDialog(isApproval: true),
    );

    if (notes == null) return; // Abgebrochen

    setState(() => _isLoading = true);

    try {
      // Erstelle changeObjectData Methode
      Map<String, dynamic> changeMethod =
          await getOpenRALTemplate('changeObjectData');
      final methodUID = const Uuid().v4();
      setObjectMethodUID(changeMethod, methodUID);
      changeMethod['identity']['name'] =
          'QC Approval - ${object['identity']['name']}';
      changeMethod['methodState'] = 'finished';
      changeMethod['executor'] = appUserDoc!;
      changeMethod['existenceStarts'] =
          DateTime.now().toUtc().toIso8601String();

      // Specific properties für Change-Tracking
      changeMethod = setSpecificPropertyJSON(
          changeMethod, 'changeType', 'qc_approval', 'String');
      changeMethod = setSpecificPropertyJSON(
          changeMethod, 'oldState', 'qcPending', 'String');
      changeMethod = setSpecificPropertyJSON(
          changeMethod, 'newState', 'qcApproved', 'String');
      if (notes.isNotEmpty) {
        changeMethod = setSpecificPropertyJSON(
            changeMethod, 'approvalNotes', notes, 'String');
      }

      // Input: Altes Objekt
      addInputobject(changeMethod, object, 'item');

      // Output: Neues Objekt mit geändertem Status
      Map<String, dynamic> updatedObject = Map<String, dynamic>.from(object);
      updatedObject['objectState'] = 'qcApproved';

      // Update method history
      updatedObject['methodHistoryRef'].add({
        'UID': methodUID,
        'RALType': 'changeObjectData',
      });

      addOutputobject(changeMethod, updatedObject, 'item');

      // Speichere Objekte
      updatedObject =
          jsonFullDoubleToInt(sortJsonAlphabetically(updatedObject));
      await setObjectMethod(updatedObject, false, false);

      changeMethod = jsonFullDoubleToInt(sortJsonAlphabetically(changeMethod));
      await setObjectMethod(changeMethod, true, true); // Signieren und syncen

      // UI aktualisieren
      repaintContainerList.value = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.registrationApproved),
            backgroundColor: Colors.green,
          ),
        );
        await _loadPendingRegistrations();
      }
    } catch (e) {
      debugPrint('Error approving registration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectRegistration(Map<String, dynamic> object) async {
    final l10n = AppLocalizations.of(context)!;

    // Zeige Ablehnungs-Dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ApprovalDialog(isApproval: false),
    );

    if (reason == null) return; // Abgebrochen

    setState(() => _isLoading = true);

    try {
      // Erstelle changeObjectData Methode
      Map<String, dynamic> changeMethod =
          await getOpenRALTemplate('changeObjectData');
      final methodUID = const Uuid().v4();
      setObjectMethodUID(changeMethod, methodUID);
      changeMethod['identity']['name'] =
          'QC Rejection - ${object['identity']['name']}';
      changeMethod['methodState'] = 'finished';
      changeMethod['executor'] = appUserDoc!;
      changeMethod['existenceStarts'] =
          DateTime.now().toUtc().toIso8601String();

      // Specific properties
      changeMethod = setSpecificPropertyJSON(
          changeMethod, 'changeType', 'qc_rejection', 'String');
      changeMethod = setSpecificPropertyJSON(
          changeMethod, 'oldState', 'qcPending', 'String');
      changeMethod = setSpecificPropertyJSON(
          changeMethod, 'newState', 'qcRejected', 'String');
      if (reason.isNotEmpty) {
        changeMethod = setSpecificPropertyJSON(
            changeMethod, 'rejectionReason', reason, 'String');
      }

      // Input/Output
      addInputobject(changeMethod, object, 'item');

      Map<String, dynamic> updatedObject = Map<String, dynamic>.from(object);
      updatedObject['objectState'] = 'qcRejected';
      updatedObject['methodHistoryRef'].add({
        'UID': methodUID,
        'RALType': 'changeObjectData',
      });

      addOutputobject(changeMethod, updatedObject, 'item');

      // Speichern
      updatedObject =
          jsonFullDoubleToInt(sortJsonAlphabetically(updatedObject));
      await setObjectMethod(updatedObject, false, false);

      changeMethod = jsonFullDoubleToInt(sortJsonAlphabetically(changeMethod));
      await setObjectMethod(changeMethod, true, true);

      repaintContainerList.value = true;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.registrationRejected),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadPendingRegistrations();
      }
    } catch (e) {
      debugPrint('Error rejecting registration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _debugDeleteAllDisplayedObjects() async {
    final l10n = AppLocalizations.of(context)!;

    // Bestätigungs-Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DEBUG: Delete All Displayed Objects',
            style: TextStyle(color: Colors.red)),
        content: Text(
          'Möchten Sie wirklich alle ${_filteredRegistrations.length} angezeigten Objekte aus der lokalen Datenbank löschen?\n\nDieser Vorgang kann nicht rückgängig gemacht werden!',
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      int deletedCount = 0;

      // Lösche alle angezeigten Objekte aus localStorage
      for (var obj in _filteredRegistrations) {
        final uid = obj['identity']?['UID'];
        if (uid != null && localStorage != null) {
          await localStorage!.delete(uid);
          deletedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deletedCount Objekte gelöscht'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadPendingRegistrations();
      }
    } catch (e) {
      debugPrint('Error deleting objects: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewPendingRegistrations),
        actions: [
          // Debug-Button zum Löschen aller angezeigten Objekte
          if (kDebugMode && _filteredRegistrations.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              color: Colors.red,
              onPressed: _debugDeleteAllDisplayedObjects,
              tooltip: 'DEBUG: Delete all displayed objects',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingRegistrations,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: Text('All (${_pendingRegistrations.length})'),
                    selected: _filterType == 'all',
                    onSelected: (selected) {
                      setState(() => _filterType = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                        'Farms (${_pendingRegistrations.where((o) => o['template']?['RALType'] == 'farm').length})'),
                    selected: _filterType == 'farm',
                    onSelected: (selected) {
                      setState(() => _filterType = 'farm');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                        'Farmers (${_pendingRegistrations.where((o) => o['template']?['RALType'] == 'human').length})'),
                    selected: _filterType == 'human',
                    onSelected: (selected) {
                      setState(() => _filterType = 'human');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                        'Fields (${_pendingRegistrations.where((o) => o['template']?['RALType'] == 'field').length})'),
                    selected: _filterType == 'field',
                    onSelected: (selected) {
                      setState(() => _filterType = 'field');
                    },
                  ),
                ],
              ),
            ),
          ),

          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRegistrations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              l10n.noPendingRegistrations,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredRegistrations.length,
                        itemBuilder: (context, index) {
                          final obj = _filteredRegistrations[index];
                          return _buildRegistrationCard(obj);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationCard(Map<String, dynamic> obj) {
    final l10n = AppLocalizations.of(context)!;
    final ralType = obj['template']?['RALType'] ?? 'unknown';
    final name = obj['identity']?['name'] ?? 'Unnamed';

    IconData icon;
    Color color;
    String subtitle = '';

    switch (ralType) {
      case 'farm':
        icon = Icons.agriculture;
        color = Colors.green;
        subtitle = l10n.farmDetails;
        break;
      case 'human':
        icon = Icons.person;
        color = Colors.blue;
        subtitle = l10n.farmerDetails;
        break;
      case 'field':
        icon = Icons.terrain;
        color = Colors.orange;
        final area = getSpecificPropertyfromJSON(obj, 'area');
        final areaValue = (area is num) ? area.toDouble() : 0.0;
        subtitle = '${l10n.fieldArea}: ${areaValue.toStringAsFixed(2)} ha';
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(name),
        subtitle: Text(subtitle),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildObjectDetails(obj),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _rejectRegistration(obj),
                      icon: const Icon(Icons.close),
                      label: Text(l10n.rejectRegistration),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _approveRegistration(obj),
                      icon: const Icon(Icons.check),
                      label: Text(l10n.approveRegistration),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObjectDetails(Map<String, dynamic> obj) {
    final l10n = AppLocalizations.of(context)!;
    final ralType = obj['template']?['RALType'] ?? 'unknown';

    List<Widget> details = [];

    // Common details
    details.add(_buildDetailRow('UID', obj['identity']?['UID'] ?? '-'));

    // Type-specific details
    if (ralType == 'human') {
      final firstName = getSpecificPropertyfromJSON(obj, 'firstName') ?? '-';
      final lastName = getSpecificPropertyfromJSON(obj, 'lastName') ?? '-';
      final nationalID = getSpecificPropertyfromJSON(obj, 'nationalID') ?? '-';
      final phone = getSpecificPropertyfromJSON(obj, 'phoneNumber') ?? '-';

      details.addAll([
        _buildDetailRow(l10n.firstName, firstName),
        _buildDetailRow(l10n.lastName, lastName),
        _buildDetailRow(l10n.nationalID, nationalID),
        _buildDetailRow(l10n.phoneNumber, phone),
      ]);
    } else if (ralType == 'farm') {
      final totalArea = getSpecificPropertyfromJSON(obj, 'totalAreaHa');
      final totalAreaValue = (totalArea is num) ? totalArea.toDouble() : 0.0;
      final city =
          obj['currentGeolocation']?['postalAddress']?['cityName'] ?? '-';

      details.addAll([
        _buildDetailRow(
            'Total Area', '${totalAreaValue.toStringAsFixed(2)} ha'),
        _buildDetailRow(l10n.cityName, city),
      ]);
    } else if (ralType == 'field') {
      final area = getSpecificPropertyfromJSON(obj, 'area');
      final areaValue = (area is num) ? area.toDouble() : 0.0;
      final boundaries = getSpecificPropertyfromJSON(obj, 'boundaries') ?? [];
      final pointCount = boundaries is List ? boundaries.length : 0;

      details.addAll([
        _buildDetailRow(l10n.fieldArea, '${areaValue.toStringAsFixed(2)} ha'),
        _buildDetailRow('Polygon Points', '$pointCount'),
      ]);
    }

    // Registered by
    final recordedBy = getSpecificPropertyfromJSON(obj, 'recordedBy') ?? '-';
    if (recordedBy != '-') {
      details.add(_buildDetailRow(l10n.registeredBy, recordedBy));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details,
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

/// Dialog für Genehmigung oder Ablehnung mit Notizen/Grund
class _ApprovalDialog extends StatefulWidget {
  final bool isApproval;

  const _ApprovalDialog({required this.isApproval});

  @override
  State<_ApprovalDialog> createState() => _ApprovalDialogState();
}

class _ApprovalDialogState extends State<_ApprovalDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(widget.isApproval
          ? l10n.approveRegistration
          : l10n.rejectRegistration),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText:
              widget.isApproval ? l10n.approvalNotes : l10n.rejectionReason,
          hintText: widget.isApproval
              ? 'Optional notes...'
              : 'Please provide a reason',
          border: const OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isApproval ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.isApproval
              ? l10n.approveRegistration
              : l10n.rejectRegistration),
        ),
      ],
    );
  }
}
