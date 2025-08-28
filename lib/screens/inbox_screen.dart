import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trace_foodchain_app/helpers/database_helper.dart';
import 'package:trace_foodchain_app/helpers/helpers.dart';
import 'package:trace_foodchain_app/main.dart';
import 'package:trace_foodchain_app/providers/app_state.dart';
import '../l10n/app_localizations.dart';
import 'package:trace_foodchain_app/screens/settings_screen.dart';
import 'package:trace_foodchain_app/services/open_ral_service.dart';
import 'package:trace_foodchain_app/services/service_functions.dart';
import 'package:trace_foodchain_app/widgets/items_list_widget.dart';
import 'package:trace_foodchain_app/screens/container_selection_screen.dart'; // Neuer Import
import 'package:trace_foodchain_app/widgets/tracked_value_notifier.dart';

TrackedValueNotifier<bool> rebuildInbox =
    TrackedValueNotifier<bool>(false, "rebuildInbox");

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  // Neue Methode innerhalb der State-Klasse
  void _selectNewContainer(Map<String, dynamic> item) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => ContainerSelectionScreen(item: item)))
        .then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(
              80), // Increase this value to make the AppBar taller
          child: AppBar(
            centerTitle: true,
            title: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inbox),
                    const SizedBox(width: 8),
                    Text(l10n.inbox), // lokalisiert
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.selectContainerForItems,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            if (isTestmode)
              Container(
                width: double.infinity,
                height: 50,
                color: Colors.redAccent,
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    l10n.testModeActive, // Lokalisierter Text, z. B. "Testmodus aktiv"
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ValueListenableBuilder(
                  valueListenable: rebuildInbox,
                  builder: (context, bool value, child) {
                    if (!mounted) return Container();
                    rebuildInbox.value = false;
                    return CustomScrollView(
                      slivers: [
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final container = inbox[index];
                              dynamic results;
                              return InkWell(
                                  onTap: () => _selectNewContainer(container),
                                  child: _buildContainerItem(
                                      container)); // !results entfernt
                            },
                            childCount: inbox.length,
                          ),
                        ),
                      ],
                    );
                  }),
            ),
          ],
        ));
  }

  Widget _buildContainerItem(Map<String, dynamic> container) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _databaseHelper.getContainedItems(container["identity"]["UID"]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }

        if (snapshot.hasError) {
          return _buildErrorCard(snapshot.error.toString());
        }
