import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import '../l10n/app_localizations.dart';
import 'package:archive/archive.dart';

bool _isProcessing = false;

class QRCodeReceiver extends StatefulWidget {
  const QRCodeReceiver({super.key});

  @override
  _QRCodeReceiverState createState() => _QRCodeReceiverState();
}

class _QRCodeReceiverState extends State<QRCodeReceiver> {
  final Map<int, String> _receivedChunks = {};
  int _totalChunks = 0;
  bool _isReceiving = true;
  DateTime? _startTime; // Neue Variable für Zeitmessung

  void _processScannedCode(String? code) {
    if (!_isReceiving || _isProcessing) return;

    if (code != null && code.contains(':')) {
      _isProcessing = true;

      try {
        // Startzeit beim ersten Chunk setzen
        if (_receivedChunks.isEmpty) {
          _startTime = DateTime.now();
        }

        int colonIndex = code.indexOf(':');
        final headerAll = code.substring(0, colonIndex);
        String payload = code.substring(colonIndex + 1);
        final header = headerAll.split('/');
        final chunkIndex = int.parse(header[0]);
        _totalChunks = int.parse(header[1]);

        if (chunkIndex < 1 || chunkIndex > _totalChunks) {
          debugPrint('Ungültiger Chunk-Index: $chunkIndex');
          return;
        }

        if (!_receivedChunks.containsKey(chunkIndex)) {
          _receivedChunks[chunkIndex] = payload;
          setState(() {});

          // Automatische Verarbeitung wenn alle Chunks da sind
          if (_canProcess()) {
            _assembleData();
          }
        }
      } catch (e) {
        debugPrint('Fehler beim Verarbeiten des Chunks: $e');
      } finally {
        _isProcessing = false;
      }
    }
  }

  bool _canProcess() {
    if (_totalChunks == 0) return false;

    for (int i = 1; i <= _totalChunks; i++) {
      if (!_receivedChunks.containsKey(i)) return false;
    }
    return true;
  }

  void _assembleData() {
    try {
      final assembledData = List.generate(_totalChunks, (index) {
        final chunk = _receivedChunks[index + 1];
        if (chunk == null) {
          throw Exception('Fehlender Chunk at ${index + 1}');
        }
        return chunk;
      }).join();

      // Decode and decompress data using archive package
      final bytes = base64.decode(assembledData.trim());
      final decompressed = GZipDecoder().decodeBytes(bytes);
      final decompressedString = utf8.decode(decompressed);
      final decodedData = json.decode(decompressedString);

      // Zeitmessung beenden und Dauer berechnen
      final duration = _startTime != null
          ? DateTime.now().difference(_startTime!)
          : Duration.zero;

      setState(() {
        _isReceiving = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (kDebugMode) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Processing complete',
                  style: TextStyle(color: Colors.black)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Processing time: ${duration.inSeconds}.${duration.inMilliseconds % 1000}s',
                      style: const TextStyle(color: Colors.black)),
                  const SizedBox(height: 8),
                  Text('Received data size: ${assembledData.length} bytes',
                      style: const TextStyle(color: Colors.black)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(decodedData);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          Navigator.of(context).pop(decodedData);
        }
      });
    } catch (e) {
      debugPrint('Fehler beim Assemblieren: $e');
      fshowInfoDialog(context, AppLocalizations.of(context)!.noDataAvailable);
    }
  }

  void _resetReceiver() {
    setState(() {
      _receivedChunks.clear();
      _totalChunks = 0;
      _isReceiving = true;
      _startTime = null; // Startzeit zurücksetzen
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Expanded(
          child: _isReceiving
              ? Stack(
                  children: [
                    MobileScanner(
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          _processScannedCode(barcode.rawValue);
                        }
                      },
                    ),
                    CustomPaint(
                      painter: QRFramePainter(),
                      size: Size.infinite,
                      child: Container(),
                    ),
                  ],
                )
              : Center(child: Text(l10n.dataReceived)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
              '${l10n.dataReceived} ${_receivedChunks.length} ${l10n.next} $_totalChunks chunks',
              style: const TextStyle(color: Colors.black)),
        ),
        Row(
          mainAxisAlignment:
              MainAxisAlignment.center, // von spaceEvenly zu center geändert
          children: [
            ElevatedButton(
              onPressed: _resetReceiver,
              child: Text(l10n.scan),
            ),
            // Verarbeitungs-Button entfernt
          ],
        ),
      ],
    );
  }
}

class QRFramePainter extends CustomPainter {
  final double cornerLength;
  final double strokeWidth;

  QRFramePainter({
    this.cornerLength = 30.0,
    this.strokeWidth = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final double frameSize = size.shortestSide * 0.8;
    final double left = (size.width - frameSize) / 2;
    final double top = (size.height - frameSize) / 2;

    // Oben links
    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      paint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      paint,
    );

    // Oben rechts
    canvas.drawLine(
      Offset(left + frameSize - cornerLength, top),
      Offset(left + frameSize, top),
      paint,
    );
    canvas.drawLine(
      Offset(left + frameSize, top),
      Offset(left + frameSize, top + cornerLength),
      paint,
    );

    // Unten links
    canvas.drawLine(
      Offset(left, top + frameSize - cornerLength),
      Offset(left, top + frameSize),
      paint,
    );
    canvas.drawLine(
      Offset(left, top + frameSize),
      Offset(left + cornerLength, top + frameSize),
      paint,
    );

    // Unten rechts
    canvas.drawLine(
      Offset(left + frameSize - cornerLength, top + frameSize),
      Offset(left + frameSize, top + frameSize),
      paint,
    );
    canvas.drawLine(
      Offset(left + frameSize, top + frameSize - cornerLength),
      Offset(left + frameSize, top + frameSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
