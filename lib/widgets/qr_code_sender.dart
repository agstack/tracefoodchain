//This widget now works on both Flutter and Flutter Web using the archive package for compression.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';

enum QrErrorCorrectLevel { L, M, Q, H }

extension QrErrorCorrectLevelExtension on QrErrorCorrectLevel {
  int get value {
    switch (this) {
      case QrErrorCorrectLevel.L:
        return 1;
      case QrErrorCorrectLevel.M:
        return 0;
      case QrErrorCorrectLevel.Q:
        return 3;
      case QrErrorCorrectLevel.H:
        return 2;
    }
  }
}

int moveSpeed = 300; // Default display time 300ms
int chunkSize = 500; // Default chunk size 500 bytes

class QRCodeSender extends StatefulWidget {
  final String data;

  const QRCodeSender({super.key, required this.data});

  @override
  _QRCodeSenderState createState() => _QRCodeSenderState();
}

class _QRCodeSenderState extends State<QRCodeSender> {
  // Add new state variable
  QrErrorCorrectLevel _errorCorrectLevel =
      QrErrorCorrectLevel.M; // Set to Medium
  List<String> _chunks = [];
  int _currentChunkIndex = 0;
  Timer? _timer;
  double _currentSpeed = moveSpeed.toDouble();
  final double _qrSize = 400.0;
  String _cycleTime = '';
  DateTime? _cycleStartTime;
  bool _cycleMeasured = false;
  double _currentChunkSize = chunkSize.toDouble();
  bool _isInPause = false;

  @override
  void initState() {
    super.initState();
    _chunks = _splitData(widget.data);
    // Set maximum brightness when QR sender starts
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    _startQRMovie(); // Starte QR Movie automatisch beim Öffnen
  }

  List<String> _splitData(String data) {
    // Compress and encode the data using archive package (works on all platforms)
    final minifiedJson = json.encode(json.decode(data)); // Minify JSON
    final utf8Data = utf8.encode(minifiedJson);
    final compressed = GZipEncoder().encode(utf8Data);
    final base64Data = base64.encode(Uint8List.fromList(compressed!));

    return List.generate(
      (base64Data.length / chunkSize).ceil(),
      (index) {
        final start = index * chunkSize;
        final end = (index + 1) * chunkSize;
        String chunk = base64Data.substring(
            start, end > base64Data.length ? base64Data.length : end);
        if (chunk.length < chunkSize) {
          chunk = chunk.padRight(chunkSize);
        }
        return '${index + 1}/${(base64Data.length / chunkSize).ceil()}:$chunk';
      },
    );
  }

  void _startQRMovie() {
    _currentChunkIndex = 0;
    _cycleMeasured = false;
    _cycleTime = '';
    _isInPause = false;

    _timer = Timer.periodic(Duration(milliseconds: moveSpeed), (timer) {
      setState(() {
        if (_isInPause) {
          _isInPause = false;
          _currentChunkIndex = 0;
          return;
        }

        // Start measuring at first chunk
        if (_currentChunkIndex == 0 && !_cycleMeasured) {
          _cycleStartTime = DateTime.now();
        }

        _currentChunkIndex++;

        // When reaching last chunk
        if (_currentChunkIndex >= _chunks.length) {
          if (!_cycleMeasured) {
            final cycleEndTime = DateTime.now();
            final cycleDuration = cycleEndTime.difference(_cycleStartTime!);
            _cycleTime =
                '${cycleDuration.inSeconds}.${(cycleDuration.inMilliseconds % 1000).toString().padLeft(3, '0')}s';
            _cycleMeasured = true;
          }
          _currentChunkIndex = _chunks.length - 1; // Stay on last frame
          _isInPause = true; // Enter pause state
        }
      });
    });
  }

  void _stopQRMovie() {
    _timer?.cancel();
    _timer = null;
    _cycleStartTime = null;
  }

  void _updateSpeed(double newSpeed) {
    setState(() {
      _currentSpeed = newSpeed;
      moveSpeed = newSpeed.toInt();
      if (_timer != null) {
        _stopQRMovie();
        _startQRMovie();
      }
    });
  }

  void _updateChunkSize(double newSize) {
    setState(() {
      _currentChunkSize = newSize;
      chunkSize = newSize.toInt();
      _chunks = _splitData(widget.data); // Regenerate chunks with new size
      if (_timer != null) {
        _stopQRMovie();
        _startQRMovie();
      }
    });
  }

  void _updateErrorCorrection(QrErrorCorrectLevel? newLevel) {
    if (newLevel != null) {
      setState(() {
        _errorCorrectLevel = newLevel;
      });
    }
  }

  @override
  void dispose() {
    // Restore system UI when widget is disposed
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _stopQRMovie();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: Colors.black, // Add black background for better contrast
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_timer != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 20),
              ),
              child: SizedBox(
                height: _qrSize,
                width: _qrSize,
                child: QrImageView(
                  data: _chunks[_currentChunkIndex],
                  version: QrVersions.auto,
                  size: _qrSize,
                  errorCorrectionLevel:
                      _errorCorrectLevel.value, // Convert enum to int
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF000000),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF000000),
                  ),
                ),
              ),
            )
          else
            Text(
              l10n.waitingForData,
              style: const TextStyle(color: Colors.white),
            ),
          const SizedBox(height: 20),
          if (_cycleTime.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Cycle Time: $_cycleTime',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (kDebugMode)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Speed: ',
                            style: TextStyle(color: Colors.white)),
                        Slider(
                          value: _currentSpeed,
                          min: 300,
                          max: 2000,
                          divisions: 17,
                          label: '${_currentSpeed.round()} ms',
                          onChanged: _updateSpeed,
                        ),
                        Text(
                          '${_currentSpeed.round()} ms',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Chunk Size: ',
                            style: TextStyle(color: Colors.white)),
                        Slider(
                          value: _currentChunkSize,
                          min: 100,
                          max: 1000,
                          divisions: 9,
                          label: '${_currentChunkSize.round()} bytes',
                          onChanged: _updateChunkSize,
                        ),
                        Text(
                          '${_currentChunkSize.round()} bytes',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Error Correction: ',
                            style: TextStyle(color: Colors.white)),
                        DropdownButton<QrErrorCorrectLevel>(
                          value: _errorCorrectLevel,
                          dropdownColor: Colors.black87,
                          items: const [
                            DropdownMenuItem(
                              value: QrErrorCorrectLevel.L,
                              child: Text('Low (7%)',
                                  style: TextStyle(color: Colors.white)),
                            ),
                            DropdownMenuItem(
                              value: QrErrorCorrectLevel.M,
                              child: Text('Medium (15%)',
                                  style: TextStyle(color: Colors.white)),
                            ),
                            DropdownMenuItem(
                              value: QrErrorCorrectLevel.Q,
                              child: Text('Quartile (25%)',
                                  style: TextStyle(color: Colors.white)),
                            ),
                            DropdownMenuItem(
                              value: QrErrorCorrectLevel.H,
                              child: Text('High (30%)',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                          onChanged: _updateErrorCorrection,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _stopQRMovie();
              Navigator.of(context).pop(); // Fenster sofort schließen
            },
            child: Text(l10n.stopPresenting), // Zeige immer "stopPresenting"
          ),
        ],
      ),
    );
  }
}
