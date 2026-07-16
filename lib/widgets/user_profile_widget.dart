import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/open_ral_service.dart';
import '../services/profile_update_notifier.dart';
import '../screens/user_profile_view_screen.dart';

class UserProfileWidget extends StatefulWidget {
  const UserProfileWidget({super.key});

  @override
  State<UserProfileWidget> createState() => _UserProfileWidgetState();
}

class _UserProfileWidgetState extends State<UserProfileWidget> {
  Map<String, String> _userProfile = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    // Listen to profile updates
    ProfileUpdateNotifier().profileUpdateNotifier.addListener(_onProfileUpdate);
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    ProfileUpdateNotifier()
        .profileUpdateNotifier
        .removeListener(_onProfileUpdate);
    super.dispose();
  }

  /// Called when profile update is notified
  void _onProfileUpdate() {
    if (mounted) {
      debugPrint('UserProfileWidget: Profile update notified, reloading...');
      _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    debugPrint('UserProfileWidget: Starting to load user profile...');
    try {
      final profile = await OpenRALService.getUserProfile();
      debugPrint('UserProfileWidget: Received profile: $profile');
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
        debugPrint('UserProfileWidget: Profile loaded successfully');
      }
    } catch (e) {
      debugPrint('UserProfileWidget: Error loading profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToProfile() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => const UserProfileViewScreen(),
      ),
    )
        .then((_) {
      // Reload profile after navigation back
      _loadUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final avatarUrl = _userProfile['downloadURL'];
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey[300],
      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
          ? CachedNetworkImageProvider(avatarUrl)
          : null,
      child: (avatarUrl == null || avatarUrl.isEmpty)
          ? Icon(
              Icons.person,
              size: 16,
              color: Colors.grey[600],
            )
          : null,
    );

    // Das AppBar-Leading ist auf kToolbarHeight (56px) begrenzt, daher passt
    // nur der Avatar hinein.
    return GestureDetector(
      onTap: _navigateToProfile,
      child: Center(child: avatar),
    );
  }
}
