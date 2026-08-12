import 'dart:async';
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
import '../widgets/status_chip.dart';
import '../widgets/sync_control_card.dart';
import '../services/background_sync_service.dart';
import '../services/sync_settings_service.dart';
import '../screens/registrar_qc_screen.dart';
import '../screens/sign_up_screen.dart';
import '../screens/view_history_screen.dart';
import '../providers/app_state.dart';
import '../main.dart';
import '../services/open_ral_service.dart';
import '../services/service_functions.dart';
import '../widgets/ihcafe_producer_widgets.dart';

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

  /// WP A3: the registrar dashboard is a route of its own - without this timer
  /// a failed push would only be retried when the user happens to trigger a
  /// save, so backoff retries would never fire on their own here.
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _checkUserRole();
    _loadStats();
    _startPeriodicSync();
  }

  void _startPeriodicSync() {
    _syncTimer =
        Timer.periodic(Duration(seconds: cloudSyncFrequency), (_) async {
      if (!mounted) return;
      final appState = Provider.of<AppState>(context, listen: false);
      if (!appState.isConnected || !appState.isAuthenticated) return;
      if (appState.uploadPaused) return;
      await appState.syncNow();
      if (mounted) _loadStats();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  /// Counts farmer/farm/field objects in localStorage and updates the stats.
  ///
  /// All three numbers cover the same object types (human, farm, field, plot):
  /// - Registered today: objects whose creation method has an existenceStarts
  ///   timestamp that falls within today's calendar day.
  /// - Verified: objects with objectState == 'active'.
  /// - Pending:  objects with objectState == 'qcPending'.
  ///
  /// The counts must match what the history screen lists, otherwise the
  /// dashboard claims registrations the user cannot find anywhere.
  void _loadStats() {
    if (!isLocalStorageInitialized()) return;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // The registrar's own profile is a `human` object too and is created on
    // first login - without this it would count as a farmer registered today,
    // while the history screen (which filters it out) shows nothing.
    // Fall back to the Firebase UID: the user object is keyed by it, and
    // appUserDoc may not be loaded yet on the first build.
    final currentAppUserUid = appUserDoc?['identity']?['UID']?.toString() ??
        FirebaseAuth.instance.currentUser?.uid;

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

        final objectUid = doc['identity']?['UID']?.toString();
        if (objectType == 'human' &&
            currentAppUserUid != null &&
            objectUid == currentAppUserUid) {
          continue;
        }

        // All three numbers describe the SAME population - farmers, farms and
        // fields. Counting "pending" over a wider set than "registered today"
        // made the card contradict itself (4 registered vs 5 pending for the
        // same 2 farmers + 2 farms + 1 field).
        final isRegistrationObject = objectType == 'human' ||
            objectType == 'farm' ||
            objectType == 'field' ||
            objectType == 'plot';
        if (!isRegistrationObject) continue;

        final objectState = doc['objectState']?.toString();

        // Same status window the history screen uses - anything outside it is
        // not listed there and must not be counted here either.
        final isListedState = objectState == 'active' ||
            objectState == 'qcPending' ||
            objectState == 'qcRejected';
        if (!isListedState) continue;

        // Pending count: all relevant objects awaiting QC
        if (objectState == 'qcPending') pending++;

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
    // Der Status-Chip zeigt offene Uploads - nach jeder Registrierung neu
    // zählen, sonst hinkt er bis zum nächsten Sync-Tick hinterher.
    refreshPendingItemCount();
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Begrüßung - eine Zeile statt einer Karte. Name und Rolle
                //    sind Kontext, keine Aufgabe.
                _buildGreeting(context, l10n),
                const SizedBox(height: 12),

                // 2. Statusstreifen: GPS, Verbindung, offene Uploads in einer
                //    Zeile. Beantwortet vor dem Start die Frage "kann ich jetzt
                //    arbeiten und ist meine Arbeit sicher?" - Details per Tap.
                _buildStatusStrip(context, l10n),
                const SizedBox(height: 20),

                // 3. Die beiden Felderfassungs-Aufgaben - gleichrangig, weil
                //    beide echte Außendienst-Arbeit sind.
                _buildPrimaryActions(context, l10n),
                const SizedBox(height: 24),

                // 4. Motivation + Rückschau: die Tagesleistung als Hero-Zahl,
                //    der Verlauf als ihr natürlicher Einstieg.
                _buildTodayCard(context, l10n),
                const SizedBox(height: 16),

                // 6. Selten Gebrauchtes eingeklappt. Der Registrar erreicht den
                //    Settings-Screen nicht, daher liegen Flächeneinheit und das
                //    volle Sync-Panel hier.
                _buildToolsSection(context, l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          radius: 20,
          child: const Icon(Icons.verified_user, size: 22, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.welcome,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                _userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'REGISTRAR',
            style: TextStyle(
              color: Colors.green[800],
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusStrip(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        const Expanded(child: GpsPositionWidget(compact: true)),
        const SizedBox(width: 8),
        Expanded(
          child: Consumer<AppState>(
            builder: (context, appState, _) {
              final online = appState.isConnected;
              return StatusChip(
                icon: online ? Icons.wifi : Icons.wifi_off,
                color: online ? Colors.green : Colors.grey,
                label: online ? l10n.statusOnline : l10n.statusOffline,
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: syncSettings.uploadPaused,
            builder: (context, paused, _) {
              return ValueListenableBuilder<int>(
                valueListenable: syncSettings.pendingItemCount,
                builder: (context, pending, __) {
                  final IconData icon;
                  final Color color;
                  final String label;
                  // While paused the label describes the state, so the count
                  // moves into a badge - otherwise pausing would hide exactly
                  // the number that matters most while offline.
                  int? badge;
                  if (paused) {
                    icon = Icons.cloud_off;
                    color = Colors.orange[700]!;
                    label = l10n.uploadPausedShort;
                    badge = pending;
                  } else if (pending > 0) {
                    icon = Icons.cloud_upload;
                    color = Colors.orange[700]!;
                    label = l10n.pendingUploadsShort(pending);
                  } else {
                    icon = Icons.cloud_done;
                    color = Colors.green[700]!;
                    label = l10n.syncedShort;
                  }
                  return StatusChip(
                    icon: icon,
                    color: color,
                    label: label,
                    badgeCount: badge,
                    onTap: () => showSyncSheet(context),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Registrieren und Feldgrenzen erfassen sind beide Außendienst-Arbeit und
  /// bekommen deshalb dieselbe Größe. Unterschieden werden sie über Farbe und
  /// Icon, nicht über die Hierarchie.
  Widget _buildPrimaryActions(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        _buildPrimaryButton(
          icon: Icons.agriculture,
          label: l10n.registerFarmFarmer,
          color: Theme.of(context).primaryColor,
          onTap: _openRegistrationForm,
        ),
        const SizedBox(height: 12),
        _buildPrimaryButton(
          icon: Icons.map,
          label: l10n.recordFieldBoundary,
          color: Colors.blue[700]!,
          onTap: _openFieldBoundaryRecorder,
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          // Das globale ElevatedButton-Theme erzwingt Grün - für den zweiten
          // Button muss die Farbe daher explizit gesetzt werden.
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tagesleistung als Motivation: die "heute registriert"-Zahl dominiert,
  /// verifiziert/offen stehen als Kontext daneben. Der Verlauf hängt als
  /// Rückschau direkt darunter - er beantwortet dieselbe Frage in ausführlich.
  Widget _buildTodayCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_statRegisteredToday',
                      style: TextStyle(
                        fontSize: 44,
                        height: 1.0,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.registeredToday,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMiniStat(
                        icon: Icons.check_circle,
                        color: Colors.green[700]!,
                        label: l10n.verified,
                        value: _statVerified,
                      ),
                      const SizedBox(height: 8),
                      _buildMiniStat(
                        icon: Icons.pending,
                        color: Colors.orange[700]!,
                        label: l10n.pending,
                        value: _statPending,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ViewHistoryScreen(),
                ),
              ).then((_) => _loadStats());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.history, size: 20, color: Colors.teal[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.viewHistory,
                      style: TextStyle(
                        color: Colors.teal[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[500]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required Color color,
    required String label,
    required int value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$value',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildToolsSection(BuildContext context, AppLocalizations l10n) {
    return Card(
      elevation: 0,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Theme(
        // Die Divider der ExpansionTile passen nicht zur flachen Karte.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.tune),
          title: Text(
            l10n.toolsAndSettings,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            // Flächeneinheit - für den Registrar nur hier erreichbar, da der
            // Settings-Screen aus diesem Workflow nicht verlinkt ist.
            Consumer<AppState>(
              builder: (ctx, appState, _) {
                final units = getAreaUnits(country);
                final currentUnit = units.firstWhere(
                  (u) => u['symbol'] == appState.preferredAreaUnitSymbol,
                  orElse: () => units.first,
                );
                return ListTile(
                  leading: const Icon(Icons.straighten),
                  title: Text(l10n.areaUnitSetting),
                  subtitle: Text(l10n.areaUnitSettingSubtitle),
                  trailing: OutlinedButton.icon(
                    onPressed: () {
                      final idx = units.indexWhere(
                          (u) => u['symbol'] == currentUnit['symbol']);
                      final nextUnit = units[(idx + 1) % units.length];
                      appState
                          .setPreferredAreaUnit(nextUnit['symbol'] as String);
                    },
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text(
                      currentUnit['symbol'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 1),
            const SyncControlCard(showAsCard: false),
            const Divider(height: 1),
            // IHCafe-Verzeichnis: nur im Registrar-Workflow angeboten, damit im
            // Farmer-/Buyer-Workflow kein Speicher belegt wird.
            const IhcafeCatalogCard(),
          ],
        ),
      ),
    );
  }

}
