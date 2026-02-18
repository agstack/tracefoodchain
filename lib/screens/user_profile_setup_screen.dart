import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firebase_storage_service.dart';
import '../services/open_ral_service.dart';
import '../services/role_management_service.dart';
import '../services/profile_update_notifier.dart';
import '../repositories/roles.dart';
import '../l10n/app_localizations.dart';
import '../main.dart'; // Für appUserDoc

class UserProfileSetupScreen extends StatefulWidget {
  final bool isFromSettings;

  const UserProfileSetupScreen({
    super.key,
    this.isFromSettings = false,
  });

  @override
  State<UserProfileSetupScreen> createState() => _UserProfileSetupScreenState();
}

class _UserProfileSetupScreenState extends State<UserProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  String? _selectedRole;
  String? _selectedCountry;
  String? _selectedCountryName;
  XFile? _avatarFile;
  String? _avatarUrl;
  bool _isUploading = false;
  bool _isSaving = false;

  final RoleManagementService _roleManagementService = RoleManagementService();
  List<String> _availableRoles = [];
  String? _currentUserRole; // Aktuelle Rolle des Users
  String? _requestedUserRole; // Angeforderte Rolle

  @override
  void initState() {
    super.initState();
    _loadCurrentUserRole();
    _loadAvailableRoles();

    // Always load existing profile data, regardless of how the screen was called
    _loadExistingProfileData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  /// Lädt die aktuelle Rolle des Users und angeforderte Rolle
  void _loadCurrentUserRole() {
    // Lade aktuelle userRole
    final currentRole = _roleManagementService.getCurrentUserRole();

    // Lade angeforderte Rolle aus specificProperties
    String? requestedRole;
    if (appUserDoc != null) {
      final requested =
          getSpecificPropertyfromJSON(appUserDoc!, "requestedUserRole");
      requestedRole = (requested != "" && requested != "-no data found-")
          ? requested
          : null;
    }

    setState(() {
      _currentUserRole = currentRole.isNotEmpty ? currentRole : null;
      _requestedUserRole = requestedRole;
    });
  }

  /// Lädt bestehende Profildaten wenn aus Settings aufgerufen
  Future<void> _loadExistingProfileData() async {
    try {
      final profile = await OpenRALService.getUserProfile();
      debugPrint('Loaded profile data: $profile');

      setState(() {
        // Namen laden
        if (profile.containsKey('firstName')) {
          _firstNameController.text = profile['firstName']!;
          debugPrint('Set firstName: ${profile['firstName']}');
        }
        if (profile.containsKey('lastName')) {
          _lastNameController.text = profile['lastName']!;
          debugPrint('Set lastName: ${profile['lastName']}');
        }

        // Land laden
        if (profile.containsKey('country')) {
          _selectedCountry = profile['country'];
          // TODO: Country name lookup
          _selectedCountryName = profile['country']; // Simplified
          debugPrint('Set country: ${profile['country']}');
        }

        // Avatar URL laden
        if (profile.containsKey('downloadURL')) {
          _avatarUrl = profile['downloadURL'];
          debugPrint('Set avatar URL: ${profile['downloadURL']}');
        }
      });
    } catch (e) {
      // Fehler beim Laden der Profildaten - nicht kritisch
      debugPrint('Error loading profile data: $e');
    }
  }

  /// Lädt die verfügbaren Rollen vom RoleManagementService
  void _loadAvailableRoles() {
    final availableRoles = _roleManagementService.getAvailableRoles();

    setState(() {
      // Filtere nur die Standard-Benutzerrollen für die Registrierung
      // Entferne administrative Rollen und 'KEINE_ROLLE'
      _availableRoles = availableRoles
          .where((role) =>
              role != RoleManagementService.NO_ROLE &&
              role != 'tfcAdmin' &&
              role != 'registrarCoordinator' &&
              role != 'SUPERADMIN')
          .toList();

      // Fallback falls keine Rollen verfügbar sind
      if (_availableRoles.isEmpty) {
        _availableRoles = [
          'Farmer',
          'Trader',
          'Processor',
          'Importer',
          'registrar'
        ];
      }
    });
  }

  /// Build avatar widget that works on all platforms
  Widget _buildAvatarWidget() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      // Show network image
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[300],
        backgroundImage: CachedNetworkImageProvider(_avatarUrl!),
      );
    } else if (_avatarFile != null) {
      // Show local file - handle differently for web and mobile
      if (kIsWeb) {
        return FutureBuilder<Uint8List>(
          future: _avatarFile!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: MemoryImage(snapshot.data!),
              );
            } else {
              return CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                child: const CircularProgressIndicator(),
              );
            }
          },
        );
      } else {
        return FutureBuilder<Uint8List>(
          future: _avatarFile!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: MemoryImage(snapshot.data!),
              );
            } else {
              return CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                child: const CircularProgressIndicator(),
              );
            }
          },
        );
      }
    } else {
      // Show placeholder
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[300],
        child: Icon(
          Icons.person,
          size: 60,
          color: Colors.grey[600],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF35DB00),
        title: Text(
          widget.isFromSettings ? l10n.editProfile : l10n.profileSetup,
          style: const TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        automaticallyImplyLeading:
            widget.isFromSettings, // Back-Button nur in Settings
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome text
              if (!widget.isFromSettings)
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.person_add,
                            size: 48, color: Colors.blue),
                        const SizedBox(height: 16),
                        Text(
                          l10n.welcomeCompleteProfile,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: Colors.black),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.profileSetupDescription,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              if (!widget.isFromSettings) const SizedBox(height: 24),

              // Avatar upload section
              _buildAvatarSection(l10n),
              const SizedBox(height: 24),

              // Personal information
              _buildPersonalInfoSection(l10n),
              const SizedBox(height: 24),

              // Country selection
              _buildCountrySection(l10n),
              const SizedBox(height: 24),

              // Role selection
              _buildRoleSection(l10n),
              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(l10n.saving,
                              style: const TextStyle(color: Colors.black)),
                        ],
                      )
                    : Text(
                        widget.isFromSettings
                            ? l10n.saveChanges
                            : l10n.completeProfile,
                        style:
                            const TextStyle(fontSize: 16, color: Colors.black),
                      ),
              ),
              const SizedBox(height: 16),

              // Skip/Cancel button - nur anzeigen wenn nicht aus Settings
              if (!widget.isFromSettings)
                TextButton(
                  onPressed: _isSaving ? null : _skipForNow,
                  child: Text(
                    l10n.skipForNow,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(AppLocalizations l10n) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profilePicture,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.black),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _isUploading ? null : _pickAndCropAvatar,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _buildAvatarWidget(),
                    if (_isUploading)
                      const Positioned.fill(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.black45,
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    if (!_isUploading)
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.tapToAddPhoto,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection(AppLocalizations l10n) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.personalInformation,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.black),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _firstNameController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: l10n.firstName,
                labelStyle: const TextStyle(color: Colors.black87),
                prefixIcon: const Icon(Icons.person, color: Colors.black87),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.pleaseEnterFirstName;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: l10n.lastName,
                labelStyle: const TextStyle(color: Colors.black87),
                prefixIcon:
                    const Icon(Icons.person_outline, color: Colors.black87),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.pleaseEnterLastName;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountrySection(AppLocalizations l10n) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.nationality,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.black),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectCountry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag, color: Colors.black87),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedCountryName ?? l10n.selectCountry,
                        style: TextStyle(
                          color: _selectedCountryName != null
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.black87),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSection(AppLocalizations l10n) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentUserRole != null ? l10n.role : l10n.selectRole,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.black),
            ),
            const SizedBox(height: 16),

            // Falls bereits eine userRole existiert, zeige sie nur an
            if (_currentUserRole != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getLocalizedRoleName(_currentUserRole!, l10n),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            l10n.yourAssignedRole,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            // Falls noch keine userRole existiert, zeige Dropdown für Rollenanfrage
            else if (_requestedUserRole != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.orange[50],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_empty, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getLocalizedRoleName(_requestedUserRole!, l10n),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            l10n.roleRequestedWaitingApproval,
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            // Neuer Benutzer - zeige Dropdown für Rollenanfrage
            else
              _availableRoles.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.rolesLoading,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          style: const TextStyle(color: Colors.black),
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            labelText: l10n.requestDesiredRole,
                            labelStyle: const TextStyle(color: Colors.black87),
                            prefixIcon:
                                const Icon(Icons.work, color: Colors.black87),
                            border: const OutlineInputBorder(),
                            helperText: l10n.roleRequestMustBeApproved,
                            helperStyle: const TextStyle(color: Colors.black54),
                          ),
                          items: _availableRoles.map((role) {
                            final roleObject = roles.firstWhere(
                              (r) => r.key == role,
                              orElse: () => roles.first, // Fallback
                            );
                            return DropdownMenuItem<String>(
                              value: role,
                              child: Row(
                                children: [
                                  Icon(roleObject.icon, color: Colors.black87),
                                  const SizedBox(width: 8),
                                  Text(
                                    roleObject.getLocalizedName(l10n),
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            setState(() {
                              _selectedRole = value;
                            });
                          },
                          validator: (value) {
                            if (_currentUserRole == null &&
                                _requestedUserRole == null &&
                                (value == null || value.isEmpty)) {
                              return l10n.pleaseSelectRole;
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCropAvatar() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Pick image
      final XFile? pickedFile =
          await FirebaseStorageService.showImageSourceDialog(context);
      if (pickedFile == null) return;

      setState(() {
        _avatarFile = pickedFile;
        _isUploading = true;
      });

      // For web platform, skip cropping as it may not be fully supported
      XFile? finalFile = pickedFile;

      if (!kIsWeb) {
        // Crop image on mobile platforms
        final CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: l10n.cropImage,
              toolbarColor: Theme.of(context).primaryColor,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: l10n.cropImage,
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
            ),
          ],
        );

        if (croppedFile != null) {
          finalFile = XFile(croppedFile.path);
        }
      }

      setState(() {
        _avatarFile = finalFile;
      });

      // Upload to Firebase Storage
      final String? downloadUrl =
          await FirebaseStorageService.uploadUserAvatar(finalFile);

      setState(() {
        _isUploading = false;
        if (downloadUrl != null) {
          _avatarUrl = downloadUrl;
        }
      });

      if (downloadUrl == null) {
        _showErrorSnackBar(l10n.imageUploadError);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showErrorSnackBar(l10n.imageProcessingError(e.toString()));
    }
  }

  /// Hilfsmethode um lokalisierte Rollennamen zu bekommen
  String _getLocalizedRoleName(String role, AppLocalizations l10n) {
    final roleObject = roles.firstWhere(
      (r) => r.key == role,
      orElse: () => Role(
        key: role,
        icon: Icons.work,
        getLocalizedName: (l10n) => role, // Fallback
      ),
    );
    return roleObject.getLocalizedName(l10n);
  }

  void _selectCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country.countryCode;
          _selectedCountryName = country.name;
        });
      },
    );
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCountry == null) {
      _showErrorSnackBar(l10n.pleaseSelectCountry);
      return;
    }

    // Falls bereits eine userRole existiert oder eine Rolle angefordert wurde,
    // ist keine Rollenauswahl erforderlich
    if (_currentUserRole == null &&
        _requestedUserRole == null &&
        _selectedRole == null) {
      _showErrorSnackBar(l10n.pleaseSelectRole);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Update openRAL user object - speichere requestedUserRole statt userRole
      await OpenRALService.updateUserProfileWithRoleRequest(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        requestedRole:
            _selectedRole, // Kann null sein wenn bereits Rolle existiert
        country: _selectedCountry!,
        avatarUrl: _avatarUrl,
      );

      // Notify that profile was updated
      ProfileUpdateNotifier().notifyProfileUpdated();

      // Navigate based on context
      if (mounted) {
        if (widget.isFromSettings) {
          // From settings - go back to previous screen
          Navigator.of(context).pop();
        } else {
          // From sign-up - go to main app
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    } catch (e) {
      _showErrorSnackBar(l10n.profileSaveError(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _skipForNow() {
    // Navigate to main app without saving profile
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
