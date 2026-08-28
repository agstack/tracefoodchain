import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../l10n/app_localizations.dart';

/// Sichtbarer Umschalter für die Kartenansicht (Satellit ist überall der
/// Standard, weil der Abgleich "Polygon gegen sichtbare Feldgrenze" die
/// eigentliche Prüfarbeit ist).
class MapTypeSelector extends StatelessWidget {
  const MapTypeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final MapType selected;
  final ValueChanged<MapType> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final types = <MapType, String>{
      MapType.satellite: l10n.mapTypeSatellite,
      MapType.hybrid: l10n.mapTypeHybrid,
      MapType.terrain: l10n.mapTypeTerrain,
      MapType.normal: l10n.mapTypeNormal,
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: PopupMenuButton<MapType>(
        tooltip: l10n.mapTypeLabel,
        initialValue: selected,
        onSelected: onSelected,
        itemBuilder: (context) => types.entries
            .map((entry) => PopupMenuItem<MapType>(
                  value: entry.key,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        entry.key == selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Text(entry.value),
                    ],
                  ),
                ))
            .toList(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.layers, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                types[selected] ?? l10n.mapTypeLabel,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
