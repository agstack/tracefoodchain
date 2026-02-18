import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/open_ral_service.dart';
import '../l10n/app_localizations.dart';
import '../repositories/roles.dart';
import 'user_profile_setup_screen.dart';

class UserProfileViewScreen extends StatefulWidget {
  const UserProfileViewScreen({super.key});

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  Map<String, String> _userProfile = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await OpenRALService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToEditProfile() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                const UserProfileSetupScreen(isFromSettings: true),
          ),
        )
        .then((_) => _loadUserProfile()); // Reload profile after editing
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF35DB00),
        title: Text(
          l10n.profileSetup,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _navigateToEditProfile,
            tooltip: l10n.editProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar Section
                  _buildAvatarSection(),
                  const SizedBox(height: 32),

                  // Personal Information
                  _buildInfoCard(
                    title: l10n.personalInformation,
                    children: [
                      _buildInfoRow(Icons.person, l10n.firstName,
                          _userProfile['firstName'] ?? l10n.notSpecified),
                      _buildInfoRow(Icons.person_outline, l10n.lastName,
                          _userProfile['lastName'] ?? l10n.notSpecified),
                      _buildInfoRow(Icons.email, 'Email',
                          _userProfile['emailAddress'] ?? l10n.notSpecified),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Role and Location
                  _buildInfoCard(
                    title: l10n.roleAndLocation,
                    children: [
                      _buildInfoRow(Icons.work, l10n.role,
                          _getRoleDisplayName(_userProfile['userRole'])),
                      _buildInfoRow(Icons.flag, l10n.nationality,
                          _userProfile['country'] ?? l10n.notSpecified),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Edit Profile Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _navigateToEditProfile,
                      icon: const Icon(Icons.edit),
                      label: Text(
                        l10n.editProfile,
                        style: const TextStyle(color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    final avatarUrl = _userProfile['downloadURL'];
    final fullName = _userProfile['fullName'] ??
        '${_userProfile['firstName'] ?? ''} ${_userProfile['lastName'] ?? ''}'
            .trim();

    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey[300],
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? CachedNetworkImageProvider(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.grey[600],
                )
              : null,
        ),
        const SizedBox(height: 16),
        if (fullName.isNotEmpty)
          Text(
            fullName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildInfoCard(
      {required String title, required List<Widget> children}) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isEmpty
                  ? AppLocalizations.of(context)!.notSpecified
                  : value,
              style: TextStyle(
                color: value.isEmpty ? Colors.grey[600] : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDisplayName(String? role) {
    final l10n = AppLocalizations.of(context)!;
    if (role == null || role.isEmpty) return l10n.notSpecified;

    final roleObject = roles.firstWhere(
      (r) => r.key == role,
      orElse: () => Role(
        key: role,
        icon: Icons.work,
        getLocalizedName: (_) => role,
      ),
    );
    return roleObject.getLocalizedName(l10n);
  }
}
