import 'package:flutter/material.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import 'package:trace_foodchain_app/widgets/online_sale_dialog.dart';
import 'package:trace_foodchain_app/widgets/shared_widgets.dart';
import 'package:trace_foodchain_app/widgets/stepper_sell_coffee.dart';
import 'package:trace_foodchain_app/widgets/safe_popup_menu.dart';
import '../l10n/app_localizations.dart';

class CoffeeActionsMenu extends StatefulWidget {
  final Map<String, dynamic> coffee;
  final Function(Map<String, dynamic>) onProcessingStateChange;
  final VoidCallback onRepaint;
  final bool isConnected;

  const CoffeeActionsMenu({
    super.key,
    required this.coffee,
    required this.onProcessingStateChange,
    required this.onRepaint,
    required this.isConnected,
  });

  @override
  _CoffeeActionsMenuState createState() => _CoffeeActionsMenuState();
}

class _CoffeeActionsMenuState extends State<CoffeeActionsMenu>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Add mounted check to prevent accessing deactivated context
    if (!mounted) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    // Use SafePopupMenuButton instead of PopupMenuButton
    return SafePopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.black54),
      surfaceTintColor: Colors.white,
      tooltip: "",
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: "sell_offline",
          child: ListTile(
            leading: Image.asset(
              'assets/images/cappuccino.png',
              width: 24,
              height: 24,
            ),
            title: Text(l10n.sellOffline,
                style: const TextStyle(color: Colors.black)),
          ),
        ),
        if (widget.isConnected && widget.coffee["needsSync"] == null)
          PopupMenuItem<String>(
            value: "sell_online",
            child: ListTile(
              leading: Image.asset(
                'assets/images/cappuccino.png',
                width: 24,
                height: 24,
              ),
              title: Text(l10n.sellOnline,
                  style: const TextStyle(color: Colors.black)),
            ),
          ),
        PopupMenuItem<String>(
          value: "change_processing_state",
          child: ListTile(
            leading: const Icon(Icons.change_circle, size: 20),
            title: Text(l10n.changeProcessingState,
                style: const TextStyle(color: Colors.black)),
          ),
        ),
        PopupMenuItem<String>(
          value: "change_location",
          child: ListTile(
            leading: const Icon(Icons.swap_horiz, size: 20),
            title: Text(l10n.changeLocation,
                style: const TextStyle(color: Colors.black)),
          ),
        ),
      ],
      onSelected: (String value) async {
        if (!mounted) return;

        switch (value) {
          case "sell_offline":
            await _sellOffline();
            break;
          case "sell_online":
            await _sellOnline();
            break;
          case "change_processing_state":
            await _changeProcessingState();
            break;
          case "change_location":
            _changeLocation();
            break;
        }
      },
    );
  }

  Future<void> _sellOffline() async {
    if (!mounted) return;

    final currentContainerUID =
        widget.coffee["currentGeolocation"]["container"]["UID"];
    Map<String, dynamic> oldContainer =
        await getLocalObjectMethod(currentContainerUID);
    StepperSellCoffee sellCoffeeProcess = StepperSellCoffee();
    await sellCoffeeProcess.startProcess(
        context, widget.coffee, appUserDoc!, oldContainer);
    widget.onRepaint();
  }

  Future<void> _sellOnline() async {
    if (!mounted) return;

    Map<String, dynamic> itemToSell = widget.coffee;
    if (itemToSell.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (dialogContext) => OnlineSaleDialog(itemsToSell: [itemToSell]),
      );
    } else {
      final l10n = AppLocalizations.of(context)!;
      await fshowInfoDialog(context, l10n.selectItemToSell);
    }
    widget.onRepaint();
  }

  Future<void> _changeProcessingState() async {
    if (!mounted) return;

    await showProcessingStateDialog(widget.coffee, context);
    widget.onRepaint();
  }

  void _changeLocation() {
    if (!mounted) return;

    showChangeContainerDialog(context, widget.coffee);
    widget.onRepaint();
  }
}
