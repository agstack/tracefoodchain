import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import '../l10n/app_localizations.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import 'package:trace_foodchain_app/widgets/add_empty_item_dialog.dart';
import 'package:trace_foodchain_app/widgets/items_list_widget.dart';
import 'package:trace_foodchain_app/widgets/shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart'; // Neuer Import

class RoleBasedSpeedDial extends StatefulWidget {
  final String displayContext;

  const RoleBasedSpeedDial({super.key, required this.displayContext});

  @override
  State<RoleBasedSpeedDial> createState() => _RoleBasedSpeedDialState();
}

class _RoleBasedSpeedDialState extends State<RoleBasedSpeedDial> {
  @override
  void initState() {
    super.initState();
  }

  String _getHelpUrl(String languageCode) {
    switch (languageCode) {
      case 'de':
        return 'https://docs.google.com/document/d/1wURF_uGIW3eKHh1qEn380_JE5tOdOyZRfFRQuL46Hn0';
      case 'es':
        return 'https://docs.google.com/document/d/1IVqaR_mJkQKbVobJfYM_EUxYCpd5B5qel0mY2U_KPVg';
      case 'fr':
        return 'https://docs.google.com/document/d/19Z0dMR6CqHqaT2nU9qM4uzHftNFlIeZpd2AlyuHngP4';
      default:
        return "https://docs.google.com/document/d/1JcNxTNEs6nkTDotVzFw-AFU0arB6T8aI1BfzKAuDF0A";
    }
  }

