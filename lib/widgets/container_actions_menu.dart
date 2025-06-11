import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/widgets/items_list_widget.dart';
import 'package:trace_foodchain_app/widgets/online_sale_dialog.dart';
import 'package:trace_foodchain_app/widgets/shared_widgets.dart';
import 'package:trace_foodchain_app/widgets/stepper_sell_coffee.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Only import dart:html on web.
//import 'dart:html' as html;

class ContainerActionsMenu extends StatefulWidget {
  final Map<String, dynamic> container;
  final List<Map<String, dynamic>> contents;
  final Function(List<String>) onPerformAnalysis;
  final Function(List<Map<String, dynamic>>, double, String)
      onGenerateAndSharePdf;
  final Function() onRepaint;
  final bool isConnected;
  final Function(String) onDeleteContainer;

  const ContainerActionsMenu({
    super.key,
    required this.container,
    required this.contents,
    required this.onPerformAnalysis,
    required this.onGenerateAndSharePdf,
    required this.onRepaint,
    required this.isConnected,
    required this.onDeleteContainer,
  });

  @override
  _ContainerActionsMenuState createState() => _ContainerActionsMenuState();
}

class _ContainerActionsMenuState extends State<ContainerActionsMenu> {
  bool _isBuilding = false;
  final ValueNotifier<bool> rebuildDDS = ValueNotifier<bool>(false);
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert, color: Colors.black54),
      surfaceTintColor: Colors.white,
      tooltip: "",
      itemBuilder: (context) => [
        PopupMenuItem(
          child: ListTile(
            leading: Image.asset(
              'assets/images/cappuccino.png',
              width: 24,
              height: 24,
            ),
            title: Text(l10n.buyCoffee,
                style: const TextStyle(color: Colors.black)),
            onTap: () => _buyCoffeeForContainer(context),
          ),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: const Icon(Icons.shopping_cart, size: 20),
            title: Text(l10n.sellOffline,
                style: const TextStyle(color: Colors.black)),
            onTap: () => _sellContainerOffline(context, widget.container),
          ),
        ),
        if (widget.isConnected && widget.container["needsSync"] == null)
          // if (widget.isConnected ) //! DEBUG ONLY
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.shopping_cart, size: 20),
              title: Text(l10n.sellOnline,
                  style: const TextStyle(color: Colors.black)),
              onTap: () async {
                Navigator.pop(context, "close menu");
                //1. Add selected item to the outgoing items list
                List<Map<String, dynamic>> outgoingItems = [widget.container];
                //2. Add nested Items
                final nestedItems =
                    await _databaseHelper.getNestedContainedItems(
                        getObjectMethodUID(widget.container));
                for (final item in nestedItems) {
                  outgoingItems.add(item);
                }

                for (final item in outgoingItems) {
                  if (item["needsSync"] != null) {
                    await fshowInfoDialog(context, l10n.syncError);
                    return;
                  }
                }

                if (outgoingItems.isNotEmpty) {
                  await showDialog(
                    context: context,
                    builder: (context) =>
                        OnlineSaleDialog(itemsToSell: outgoingItems),
                  );
                } else {
                  await fshowInfoDialog(context, l10n.selectItemToSell);
                }

                widget.onRepaint();
              },
            ),
          ),
        PopupMenuItem(
          child: ListTile(
              leading: const Icon(Icons.swap_horiz, size: 20),
              title: Text(l10n.changeLocation,
                  style: const TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context, "close menu");
                showChangeContainerDialog(context, widget.container);
                widget.onRepaint();
              }),
        ),
        PopupMenuItem(
          child: Builder(
            builder: (context) {
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf, size: 20),
                title: ValueListenableBuilder(
                  valueListenable: rebuildDDS,
                  builder: (context, bool value, child) {
                    rebuildDDS.value = false;
                    return _isBuilding
                        ? const SizedBox(
                            width: 10,
                            child: CircularProgressIndicator(
                              color: Color(0xFF35DB00),
                            ),
                          )
                        : Text(l10n.generateDDS,
                            style: const TextStyle(color: Colors.black));
                  },
                ),
                onTap: () => _generateDDS(context),
              );
            },
          ),
        ),
        PopupMenuItem(
          child: ListTile(
              leading: const Icon(Icons.table_chart, size: 20),
              title: Text(l10n.exportToExcel,
                  style: const TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.pop(context, "close menu");
                _generateExcel(context);
                widget.onRepaint();
              }),
        ),
        if (kDebugMode)
          PopupMenuItem(
            child: ListTile(
              leading: const Icon(Icons.delete_forever, size: 20),
              title: Text(l10n.debugDeleteContainer,
                  style: const TextStyle(color: Colors.black)),
              onTap: () => _deleteContainer(context),
            ),
          ),
      ],
    );
  }

  Future<void> _generateExcel(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    // Generate and Download data as Excel file
    // GeoID along with the corresponding data.
    // Each purchase is recorded as a single line, with details such as quantity, unit, and processing state at time of purchase.
    var excel = Excel.createExcel();
    var sheet = excel.sheets[excel.getDefaultSheet()];

    // Add header row
    // sheet.appendRow(['GeoID', 'Species', 'Amount', 'Unit', 'Processing State']);
    // Definiere die Spaltenüberschriften
    final headers = [
      "GeoID",
      l10n.species,
      l10n.amount2,
      l10n.unit,
      l10n.processingState,
      l10n.weightEquivalentGreenBeanKg
    ];

    // Füge die Spaltenüberschriften in Zeile 3 ein
    for (var i = 0; i < headers.length; i++) {
      sheet!.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = headers[i] as dynamic;
    }
    // Process each coffee item and add its data as a row in the Excel file
    for (final coffee in widget.contents) {
      Map<String, dynamic> firstSale =
          await _databaseHelper.getFirstSale(context, coffee);
      if (firstSale.isNotEmpty) {
        final field = firstSale["inputObjects"][1];
        final geoID = field["identity"]["alternateIDs"][0]["UID"]
            .replaceAll(RegExp(r'\s+'), '');

        // Get the initial state details at the time of purchase
        Map<String, dynamic> coffeeInitialState =
            Map<String, dynamic>.from(firstSale["outputObjects"][0]);
        // Optionally, you can use coffeeCurrentState later if needed:
        Map<String, dynamic> coffeeCurrentState =
            await getObjectMethod(getObjectMethodUID(coffeeInitialState));
        final species =
            getSpecificPropertyfromJSON(coffeeInitialState, "species");
        final amount =
            getSpecificPropertyfromJSON(coffeeInitialState, "amount");
        final unit =
            getSpecificPropertyUnitfromJSON(coffeeInitialState, "amount");
        final processingState =
            getSpecificPropertyfromJSON(coffeeInitialState, "processingState");
        final convertedAmount = convertToGreenBeanEquivalent(
            Map<String, dynamic>.from(coffeeInitialState), "kg");
        // Append a new row with extracted data
        final rowIndex = sheet!.maxRows;
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            geoID);
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            species);
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            amount);
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            unit);
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
            processingState);
        sheet.updateCell(
            CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
            convertedAmount.toStringAsFixed(2));
      }
    }

    // Encode the file into bytes
    final List<int>? fileBytes = excel.encode();
    if (fileBytes != null) {
      if (kIsWeb) {
        // // For Flutter Web: initiate a download using a blob.
        // final blob = html.Blob([fileBytes]);
        // final url = html.Url.createObjectUrlFromBlob(blob);
        // final anchor = html.AnchorElement(href: url)
        //   ..download =
        //       'content_of_${truncateUID(widget.container["identity"]["alternateIDs"][0]["UID"])}.xlsx'
        //   ..click();
        // html.Url.revokeObjectUrl(url);
        // await fshowInfoDialog(context, l10n.excelFileDownloaded);
      } else {
        // For mobile or desktop: save the file to the application's documents directory.
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/tracefoodchain_data.xlsx';
        final file = File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        debugPrint("Excel file saved: $filePath");
        await fshowInfoDialog(context, "${l10n.excelFileSavedAt}: $filePath");
      }
    } else {
      debugPrint("Failed to generate Excel file.");
      await fshowInfoDialog(context, l10n.failedToGenerateExcelFile);
    }
  }

  Future<void> _generateDDS(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isBuilding = true;
      rebuildDDS.value = true;
    });

    List<String> plotList = [];
    String? reportingUnit = "kg";
    double? reportingAmount;
    for (final coffee in widget.contents) {
      Map<String, dynamic> firstSale = Map<String, dynamic>.from(
          await _databaseHelper.getFirstSale(context, coffee));
      final field = firstSale["inputObjects"][1];
      plotList.add(field["identity"]["alternateIDs"][0]["UID"].replaceAll(
          RegExp(r'\s+'),
          '')); //This is because some CIAT cards have a space in the UID
      debugPrint(field["identity"]["alternateIDs"][0]["UID"]);
      //ToDo: Get amount and unit and processing state.
      //ToDo: Calculate the amount and unit as it would be in green bean equivalent.
      // debugPrint(
      //     "Amount old: ${getSpecificPropertyfromJSON(Map<String, dynamic>.from(firstSale["outputObjects"][0]), "amount")}");
      // debugPrint(
      //     "Unit old : ${getSpecificPropertyUnitfromJSON(Map<String, dynamic>.from(firstSale["outputObjects"][0]), "amount")}");
      final convertedAmount = convertToGreenBeanEquivalent(
          Map<String, dynamic>.from(firstSale["outputObjects"][0]),
          reportingUnit); //Converts the amount to green bean equivalent and into the right unit for reporting
      // debugPrint("Amount new: $convertedAmount");
      // debugPrint("Unit new: $reportingUnit");
      reportingAmount = reportingAmount == null
          ? convertedAmount
          : reportingAmount + convertedAmount;
    }

    await fshowInfoDialog(context, l10n.ddsGenerationDemo);

    final results = await widget.onPerformAnalysis(plotList);
    await widget.onGenerateAndSharePdf(
        results, reportingAmount!, reportingUnit);
    _isBuilding = false;
    rebuildDDS.value = true;
    if (mounted) {
      setState(() {});
    }

    Navigator.pop(context, "close menu");
  }

  void _buyCoffeeForContainer(BuildContext context) async {
    Navigator.of(context).pop();
    await showBuyCoffeeOptions(
      context,
      receivingContainerUID: widget.container["identity"]["alternateIDs"][0]
          ["UID"],
    );
    widget.onRepaint();
  }

  void _sellContainerOffline(
      BuildContext context, Map<String, dynamic> container) async {
    Navigator.pop(context, "close menu");
    final currentContainerUID =
        container["currentGeolocation"]["container"]["UID"];
    Map<String, dynamic> oldContainer =
        await getObjectMethod(currentContainerUID);
    StepperSellCoffee sellCoffeeProcess = StepperSellCoffee();
    await sellCoffeeProcess.startProcess(
        context, container, appUserDoc!, oldContainer);
    widget.onRepaint();
  }

  void _deleteContainer(BuildContext context) async {
    Navigator.pop(context, "close menu");
    await widget.onDeleteContainer(widget.container["identity"]["UID"]);
    for (var content in widget.contents) {
      await widget.onDeleteContainer(content["identity"]["UID"]);
    }
    widget.onRepaint();
  }
}
