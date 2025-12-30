import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

      // Abfrage der Cloud-Datenbank (Firestore) statt localStorage
      final querySnapshot = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .where('objectState', isEqualTo: 'qcPending')
          .get();

      for (var doc in querySnapshot.docs) {
        final obj = doc.data() as Map<String, dynamic>;
        final ralType = obj['template']?['RALType'] ?? 'unknown';

        // Filter nur relevante Typen
        if (ralType == 'farm' || ralType == 'human' || ralType == 'field') {
          allPending.add(obj);
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
      debugPrint('Error loading pending registrations from cloud: $e');
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

      // Speichere Objekte in Firestore
      updatedObject =
          jsonFullDoubleToInt(sortJsonAlphabetically(updatedObject));

      // Schreibe aktualisiertes Objekt in Firestore
      await FirebaseFirestore.instance
          .collection('TFC_objects')
          .doc(updatedObject['identity']['UID'])
          .set(updatedObject);

      changeMethod = jsonFullDoubleToInt(sortJsonAlphabetically(changeMethod));

      // Schreibe Methode in Firestore
      await FirebaseFirestore.instance
          .collection('TFC_methods')
          .doc(methodUID)
          .set(changeMethod);

      // Optional: Auch lokal speichern falls gewünscht
      if (localStorage != null) {
        await setObjectMethod(updatedObject, false, false);
        await setObjectMethod(changeMethod, false, false);
      }

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

      // Speichern in Firestore
      updatedObject =
          jsonFullDoubleToInt(sortJsonAlphabetically(updatedObject));

      // Schreibe aktualisiertes Objekt in Firestore
      await FirebaseFirestore.instance
          .collection('TFC_objects')
          .doc(updatedObject['identity']['UID'])
          .set(updatedObject);

      changeMethod = jsonFullDoubleToInt(sortJsonAlphabetically(changeMethod));

      // Schreibe Methode in Firestore
      await FirebaseFirestore.instance
          .collection('TFC_methods')
          .doc(methodUID)
          .set(changeMethod);

      // Optional: Auch lokal speichern falls gewünscht
      if (localStorage != null) {
        await setObjectMethod(updatedObject, false, false);
        await setObjectMethod(changeMethod, false, false);
      }

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
        title: Text(l10n.debugDeleteAllObjects,
            style: const TextStyle(color: Colors.red)),
        content: Text(
          l10n.confirmDeleteAllObjects(_filteredRegistrations.length),
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      int deletedCount = 0;

      // Lösche alle angezeigten Objekte aus Firestore
      for (var obj in _filteredRegistrations) {
        final uid = obj['identity']?['UID'];
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('TFC_objects')
              .doc(uid)
              .delete();
          deletedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.objectsDeleted(deletedCount)),
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
            content: Text('${l10n.errorDeleting}: $e'),
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
                    label:
                        Text('${l10n.all} (${_pendingRegistrations.length})'),
                    selected: _filterType == 'all',
                    onSelected: (selected) {
                      setState(() => _filterType = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                        '${l10n.farms} (${_pendingRegistrations.where((o) => o['template']?['RALType'] == 'farm').length})'),
                    selected: _filterType == 'farm',
                    onSelected: (selected) {
                      setState(() => _filterType = 'farm');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                        '${l10n.farmers} (${_pendingRegistrations.where((o) => o['template']?['RALType'] == 'human').length})'),
                    selected: _filterType == 'human',
                    onSelected: (selected) {
                      setState(() => _filterType = 'human');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                        '${l10n.fields} (${_pendingRegistrations.where((o) => o['template']?['RALType'] == 'field').length})'),
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
        title: Text(name, style: const TextStyle(color: Colors.black)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.black87)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Layout: Details links, Map rechts (wenn Geodaten vorhanden)
                _hasGeoData(obj)
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildObjectDetails(obj),
                          ),
                          const SizedBox(width: 16),
                          _buildMiniMapWidget(obj),
                        ],
                      )
                    : _buildObjectDetails(obj),
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
      ]);

      // National ID Photo anzeigen, falls vorhanden
      final nationalIDPhotoURL =
          getSpecificPropertyfromJSON(obj, 'nationalIDPhotoURL');
      if (nationalIDPhotoURL != null &&
          nationalIDPhotoURL.toString().isNotEmpty) {
        details.add(_buildNationalIDPhotoWidget(nationalIDPhotoURL.toString()));
      }

      details.add(_buildDetailRow(l10n.phoneNumber, phone));
    } else if (ralType == 'farm') {
      final totalArea = getSpecificPropertyfromJSON(obj, 'totalAreaHa');
      final totalAreaValue = (totalArea is num) ? totalArea.toDouble() : 0.0;
      final city =
          obj['currentGeolocation']?['postalAddress']?['cityName'] ?? '-';

      details.addAll([
        _buildDetailRow(
            l10n.totalArea, '${totalAreaValue.toStringAsFixed(2)} ha'),
        _buildDetailRow(l10n.cityName, city),
      ]);

      // Eigentümer der Farm - wird asynchron geladen
      details.add(_buildOwnerRow(obj, l10n));
    } else if (ralType == 'field') {
      final area = getSpecificPropertyfromJSON(obj, 'area');
      final areaValue = (area is num) ? area.toDouble() : 0.0;
      final boundaries = getSpecificPropertyfromJSON(obj, 'boundaries') ?? [];
      final pointCount = boundaries is List ? boundaries.length : 0;

      details.addAll([
        _buildDetailRow(l10n.fieldArea, '${areaValue.toStringAsFixed(2)} ha'),
        _buildDetailRow(l10n.polygonPoints, '$pointCount'),
      ]);
    }

    // Registered by - wird asynchron geladen
    details.add(_buildRegisteredByRow(obj, l10n));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details,
    );
  }

  /// Lädt den Namen und UID des Registrars aus der Methoden-Historie
  Future<Map<String, String>> _getRegistrarInfo(
      Map<String, dynamic> obj) async {
    try {
      // Hole ersten Eintrag aus methodHistoryRef
      final methodHistoryRef = obj['methodHistoryRef'];
      if (methodHistoryRef == null ||
          methodHistoryRef is! List ||
          methodHistoryRef.isEmpty) {
        return {'name': '-', 'uid': ''};
      }

      final firstMethod = methodHistoryRef[0];
      if (firstMethod is! Map || !firstMethod.containsKey('UID')) {
        return {'name': '-', 'uid': ''};
      }

      final methodUID = firstMethod['UID'];
      if (methodUID == null || methodUID.toString().isEmpty) {
        return {'name': '-', 'uid': ''};
      }

      // Lade Methode aus TFC_methods
      final methodDoc = await FirebaseFirestore.instance
          .collection('TFC_methods')
          .doc(methodUID.toString())
          .get();

      if (!methodDoc.exists) {
        return {'name': '-', 'uid': ''};
      }

      final methodData = methodDoc.data();
      if (methodData == null) {
        return {'name': '-', 'uid': ''};
      }

      // Extrahiere executor -> identity -> name und UID
      final executor = methodData['executor'];
      if (executor == null || executor is! Map) {
        return {'name': '-', 'uid': ''};
      }

      final identity = executor['identity'];
      if (identity == null || identity is! Map) {
        return {'name': '-', 'uid': ''};
      }

      final name = identity['name'];
      final uid = identity['UID'];
      if (name == null || name.toString().isEmpty) {
        return {'name': '-', 'uid': ''};
      }

      return {'name': name.toString(), 'uid': uid?.toString() ?? ''};
    } catch (e) {
      debugPrint('Error getting registrar info: $e');
      return {'name': '-', 'uid': ''};
    }
  }

  /// Zeigt einen Dialog mit Details zu einem openRAL Objekt
  Future<void> _showObjectDetailsDialog(String uid) async {
    final l10n = AppLocalizations.of(context)!;

    // Lade Objekt aus Firestore
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final objDoc = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .doc(uid)
          .get();

      // Schließe Loading-Dialog
      if (mounted) Navigator.of(context).pop();

      if (!objDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.objectNotFound),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final objData = objDoc.data();
      if (objData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.invalidObjectData),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Zeige Details-Dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _ObjectDetailsDialog(obj: objData),
        );
      }
    } catch (e) {
      debugPrint('Error loading object details: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Schließe Loading-Dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorLoadingDetails}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Widget für "Registriert von" Zeile mit FutureBuilder
  Widget _buildRegisteredByRow(
      Map<String, dynamic> obj, AppLocalizations l10n) {
    return FutureBuilder<Map<String, String>>(
      future: _getRegistrarInfo(obj),
      builder: (context, snapshot) {
        final info = snapshot.data ?? {'name': '...', 'uid': ''};
        final registrarName = info['name'] ?? '...';
        final registrarUID = info['uid'] ?? '';

        return _buildDetailRow(
          l10n.registeredBy,
          registrarName,
          onTap: registrarUID.isNotEmpty &&
                  registrarName != '-' &&
                  registrarName != '...'
              ? () => _showObjectDetailsDialog(registrarUID)
              : null,
        );
      },
    );
  }

  /// Lädt den Namen und UID des Farm-Eigentümers aus linkedObjectRef
  Future<Map<String, String>> _getOwnerInfo(
      Map<String, dynamic> farmObj) async {
    try {
      // Hole linkedObjectRef
      final linkedObjectRef = farmObj['linkedObjectRef'];
      if (linkedObjectRef == null ||
          linkedObjectRef is! List ||
          linkedObjectRef.isEmpty) {
        return {'name': '-', 'uid': ''};
      }

      // Finde Eintrag mit rolle = "owner"
      Map<String, dynamic>? ownerRef;
      for (var link in linkedObjectRef) {
        if (link is Map && link['role'] == 'owner') {
          ownerRef = Map<String, dynamic>.from(link);
          break;
        }
      }

      if (ownerRef == null || !ownerRef.containsKey('UID')) {
        return {'name': '-', 'uid': ''};
      }

      final ownerUID = ownerRef['UID'];
      if (ownerUID == null || ownerUID.toString().isEmpty) {
        return {'name': '-', 'uid': ''};
      }

      // Lade Eigentümer-Objekt aus TFC_objects
      final ownerDoc = await FirebaseFirestore.instance
          .collection('TFC_objects')
          .doc(ownerUID.toString())
          .get();

      if (!ownerDoc.exists) {
        return {'name': '-', 'uid': ''};
      }

      final ownerData = ownerDoc.data();
      if (ownerData == null) {
        return {'name': '-', 'uid': ''};
      }

      // Extrahiere identity -> name
      final identity = ownerData['identity'];
      if (identity == null || identity is! Map) {
        return {'name': '-', 'uid': ''};
      }

      final name = identity['name'];
      if (name == null || name.toString().isEmpty) {
        return {'name': '-', 'uid': ''};
      }

      return {'name': name.toString(), 'uid': ownerUID.toString()};
    } catch (e) {
      debugPrint('Error getting owner info: $e');
      return {'name': '-', 'uid': ''};
    }
  }

  /// Widget für "Eigentümer" Zeile mit FutureBuilder
  Widget _buildOwnerRow(Map<String, dynamic> obj, AppLocalizations l10n) {
    return FutureBuilder<Map<String, String>>(
      future: _getOwnerInfo(obj),
      builder: (context, snapshot) {
        final info = snapshot.data ?? {'name': '...', 'uid': ''};
        final ownerName = info['name'] ?? '...';
        final ownerUID = info['uid'] ?? '';

        return _buildDetailRow(
          l10n.owner,
          ownerName,
          onTap: ownerUID.isNotEmpty && ownerName != '-' && ownerName != '...'
              ? () => _showObjectDetailsDialog(ownerUID)
              : null,
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {VoidCallback? onTap}) {
    final l10n = AppLocalizations.of(context)!;
    final isUID = label == 'UID';
    final isClickable = isUID || onTap != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          Expanded(
            child: isClickable
                ? MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: isUID
                          ? () async {
                              await Clipboard.setData(
                                  ClipboardData(text: value));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.uidCopiedToClipboard),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: Colors.blue,
                                  ),
                                );
                              }
                            }
                          : onTap,
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  )
                : Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  /// Widget für National ID Photo mit Tap-to-Zoom
  Widget _buildNationalIDPhotoWidget(String photoURL) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.nationalIDPhoto,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showFullScreenImage(photoURL),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: photoURL,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 32, color: Colors.grey[400]),
                          const SizedBox(height: 4),
                          Text(
                            l10n.errorLoadingImage,
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.tapToEnlarge,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Zeigt Bild in bildschirmfüllender Ansicht
  void _showFullScreenImage(String imageURL) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Bildschirmfüllendes Bild
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageURL,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          l10n.errorLoadingImage,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Schließen-Button oben rechts
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Prüft ob Objekt gültige Geodaten hat (Geolocation oder Boundaries)
  bool _hasGeoData(Map<String, dynamic> obj) {
    // Prüfe currentGeolocation
    final geolocation = obj['currentGeolocation'];
    if (geolocation != null && geolocation is Map) {
      final lat = geolocation["geoCoordinates"]['latitude'];
      final lng = geolocation["geoCoordinates"]['longitude'];
      if (lat != null && lng != null) {
        final latNum =
            (lat is num) ? lat.toDouble() : double.tryParse(lat.toString());
        final lngNum =
            (lng is num) ? lng.toDouble() : double.tryParse(lng.toString());
        if (latNum != null &&
            lngNum != null &&
            latNum != 0.0 &&
            lngNum != 0.0) {
          return true;
        }
      }
    }

    // Prüfe boundaries in specificProperties
    final boundaries = getSpecificPropertyfromJSON(obj, 'boundaries');
    if (boundaries != null && boundaries is List && boundaries.isNotEmpty) {
      return true;
    }

    return false;
  }

  /// Extrahiert LatLng aus currentGeolocation
  LatLng? _getLocationFromObject(Map<String, dynamic> obj) {
    final geolocation = obj['currentGeolocation'];
    if (geolocation == null || geolocation is! Map) return null;

    final lat = geolocation["geoCoordinates"]['latitude'];
    final lng = geolocation["geoCoordinates"]['longitude'];
    if (lat == null || lng == null) return null;

    final latNum =
        (lat is num) ? lat.toDouble() : double.tryParse(lat.toString());
    final lngNum =
        (lng is num) ? lng.toDouble() : double.tryParse(lng.toString());

    if (latNum == null || lngNum == null || latNum == 0.0 || lngNum == 0.0) {
      return null;
    }

    return LatLng(latNum, lngNum);
  }

  /// Extrahiert Polygon-Koordinaten aus boundaries
  List<LatLng>? _getBoundariesFromObject(Map<String, dynamic> obj) {
    final boundaries = getSpecificPropertyfromJSON(obj, 'boundaries');
    if (boundaries == null || boundaries is! List || boundaries.isEmpty) {
      return null;
    }

    List<LatLng> points = [];
    for (var point in boundaries) {
      if (point is! Map) continue;

      final lat = point['latitude'] ?? point['lat'];
      final lng = point['longitude'] ?? point['lon'] ?? point['lng'];

      if (lat == null || lng == null) continue;

      final latNum =
          (lat is num) ? lat.toDouble() : double.tryParse(lat.toString());
      final lngNum =
          (lng is num) ? lng.toDouble() : double.tryParse(lng.toString());

      if (latNum != null && lngNum != null) {
        points.add(LatLng(latNum, lngNum));
      }
    }

    return points.isNotEmpty ? points : null;
  }

  /// Erstellt eine kleine Map-Vorschau für die Card
  Widget _buildMiniMapWidget(Map<String, dynamic> obj) {
    final l10n = AppLocalizations.of(context)!;
    final location = _getLocationFromObject(obj);
    final boundaries = _getBoundariesFromObject(obj);

    // Berechne Kamera-Position (Center)
    LatLng center;
    if (location != null) {
      center = location;
    } else if (boundaries != null && boundaries.isNotEmpty) {
      // Berechne Center des Polygons
      double sumLat = 0;
      double sumLng = 0;
      for (var point in boundaries) {
        sumLat += point.latitude;
        sumLng += point.longitude;
      }
      center = LatLng(sumLat / boundaries.length, sumLng / boundaries.length);
    } else {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _showFullScreenMap(obj),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 200,
          width: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // AbsorbPointer verhindert Interaktion mit der Map (verhindert Links zu Google Maps)
                AbsorbPointer(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: center,
                      zoom: boundaries != null ? 16 : 14,
                    ),
                    markers: location != null
                        ? {
                            Marker(
                              markerId: const MarkerId('location'),
                              position: location,
                            ),
                          }
                        : {},
                    polygons: boundaries != null
                        ? {
                            Polygon(
                              polygonId: const PolygonId('boundary'),
                              points: boundaries,
                              strokeColor: Colors.blue,
                              strokeWidth: 2,
                              fillColor: Colors.blue.withOpacity(0.2),
                            ),
                          }
                        : {},
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    liteModeEnabled:
                        true, // Lite Mode für bessere Performance und weniger Interaktivität
                  ),
                ),
                // Overlay mit Hinweis
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.tapToEnlargeMap,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Zeigt Map in bildschirmfüllender Ansicht
  void _showFullScreenMap(Map<String, dynamic> obj) {
    final l10n = AppLocalizations.of(context)!;
    final location = _getLocationFromObject(obj);
    final boundaries = _getBoundariesFromObject(obj);

    // Berechne Kamera-Position
    LatLng center;
    if (location != null) {
      center = location;
    } else if (boundaries != null && boundaries.isNotEmpty) {
      double sumLat = 0;
      double sumLng = 0;
      for (var point in boundaries) {
        sumLat += point.latitude;
        sumLng += point.longitude;
      }
      center = LatLng(sumLat / boundaries.length, sumLng / boundaries.length);
    } else {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Bildschirmfüllende Map
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: center,
                zoom: boundaries != null ? 17 : 15,
              ),
              markers: location != null
                  ? {
                      Marker(
                        markerId: const MarkerId('location'),
                        position: location,
                        infoWindow: InfoWindow(
                          title: obj['identity']?['name'] ?? l10n.mapView,
                        ),
                      ),
                    }
                  : {},
              polygons: boundaries != null
                  ? {
                      Polygon(
                        polygonId: const PolygonId('boundary'),
                        points: boundaries,
                        strokeColor: Colors.blue,
                        strokeWidth: 3,
                        fillColor: Colors.blue.withOpacity(0.2),
                      ),
                    }
                  : {},
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            ),
            // Schließen-Button
            Positioned(
              top: 40,
              right: 16,
              child: FloatingActionButton(
                backgroundColor: Colors.white,
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, color: Colors.black),
              ),
            ),
            // Titel
            Positioned(
              top: 40,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  obj['identity']?['name'] ?? l10n.mapView,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
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
          hintText:
              widget.isApproval ? l10n.optionalNotes : l10n.pleaseProvideReason,
          border: const OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
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

/// Dialog zur Anzeige von openRAL Objekt-Details
class _ObjectDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> obj;

  const _ObjectDetailsDialog({required this.obj});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ralType = obj['template']?['RALType'] ?? 'unknown';
    final name = obj['identity']?['name'] ?? l10n.unnamed;

    IconData icon;
    Color color;

    switch (ralType) {
      case 'farm':
        icon = Icons.agriculture;
        color = Colors.green;
        break;
      case 'human':
        icon = Icons.person;
        color = Colors.blue;
        break;
      case 'field':
        icon = Icons.terrain;
        color = Colors.orange;
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.grey;
    }

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: color,
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildObjectInfo(obj, l10n, ralType),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectInfo(
      Map<String, dynamic> obj, AppLocalizations l10n, String ralType) {
    List<Widget> details = [];

    // Common details
    details.add(_buildInfoRow('UID', obj['identity']?['UID'] ?? '-'));
    details.add(_buildInfoRow(l10n.type, ralType));

    final objectState = obj['objectState'] ?? '-';
    details.add(_buildInfoRow(l10n.status, objectState));

    // Type-specific details
    if (ralType == 'human') {
      final firstName = getSpecificPropertyfromJSON(obj, 'firstName') ?? '-';
      final lastName = getSpecificPropertyfromJSON(obj, 'lastName') ?? '-';
      final nationalID = getSpecificPropertyfromJSON(obj, 'nationalID') ?? '-';
      final phone = getSpecificPropertyfromJSON(obj, 'phoneNumber') ?? '-';
      final email = getSpecificPropertyfromJSON(obj, 'email') ?? '-';

      details.addAll([
        _buildInfoRow(l10n.firstName, firstName),
        _buildInfoRow(l10n.lastName, lastName),
        _buildInfoRow(l10n.nationalID, nationalID),
        _buildInfoRow(l10n.phoneNumber, phone),
        _buildInfoRow(l10n.email, email),
      ]);
    } else if (ralType == 'farm') {
      final totalArea = getSpecificPropertyfromJSON(obj, 'totalAreaHa');
      final totalAreaValue = (totalArea is num) ? totalArea.toDouble() : 0.0;
      final city =
          obj['currentGeolocation']?['postalAddress']?['cityName'] ?? '-';
      final country =
          obj['currentGeolocation']?['postalAddress']?['countryName'] ?? '-';

      details.addAll([
        _buildInfoRow(
            l10n.totalArea, '${totalAreaValue.toStringAsFixed(2)} ha'),
        _buildInfoRow(l10n.cityName, city),
        _buildInfoRow(l10n.country, country),
      ]);
    } else if (ralType == 'field') {
      final area = getSpecificPropertyfromJSON(obj, 'area');
      final areaValue = (area is num) ? area.toDouble() : 0.0;
      final boundaries = getSpecificPropertyfromJSON(obj, 'boundaries') ?? [];
      final pointCount = boundaries is List ? boundaries.length : 0;

      details.addAll([
        _buildInfoRow(l10n.fieldArea, '${areaValue.toStringAsFixed(2)} ha'),
        _buildInfoRow(l10n.polygonPoints, '$pointCount'),
      ]);
    }

    // Creation date
    final methodHistoryRef = obj['methodHistoryRef'];
    if (methodHistoryRef is List && methodHistoryRef.isNotEmpty) {
      final firstMethod = methodHistoryRef[0];
      if (firstMethod is Map && firstMethod.containsKey('timestamp')) {
        final timestamp = firstMethod['timestamp'];
        if (timestamp != null) {
          details.add(_buildInfoRow(l10n.created, timestamp.toString()));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: details,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
