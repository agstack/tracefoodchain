import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../l10n/app_localizations.dart';

class GpsPositionWidget extends StatefulWidget {
  const GpsPositionWidget({super.key});

  @override
  State<GpsPositionWidget> createState() => _GpsPositionWidgetState();
}

class _GpsPositionWidgetState extends State<GpsPositionWidget> {
  Position? _currentPosition;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isServiceEnabled = false;
  LocationPermission? _permission;
  Timer? _updateTimer;
  bool _hasGpsHardware = true;

  @override
  void initState() {
    super.initState();
    _initializeGps();
    // Update UI every second to refresh timestamp display
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _currentPosition != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeGps() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if location services are enabled
      _isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_isServiceEnabled) {
        setState(() {
          _errorMessage = 'gps_disabled';
          _isLoading = false;
        });
        return;
      }

      // Check location permissions
      _permission = await Geolocator.checkPermission();
      if (_permission == LocationPermission.denied) {
        _permission = await Geolocator.requestPermission();
        if (_permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'permission_denied';
            _isLoading = false;
          });
          return;
        }
      }

      if (_permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'permission_denied_forever';
          _isLoading = false;
        });
        return;
      }

      // Get current position
      await _updatePosition();
    } catch (e) {
      // Check if the error indicates no GPS hardware
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('location') &&
          (errorString.contains('unavailable') ||
              errorString.contains('not available') ||
              errorString.contains('not supported'))) {
        setState(() {
          _hasGpsHardware = false;
          _errorMessage = 'no_gps_hardware';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error initializing GPS: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updatePosition() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting position: $e';
        _isLoading = false;
      });
    }
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy < 5) return Colors.green;
    if (accuracy < 10) return Colors.lightGreen;
    if (accuracy < 20) return Colors.orange;
    return Colors.red;
  }

  String _getAccuracyLabel(double accuracy) {
    if (accuracy < 5) return 'Excellent';
    if (accuracy < 10) return 'Good';
    if (accuracy < 20) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color:
                          _currentPosition != null ? Colors.green : Colors.grey,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GPS Position',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _updatePosition,
                  tooltip: 'Refresh Position',
                ),
              ],
            ),
            const Divider(height: 24),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.plotRegistrationNotPossible,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getErrorMessageText(l10n),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage == 'no_gps_hardware')
                    const SizedBox.shrink()
                  else
                    ElevatedButton.icon(
                      onPressed: _requestGpsAccess,
                      icon: const Icon(Icons.settings),
                      label: Text(
                        _errorMessage == 'permission_denied_forever'
                            ? l10n.openSettingsButton
                            : l10n.enableGpsButton,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                ],
              )
            else if (_currentPosition != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Coordinates
                  _buildInfoRow(
                    Icons.map,
                    'Coordinates',
                    '${_currentPosition!.latitude.toStringAsFixed(6)}, '
                        '${_currentPosition!.longitude.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 12),

                  // Accuracy
                  _buildInfoRow(
                    Icons.gps_fixed,
                    'Accuracy',
                    '${_currentPosition!.accuracy.toStringAsFixed(2)} m',
                    color: _getAccuracyColor(_currentPosition!.accuracy),
                    badge: _getAccuracyLabel(_currentPosition!.accuracy),
                  ),
                  const SizedBox(height: 12),

                  // Altitude
                  if (_currentPosition!.altitude != 0.0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildInfoRow(
                        Icons.terrain,
                        'Altitude',
                        '${_currentPosition!.altitude.toStringAsFixed(1)} m',
                      ),
                    ),

                  // Altitude Accuracy
                  if (_currentPosition!.altitudeAccuracy != 0.0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildInfoRow(
                        Icons.height,
                        'Altitude Accuracy',
                        '${_currentPosition!.altitudeAccuracy.toStringAsFixed(2)} m',
                      ),
                    ),

                  // Speed
                  if (_currentPosition!.speed > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildInfoRow(
                        Icons.speed,
                        'Speed',
                        '${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h',
                      ),
                    ),

                  // Speed Accuracy
                  if (_currentPosition!.speedAccuracy != 0.0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildInfoRow(
                        Icons.speed,
                        'Speed Accuracy',
                        '${_currentPosition!.speedAccuracy.toStringAsFixed(2)} m/s',
                      ),
                    ),

                  // Heading
                  if (_currentPosition!.heading >= 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildInfoRow(
                        Icons.explore,
                        'Heading',
                        '${_currentPosition!.heading.toStringAsFixed(1)}°',
                      ),
                    ),

                  // Heading Accuracy
                  if (_currentPosition!.headingAccuracy != 0.0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildInfoRow(
                        Icons.explore,
                        'Heading Accuracy',
                        '${_currentPosition!.headingAccuracy.toStringAsFixed(2)}°',
                      ),
                    ),

                  const Divider(height: 24),

                  // Timestamp
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Last Update: ${_formatTimestamp(_currentPosition!.timestamp)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
    String? badge,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color?.withOpacity(0.2) ?? Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color ?? Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:'
          '${timestamp.minute.toString().padLeft(2, '0')}:'
          '${timestamp.second.toString().padLeft(2, '0')}';
    }
  }

  String _getErrorMessageText(AppLocalizations l10n) {
    switch (_errorMessage) {
      case 'no_gps_hardware':
        return l10n.deviceHasNoGps;
      case 'gps_disabled':
      case 'permission_denied':
      case 'permission_denied_forever':
        return l10n.gpsDisabledMessage;
      default:
        return _errorMessage ?? 'Unknown error';
    }
  }

  Future<void> _requestGpsAccess() async {
    if (_errorMessage == 'permission_denied_forever') {
      // Open app settings for permission denied forever
      await Geolocator.openAppSettings();
    } else if (_errorMessage == 'gps_disabled') {
      // Try to open location settings
      await Geolocator.openLocationSettings();
      // Wait a bit then retry
      await Future.delayed(const Duration(seconds: 1));
      await _initializeGps();
    } else if (_errorMessage == 'permission_denied') {
      // Retry initialization which will request permission again
      await _initializeGps();
    }
  }
}