  Future<void> _launchHelp() async {
    final locale = Localizations.localeOf(context);
    final Uri url = Uri.parse(_getHelpUrl(locale.languageCode));
    if (!await launchUrl(url)) {
      await fshowInfoDialog(
          context, AppLocalizations.of(context)!.errorOpeningUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder(
        valueListenable: rebuildSpeedDial,
        builder: (context, bool value, child) {
          if (!mounted) return Container();
          rebuildSpeedDial.value = false;
          return SpeedDial(
            backgroundColor: const Color(0xFF35DB00),
            foregroundColor: Colors.white,
            icon: Icons.menu,
            activeIcon: Icons.close,
            spacing: 3,
            childPadding: const EdgeInsets.all(5),
            spaceBetweenChildren: 4,
            renderOverlay: false,
            overlayColor: Colors.black,
            overlayOpacity: 0.5,
            children: [
              SpeedDialChild(
                child: const Icon(Icons.menu_book),
                label: AppLocalizations.of(context)!.helpButtonTooltip,
                labelStyle: const TextStyle(color: Colors.black54),
                onTap: _launchHelp,
              ),
              ...(_getSpeedDialChildren(appState.userRole, appState.isConnected,
                  widget.displayContext, l10n)),
            ],
          );
        });
  }

  List<SpeedDialChild> _getSpeedDialChildren(String? userRole,
      bool? isConnected, String displayContext, AppLocalizations l10n) {
    switch (userRole) {
      case 'Farmer':
        return _getFarmerSpeedDialChildren(displayContext, l10n, isConnected!);
      case 'Farm Manager':
        return _getFarmManagerSpeedDialChildren(
            displayContext, l10n, isConnected!);
      case 'Trader':
        return _getTraderSpeedDialChildren(displayContext, l10n, isConnected!);

      case 'Processor':
        return _getProcessorSpeedDialChildren(
            displayContext, l10n, isConnected!);
      case 'Importer':
        return _getImporterSpeedDialChildren(
            displayContext, l10n, isConnected!);
      //ToDo Add more cases for other roles
      default:
        return [];
    }
  }

  //!########################## FARMER OPTIONS ####################

  List<SpeedDialChild> _getFarmerSpeedDialChildren(
      String displayContext, AppLocalizations l10n, bool isConnected) {
    return [
      SpeedDialChild(
        child: const Icon(Icons.agriculture),
        label: l10n.startHarvestOffline,
        labelStyle: const TextStyle(color: Colors.black54),
        onTap: () {
          // TODO: Implement start harvest action
        },
      ),
      SpeedDialChild(
        child: const Icon(Icons.transfer_within_a_station),
        label: l10n.handOverHarvestToTrader,
        labelStyle: const TextStyle(color: Colors.black54),
        onTap: () {
          // TODO: Implement hand over harvest action
        },
      ),
    ];
  }

  //!########################## FARM MANAGER OPTIONS ####################
  List<SpeedDialChild> _getFarmManagerSpeedDialChildren(
      String displayContext, AppLocalizations l10n, bool isConnected) {
    return [
      SpeedDialChild(
        child: const Icon(Icons.person_add),
        label: l10n.addEmployee,
        labelStyle: const TextStyle(color: Colors.black54),
        onTap: () {
          // TODO: Implement add employee action
        },
      ),
      SpeedDialChild(
        child: const Icon(Icons.add_box),
        label: l10n.addContainer,
        labelStyle: const TextStyle(color: Colors.black54),
        onTap: () {
          // TODO: Implement add container action
        },
      ),
    ];
  }

  //!########################## TRADER OPTIONS ####################
  List<SpeedDialChild> _getTraderSpeedDialChildren(
      String displayContext, AppLocalizations l10n, bool isConnected) {
    return [
      SpeedDialChild(
        child: const Icon(Icons.shopping_basket),
        label: l10n.buyCoffee,
        labelStyle: const TextStyle(color: Colors.black54),
        onTap: () async {
          showBuyCoffeeOptions(context);
        },
      ),
      if (batchSalePossible)
        SpeedDialChild(
          child: const Icon(Icons.merge_outlined),
          label: l10n.aggregateItems,
          labelStyle: const TextStyle(color: Colors.black54),
          onTap: () async {
            await showAggregateItemsDialog(context, selectedItems);
            setState(() {});
          },
        ),
      SpeedDialChild(
        child: const Icon(Icons.add_box),
        label: l10n.addNewEmptyItem,
        labelStyle: const TextStyle(color: Colors.black54),
        onTap: () async {
          await _showAddEmptyItemDialog(context);
          setState(() {});
        },
      )
    ];
  }

//!########################## PROCESSOR OPTIONS ####################

  List<SpeedDialChild> _getProcessorSpeedDialChildren(
      String displayContext, AppLocalizations l10n, bool isConnected) {
    return [
      SpeedDialChild(
        child: const Icon(Icons.shopping_basket),
        label: l10n.buyCoffee,
        labelStyle: const TextStyle(color: Colors.black54),
        onTap: () async {
          showBuyCoffeeOptions(context);
        },
      ),
      if (batchSalePossible)
        SpeedDialChild(
          child: const Icon(Icons.merge_outlined),
          label: l10n.aggregateItems,
          labelStyle: const TextStyle(color: Colors.black54),
          onTap: () async {
            await _showAddEmptyItemDialog(context);
            setState(() {});
          },
        ),
      SpeedDialChild(
        child: const Icon(Icons.add_box),
        label: l10n.addNewEmptyItem,
        labelStyle: const TextStyle(color: Colors.black54),
        onTap: () async {
          await fshowInfoDialog(context, l10n.notImplementedYet);
        },
      ),
    ];
  }

//!########################## IMPORTER OPTIONS ####################

  List<SpeedDialChild> _getImporterSpeedDialChildren(
      String displayContext, AppLocalizations l10n, bool isConnected) {
    if (displayContext == 'action' && isConnected) {
      return [
        SpeedDialChild(
          child: const Icon(Icons.shopping_basket),
          label: l10n.buyCoffee,
          labelStyle: const TextStyle(color: Colors.black54),
          onTap: () async {
            showBuyCoffeeOptions(context);
          },
        ),
      ];
    } else {
      return [];
    }
  }

  // void showBuyCoffeeOptions(BuildContext context,{String? receivingContainerUID}) {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text(
  //           'Select Buy Coffee Option',
  //           style: TextStyle(color: Colors.black),
  //           textAlign: TextAlign.center,
  //         ),
  //         content: ConstrainedBox(
  //           constraints: BoxConstraints(maxWidth: 300),
  //           child: Container(
  //             width: double.maxFinite,
  //             child: Column(
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  //                   children: [
  //                     Expanded(
  //                       child: _buildOptionButton(
  //                         context,
  //                         icon: Icons.credit_card,
  //                         label: 'CIAT first sale',
  //                         onTap: () async {
  //                           Navigator.of(context).pop();
  //                           //ToDo: Find out if First Sale or sale of selling container
  //                           FirstSaleProcess buyCoffeeProcess =
  //                               new FirstSaleProcess();
  //                           if (receivingContainerUID==null)
  //                           await buyCoffeeProcess.startProcess(context);
  //                           else
  //                           await buyCoffeeProcess.startProcess(context,receivingContainerUID:receivingContainerUID);

  //                           repaintContainerList.value = true;
  //                         },
  //                       ),
  //                     ),
  //                     SizedBox(width: 16), // Add spacing between buttons
  //                     Expanded(
  //                       child: _buildOptionButton(
  //                         context,
  //                         icon: Icons.devices,
  //                         label: 'Device-to-device',
  //                         onTap: () async {
  //                           Navigator.of(context).pop();
  //                           // TODO: Implement device-to-device process
  //                           StepperBuyCoffee buyCoffeeProcess =
  //                               new StepperBuyCoffee();
  //                           await buyCoffeeProcess.startProcess(context);

  //                           repaintContainerList.value = true;

  //                           // await fshowInfoDialog(
  //                           //     context, "Not implemented yet.");
  //                           // 
  //                         },
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //                 // SizedBox(height: 16), // Add vertical spacing
  //                 // _buildOptionButton(
  //                 //   context,
  //                 //   icon: Icons.cloud_upload,
  //                 //   label: 'Device-to-cloud',
  //                 //   onTap: () {
  //                 //     Navigator.of(context).pop();
  //                 //     // TODO: Implement device-to-cloud process
  //                 //     
  //                 //   },
  //                 // ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  void _showSellCoffeeOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            l10n.selectSellCoffeeOption,
            style: const TextStyle(color: Colors.black),
            textAlign: TextAlign.center,
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _buildOptionButton(
                          context,
                          icon: Icons.cloud_upload,
                          label: l10n.deviceToCloud,
                          onTap: () async {
                            Navigator.of(context).pop();
                            await fshowInfoDialog(
                                context, l10n.notImplementedYet);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildOptionButton(
                          context,
                          icon: Icons.devices,
                          label: l10n.deviceToDevice,
                          onTap: () async {
                            Navigator.of(context).pop();
                            await fshowInfoDialog(
                                context, l10n.notImplementedYet);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, size: 40, color: Theme.of(context).primaryColor),
          onPressed: onTap,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.black),
          textAlign: TextAlign.center,
          maxLines: 2, // Allow text to wrap to two lines if needed
          overflow: TextOverflow.ellipsis, // Add ellipsis if text is too long
        ),
      ],
    );
  }

  Future<void> _showAddEmptyItemDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddEmptyItemDialog(
          onItemAdded: (Map<String, dynamic> newItem) {
            // Handle the newly added item
            
            repaintContainerList.value = true;
          },
        );
      },
    );
  }
}
