import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../helpers/json_full_double_to_int.dart';
import '../helpers/sort_json_alphabetically.dart';
import '../l10n/app_localizations.dart';
import '../services/firebase_storage_service.dart';
import '../widgets/gps_position_widget.dart';
import '../widgets/stepper_registrar_registration.dart';
import '../widgets/field_boundary_recorder.dart';
import '../widgets/language_selector.dart';
import '../screens/registrar_qc_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/view_history_screen.dart';
import '../providers/app_state.dart';
import '../main.dart';
import '../services/open_ral_service.dart';
import '../services/service_functions.dart';

class RegistrarScreen extends StatefulWidget {
  const RegistrarScreen({super.key});

  @override
  State<RegistrarScreen> createState() => _RegistrarScreenState();
}

class _RegistrarScreenState extends State<RegistrarScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _userName = '';
  bool _isSuperAdmin = false;

  // Statistics
  int _statRegisteredToday = 0;
  int _statVerified = 0;
  int _statPending = 0;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _checkUserRole();
    _loadStats();
  }

  /// Counts farmer/farm/field objects in localStorage and updates the stats.
  ///
  /// - Registered today: farm+human objects whose creation method has an
  ///   existenceStarts timestamp that falls within today's calendar day.
  /// - Verified: all farm+human objects with objectState == 'active'.
  /// - Pending:  all farm+human+field objects with objectState == 'qcPending'.
  void _loadStats() {
    if (!isLocalStorageInitialized()) return;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    int registeredToday = 0;
    int verified = 0;
    int pending = 0;

    for (final key in localStorage!.keys) {
      try {
        final value = localStorage!.get(key);
        if (value is! Map) continue;
        final doc = Map<String, dynamic>.from(value);

        final objectType = doc['template']?['RALType']?.toString();
        if (objectType == null) continue;

        final isFarmerOrFarm = objectType == 'human' || objectType == 'farm';
        final isFarmerFarmOrField =
            isFarmerOrFarm || objectType == 'field' || objectType == 'plot';

        final objectState = doc['objectState']?.toString();

        // Pending count: all relevant objects awaiting QC
        if (isFarmerFarmOrField && objectState == 'qcPending') {
          pending++;
        }

        if (!isFarmerOrFarm) continue;

        // Verified count
        if (objectState == 'active') verified++;

        // Registered-today count: look up creation method's existenceStarts
        final methodHistoryRef = doc['methodHistoryRef'] as List?;
        if (methodHistoryRef == null || methodHistoryRef.isEmpty) continue;
        final firstMethodUid = methodHistoryRef.first?['UID']?.toString();
        if (firstMethodUid == null) continue;
        final methodDoc = localStorage!.get(firstMethodUid);
        if (methodDoc == null || methodDoc is! Map) continue;
        final existenceStartsRaw = methodDoc['existenceStarts']?.toString();
        if (existenceStartsRaw == null) continue;
        final createdAt = DateTime.tryParse(existenceStartsRaw);
        if (createdAt != null &&
            createdAt.isAfter(todayStart) &&
            createdAt.isBefore(todayEnd)) {
          registeredToday++;
        }
      } catch (_) {
        continue;
      }
    }

    if (mounted) {
      setState(() {
        _statRegisteredToday = registeredToday;
        _statVerified = verified;
        _statPending = pending;
      });
    }
  }

  void _checkUserRole() {
    if (appUserDoc != null) {
      final userRole = getSpecificPropertyfromJSON(appUserDoc!, "userRole");
      setState(() {
        _isSuperAdmin = userRole == 'SUPERADMIN';
      });
    }
  }

  void _loadUserName() {
    if (appUserDoc != null) {
      final firstName = appUserDoc!['specificProperties']?.firstWhere(
            (prop) => prop['key'] == 'firstName',
            orElse: () => {'value': ''},
          )['value'] ??
          '';
      final lastName = appUserDoc!['specificProperties']?.firstWhere(
            (prop) => prop['key'] == 'lastName',
            orElse: () => {'value': ''},
          )['value'] ??
          '';

      setState(() {
        _userName = '$firstName $lastName'.trim();
        if (_userName.isEmpty) {
          _userName = user?.email ?? 'Registrar';
        }
      });
    }
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logout, style: const TextStyle(color: Colors.black)),
        content: Text(l10n.logoutConfirmation,
            style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel,
                style: const TextStyle(color: Colors.black87)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      // Verwende die zentrale signOut-Methode aus AppState
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.signOut();

      // Navigiere zum AuthScreen und entferne alle vorherigen Routes
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  Future<void> _showEditProfileDialog() async {
    if (appUserDoc == null) return;
    final l10n = AppLocalizations.of(context)!;

    final doc = jsonDecode(jsonEncode(appUserDoc)) as Map<String, dynamic>;

    final firstNameController = TextEditingController(
        text: getSpecificPropertyfromJSON(doc, 'firstName') ?? '');
    final lastNameController = TextEditingController(
        text: getSpecificPropertyfromJSON(doc, 'lastName') ?? '');
    final phoneController = TextEditingController(
        text: getSpecificPropertyfromJSON(doc, 'phoneNumber') ?? '');

    // Current avatar URL from the user doc
    String? editAvatarUrl =
        getSpecificPropertyfromJSON(doc, 'downloadURL') ?? '';
    if (editAvatarUrl!.isEmpty) editAvatarUrl = null;

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool isUploadingPhoto = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.editProfile,
              style: const TextStyle(color: Colors.black)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Profile photo ---
                  Center(
                    child: GestureDetector(
                      onTap: (isUploadingPhoto || isSaving)
                          ? null
                          : () async {
                              setDialogState(() => isUploadingPhoto = true);
                              try {
                                final XFile? file = await FirebaseStorageService
                                    .showImageSourceDialog(ctx);
                                if (file != null) {
                                  final url = await FirebaseStorageService
                                      .uploadUserAvatar(file);
                                  if (url != null) {
                                    setDialogState(() => editAvatarUrl = url);
                                  }
                                }
                              } catch (e) {
                                debugPrint('Photo upload error: $e');
                              } finally {
                                setDialogState(() => isUploadingPhoto = false);
                              }
                            },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: editAvatarUrl != null
                                ? NetworkImage(editAvatarUrl!)
                                : null,
                            child: editAvatarUrl == null
                                ? Icon(Icons.person,
                                    size: 40, color: Colors.grey[600])
                                : null,
                          ),
                          if (isUploadingPhoto)
                            const Positioned.fill(
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.black45,
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                ),
                              ),
                            )
                          else
                            Container(
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 16),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // --- Text fields ---
                  TextFormField(
                    controller: firstNameController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: l10n.firstName,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.pleaseEnterFirstName
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: lastNameController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: l10n.lastName,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.pleaseEnterLastName
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    style: const TextStyle(color: Colors.black),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.phoneNumber,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                  ),
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
                        var updated = setSpecificPropertyJSON(doc, 'firstName',
                            firstNameController.text.trim(), 'String');
                        updated = setSpecificPropertyJSON(updated, 'lastName',
                            lastNameController.text.trim(), 'String');
                        updated = setSpecificPropertyJSON(
                            updated,
                            'phoneNumber',
                            phoneController.text.trim(),
                            'String');
                        if (editAvatarUrl != null) {
                          updated = setSpecificPropertyJSON(
                              updated, 'downloadURL', editAvatarUrl!, 'String');
                        }
                        updated['identity']['name'] =
                            '${firstNameController.text.trim()} ${lastNameController.text.trim()}'
                                .trim();
                        final processedDoc =
                            jsonFullDoubleToInt(sortJsonAlphabetically(updated))
                                as Map<String, dynamic>;
                        await changeObjectData(processedDoc);
                        appUserDoc = processedDoc;
                        if (mounted) {
                          _loadUserName();
                          Navigator.of(dialogContext).pop();
                          await fshowInfoDialog(context, l10n.changesSaved);
                        }
                      } catch (e) {
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

    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
  }

  void _openRegistrationForm() {
    final appState = Provider.of<AppState>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    // GPS-Check
    if (!appState.hasGPS) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.gpsRequired),
          content: Text(l10n.pleaseEnableGps),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Öffne Registrierungs-Stepper
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StepperRegistrarRegistration(),
      ),
    ).then((_) => _loadStats());
  }

  void _openQCReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RegistrarQCScreen(),
      ),
    ).then((_) => _loadStats());
  }

  void _openFieldBoundaryRecorder() {
    final appState = Provider.of<AppState>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    // GPS-Check
    if (!appState.hasGPS) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.gpsRequired),
          content: Text(l10n.pleaseEnableGps),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Öffne Field Boundary Recorder
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FieldBoundaryRecorder(),
      ),
    ).then((_) => _loadStats());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.registrarDashboard),
        actions: [
          const LanguageSelector(),
          IconButton(
            icon: const Icon(Icons.manage_accounts),
            onPressed: _showEditProfileDialog,
            tooltip: l10n.viewAndEditProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor,
                              radius: 30,
                              child: const Icon(
                                Icons.verified_user,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.welcome,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: Colors.grey[600],
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _userName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'REGISTRAR',
                                      style: TextStyle(
                                        color: Colors.green[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Flächeneinheit-Umschalter
                                  Consumer<AppState>(
                                    builder: (ctx, appState, _) {
                                      final l10nCtx = AppLocalizations.of(ctx)!;
                                      final units = getAreaUnits(country);
                                      final currentUnit = units.firstWhere(
                                        (u) =>
                                            u['symbol'] ==
                                            appState.preferredAreaUnitSymbol,
                                        orElse: () => units.first,
                                      );
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${l10nCtx.areaUnitSetting}:',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              final idx = units.indexWhere(
                                                  (u) =>
                                                      u['symbol'] ==
                                                      currentUnit['symbol']);
                                              final nextUnit = units[
                                                  (idx + 1) % units.length];
                                              appState.setPreferredAreaUnit(
                                                  nextUnit['symbol'] as String);
                                            },
                                            icon: const Icon(Icons.swap_horiz,
                                                size: 18),
                                            label: Text(
                                              currentUnit['symbol'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.blue[700],
                                              side: BorderSide(
                                                  color: Colors.blue[400]!),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions Card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.quickActions,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildActionButton(
                              context,
                              icon: Icons.agriculture,
                              label: l10n.registerFarmFarmer,
                              color: Colors.blue,
                              onTap: _openRegistrationForm,
                            ),
                            _buildActionButton(
                              context,
                              icon: Icons.map,
                              label: l10n.recordFieldBoundary,
                              color: Colors.green,
                              onTap: _openFieldBoundaryRecorder,
                            ),
                            _buildActionButton(
                              context,
                              icon: Icons.history,
                              label: l10n.viewHistory,
                              color: Colors.teal,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ViewHistoryScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // GPS Position Widget
                const GpsPositionWidget(),
                const SizedBox(height: 24),

                // Statistics Card (Placeholder for future)
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.todaysStatistics,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              context,
                              icon: Icons.person_add,
                              label: l10n.registered,
                              value: '$_statRegisteredToday',
                              color: Colors.blue,
                            ),
                            _buildStatItem(
                              context,
                              icon: Icons.check_circle,
                              label: l10n.verified,
                              value: '$_statVerified',
                              color: Colors.green,
                            ),
                            _buildStatItem(
                              context,
                              icon: Icons.pending,
                              label: l10n.pending,
                              value: '$_statPending',
                              color: Colors.orange,
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: (MediaQuery.of(context).size.width - 64) / 2,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