//T coffee can also be sold without a container
        if (container["template"]["RALType"] == "coffee") {
          return InkWell(
              onTap: () => _selectNewContainer(container),
              child: Card(child: _buildCoffeeItem(container)));
        }
        final contents = snapshot.data ?? [];
        if (contents.isEmpty) {
          return _buildEmptyCard(container);
        }

        return InkWell(
          onTap: () => _selectNewContainer(container),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(container, contents),
                ...contents.map((item) => _buildContentItem(item)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentItem(Map<String, dynamic> item) {
    final itemType = item['template']['RALType'];
    if (itemType != 'coffee') {
      return _buildNestedContainer(item);
    } else {
      return _buildCoffeeItem(item);
    }
  }

  Widget _buildNestedContainer(Map<String, dynamic> container) {
    return FutureBuilder<List<Map<String, dynamic>>>(
        future: _databaseHelper.getContainedItems(container["identity"]["UID"]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingIndicator();
          }
          if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          }
          final nestedContents = snapshot.data ?? [];
          return ExpansionTile(
            // leading: Icon(Icons.inbox, color: Colors.black54),
            title: _buildCardHeader(container, nestedContents),
            children: [
              Column(
                children: nestedContents
                    .map((item) => _buildContentItem(item))
                    .toList(),
              )
            ],
          );
        });
  }

  Widget _buildCoffeeItem(Map<String, dynamic> coffee) {
    // Share.share(coffee.toString());
    final appState = Provider.of<AppState>(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,

        crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
        children: [
          // Icon positioned at the top-left
          Padding(
              padding: const EdgeInsets.only(top: 6.0, right: 16.0),
              child: Image.asset(
                'assets/images/cappuccino.png',
                width: 24, // You can adjust the size here
                height: 24,
              )
              //  Icon(FontAwesomeIcons.seedling, color: Colors.brown, size: 24),
              ),
          // Content column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          l10n.coffee,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          getSpecificPropertyfromJSON(coffee, "species"),
                          style: const TextStyle(
                            fontSize: 13,
                            // fontWeight: FontWeight.w100,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    coffee["needsSync"] != null
                        ? Tooltip(
                            message: l10n.notSynced, //"Not synced to cloud",
                            child: const Icon(Icons.cloud_off,
                                color: Colors.black54))
                        : Tooltip(
                            message: l10n.synced, //"Synced with cloud",
                            child: const Icon(Icons.cloud_done,
                                color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "${l10n.amount(getSpecificPropertyfromJSON(coffee, "amount").toString(), getSpecificPropertyUnitfromJSON(coffee, "amount"))} ${l10n.processingStep(getSpecificPropertyfromJSON(coffee, "processingState")) as String}",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                // const SizedBox(height: 4),
                // Text(
                //   (l10n.processingStep(getSpecificPropertyfromJSON(
                //       coffee, "processingState")) as String),
                //   style: const TextStyle(
                //     fontSize: 14,
                //     color: Colors.black54,
                //   ),
                // ),
                const SizedBox(height: 4),
                FutureBuilder<Map<String, dynamic>>(
                  future: _databaseHelper.getFirstSale(context, coffee),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Color(0xFF35DB00),
                          strokeWidth: 2,
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}',
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12));
                    }
                    final content = snapshot.data ?? {};
                    if (content.isEmpty) {
                      return Text(l10n.noPlotFound,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12));
                    }
                    final field = content["inputObjects"][1];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            l10n.boughtOn(
                                formatTimestamp(content["existenceStarts"]) ??
                                    "unknown"),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                        Text(
                          l10n.fromPlot(truncateUID(
                              field["identity"]["alternateIDs"][0]["UID"])),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return const Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SizedBox(
        height: 100,
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: Color(0xFF35DB00),
              strokeWidth: 3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: ListTile(
          leading: const Icon(Icons.error, color: Colors.red),
          title: Text(l10n.error), // lokalisiert
          subtitle: Text(error),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(Map<String, dynamic> container) {
    final appState = Provider.of<AppState>(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () => _selectNewContainer(container),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            // leading:
            title: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                    child: getContainerIcon(container["template"]["RALType"]),
                  ),
                  const SizedBox(width: 12),
                  Text((container["identity"]["name"] != null &&
                          container["identity"]["name"]
                              .toString()
                              .trim()
                              .isNotEmpty)
                      ? container["identity"]["name"]
                      : '${getContainerTypeName(container["template"]["RALType"], context)} ${container["identity"]["alternateIDs"]?.isNotEmpty == true ? container["identity"]["alternateIDs"][0]["UID"] : "No ID"}\nis empty'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(
      Map<String, dynamic> container, List<Map<String, dynamic>> contents) {
    final l10n = AppLocalizations.of(context)!;
    final appState = Provider.of<AppState>(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start, //spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 0, 0, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child:
                            getContainerIcon(container["template"]["RALType"]),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.3,
                        child: AutoSizeText(
                          (container["identity"]["name"] != null &&
                                  container["identity"]["name"]
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                              ? container["identity"]["name"]
                              : getContainerTypeName(
                                  container["template"]["RALType"],
                                  context), // l10n.unnamedObject,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(
                      "ID: ${truncateUID(container["identity"]["alternateIDs"][0]["UID"])}",
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 13,
                      )),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${l10n.freeCapacity}:\n${computeCoffeeSum(container, (getSpecificPropertyfromJSON(container, "max capacity") is num ? getSpecificPropertyfromJSON(container, "max capacity").toDouble() : double.tryParse(getSpecificPropertyfromJSON(container, "max capacity").toString()) ?? 0.0))} / ${(getSpecificPropertyfromJSON(container, "max capacity") is num ? getSpecificPropertyfromJSON(container, "max capacity").toDouble() : double.tryParse(getSpecificPropertyfromJSON(container, "max capacity").toString()) ?? "???")} ${getSpecificPropertyUnitfromJSON(container, "max capacity")}",
                        style: const TextStyle(
                          color: Colors.black38,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Animated progress bar for fill level
                      LayoutBuilder(builder: (context, constraints) {
                        debugPrint("Layoutbilder 4");
                        double maxCapacity = getSpecificPropertyfromJSON(
                                container, "max capacity") is num
                            ? getSpecificPropertyfromJSON(
                                    container, "max capacity")
                                .toDouble()
                            : double.tryParse(getSpecificPropertyfromJSON(
                                        container, "max capacity")
                                    .toString()) ??
                                0.0;
                        double computedCapacity =
                            computeCoffeeSum(container, maxCapacity);
                        double freeCapacity =
                            computedCapacity < 0 ? 0 : computedCapacity;
                        // Calculate progress as a fraction of the available max capacity.
                        double progress = (maxCapacity > 0)
                            ? (freeCapacity / maxCapacity)
                            : 0.0;
                        progress = progress.clamp(0.0, 1.0);
                        return Stack(
                          children: [
                            Container(
                              width: 150,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              width: 150 * progress,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              curve: Curves.easeInOut,
                            ),
                          ],
                        );
                      })
                    ],
                  )
                ],
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //*Sync state with cloud

            container["needsSync"] != null
                ? Tooltip(
                    message: l10n.notSynced, // "Not synced to cloud",
                    child: const Icon(Icons.cloud_off, color: Colors.black54))
                : Tooltip(
                    message: l10n.synced, //"Synced with cloud",
                    child: const Icon(Icons.cloud_done,
                        color: Colors.black54)), //cloud_done

            const SizedBox(width: 12),
            // Popupmenu
          ],
        )
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(
          color: Color(0xFF35DB00),
          strokeWidth: 3,
        ),
      ),
    );
  }
}
