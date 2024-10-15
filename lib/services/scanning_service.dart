import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';

class ScanningService {
  static Future<String?> showScanDialog(
      BuildContext context, AppState appState) async {
    String scannedCode = '';
    bool isScanning = false;
    ValueNotifier<String?> scannedNFCCode = ValueNotifier<String?>(null);
    ValueNotifier<String?> nfcButtonText = ValueNotifier<String?>(null);

    nfcButtonText.value = AppLocalizations.of(context)!.startScanning;

    return showDialog<String>(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context),
        child: StatefulBuilder(
          builder: (context, setInnerState) {
            List<Widget> tabs = [];
            List<Widget> tabViews = [];

            if (appState.hasCamera) {
              tabs.add(Tab(text: AppLocalizations.of(context)!.qrCode));
              tabViews.add(
                _buildQRCodeScanner(setInnerState, (code) {
                  scannedCode = code;
                }),
              );
            }

            if (appState.hasNFC) {
              tabs.add(Tab(text: AppLocalizations.of(context)!.nfcTag));
              tabViews.add(
                _buildNFCScanner(context, setInnerState, appState, isScanning,
                    nfcButtonText, scannedNFCCode, (code) {
                  scannedCode = code;
                }),
              );
            }

            tabs.add(Tab(text: "Manual"));
            tabViews.add(
              _buildManualInput((code) {
                scannedCode = code;
              }),
            );

            return AlertDialog(
              title: Text(
                AppLocalizations.of(context)!.scanQrCodeOrNfcTag,
                style: TextStyle(color: Colors.black54),
              ),
              content: Container(
                width: 300,
                height: 400,
                child: DefaultTabController(
                  length: tabs.length,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TabBar(
                        tabs: tabs,
                      ),
                      Expanded(
                        child: TabBarView(
                          children: tabViews,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                //Cancel process
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.cancel,
                      style: TextStyle(color: Colors.black)),
                ),
                // Confirm scanned code
                ElevatedButton(
                  onPressed: () {
                    if (scannedCode.isNotEmpty &&
                        scannedCode !=
                            AppLocalizations.of(context)!.scanningForNfcTags) {
                      Navigator.pop(context, scannedCode);
                    } else if (scannedNFCCode.value != null) {
                      Navigator.pop(context, scannedNFCCode.value);
                    } else
                      fshowInfoDialog(context, "Please provide code first!");
                  },
                  child: Text(AppLocalizations.of(context)!.confirm,
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Widget _buildQRCodeScanner(
      StateSetter setState, Function(String) onCodeScanned) {
    String localScannedCode = '';
    return StatefulBuilder(
      builder: (context, setInnerState) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 200,
              width: 200,
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    setInnerState(() {
                      localScannedCode = barcode.rawValue ?? '';
                      onCodeScanned(localScannedCode);
                    });
                  }
                },
              ),
            ),
            SizedBox(height: 20),
            Text(localScannedCode, style: TextStyle(color: Colors.black54)),
          ],
        );
      },
    );
  }

  static Widget _buildNFCScanner(
      BuildContext context,
      StateSetter setState,
      AppState appState,
      bool isScanning,
      ValueNotifier<String?> nfcButtonText,
      ValueNotifier<String?> scannedNFCCode,
      Function(String) onCodeScanned) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () async {
              if (!isScanning) {
                isScanning = true;
                nfcButtonText.value =
                    AppLocalizations.of(context)!.stopScanning;
                await _startNfcScan(context, setState, (code) {
                  nfcButtonText.value =
                      AppLocalizations.of(context)!.startScanning;
                  scannedNFCCode.value = code;
                  onCodeScanned(code);
                  isScanning = false;
                }, appState);
              } else {
                setState(() {
                  isScanning = false;
                  scannedNFCCode.value = "";
                });
              }
            },
            child: ValueListenableBuilder(
              valueListenable: nfcButtonText,
              builder: (context, String? value, child) {
                return Text(value!, style: TextStyle(color: Colors.black));
              },
            ),
          ),
        ),
        SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: ValueListenableBuilder(
              valueListenable: scannedNFCCode,
              builder: (context, String? value, child) {
                return Text(value ?? "",
                    style: TextStyle(color: Colors.black54));
              },
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> _startNfcScan(BuildContext context, StateSetter setState,
      Function(String) onCodeScanned, AppState appState) async {
    try {
      if (!appState.hasNFC) {
        onCodeScanned(AppLocalizations.of(context)!.nfcNotAvailable);
        return;
      }

      while (true) {
        NFCTag tag = await FlutterNfcKit.poll(
          timeout: Duration(seconds: 10),
          iosMultipleTagMessage: AppLocalizations.of(context)!.multiTagFoundIOS,
          iosAlertMessage: AppLocalizations.of(context)!.scanInfoMessageIOS,
        );

        onCodeScanned(tag.id);
        await FlutterNfcKit.finish();
      }
    } catch (e) {
      debugPrint(
          "${AppLocalizations.of(context)!.nfcScanError}: ${e.toString()}");
    }
  }

  static Widget _buildManualInput(Function(String) onCodeScanned) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              style: TextStyle(color: Colors.black),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintStyle: TextStyle(color: Colors.black54),
                hintText: 'Enter UID here',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                onCodeScanned(value);
              },
            ),
          ),
          //ToDo: Check if containers are availabe to show
          Container(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all<Color>(Colors.grey)),
                onPressed: () {
                  //ToDo: Display all available containers
                },
                child: Text("Select from database",
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          )
        ],
      ),
    );
  }
}