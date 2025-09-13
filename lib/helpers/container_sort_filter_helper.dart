import 'package:trace_foodchain_app/widgets/container_search_filter_widget.dart';

class ContainerSortFilterHelper {
  /// Filtert Container basierend auf dem Suchbegriff
  static List<Map<String, dynamic>> filterContainers(
    List<Map<String, dynamic>> containers,
    String searchTerm,
  ) {
    if (searchTerm.isEmpty) {
      return containers;
    }

    final lowercaseSearchTerm = searchTerm.toLowerCase();

    return containers.where((container) {
      // Suche im Container-Namen
      final containerName =
          container["identity"]["name"]?.toString().toLowerCase() ?? '';
      if (containerName.contains(lowercaseSearchTerm)) {
        return true;
      }

      // Suche in der Container-ID
      final containerId = container["identity"]["alternateIDs"]?[0]?["UID"]
              ?.toString()
              .toLowerCase() ??
          '';
      if (containerId.contains(lowercaseSearchTerm)) {
        return true;
      }

      return false;
    }).toList();
  }

  /// Sortiert Container basierend auf dem gewählten Sortierkriterium
  static List<Map<String, dynamic>> sortContainers(
    List<Map<String, dynamic>> containers,
    SortCriteria sortCriteria,
  ) {
    final sortedContainers = List<Map<String, dynamic>>.from(containers);

    switch (sortCriteria) {
      case SortCriteria.nameAsc:
        sortedContainers.sort((a, b) {
          final nameA = _getContainerDisplayName(a).toLowerCase();
          final nameB = _getContainerDisplayName(b).toLowerCase();
          return nameA.compareTo(nameB);
        });
        break;

      case SortCriteria.nameDesc:
        sortedContainers.sort((a, b) {
          final nameA = _getContainerDisplayName(a).toLowerCase();
          final nameB = _getContainerDisplayName(b).toLowerCase();
          return nameB.compareTo(nameA);
        });
        break;

      case SortCriteria.idAsc:
        sortedContainers.sort((a, b) {
          final idA = _getContainerId(a);
          final idB = _getContainerId(b);
          return idA.compareTo(idB);
        });
        break;

      case SortCriteria.idDesc:
        sortedContainers.sort((a, b) {
          final idA = _getContainerId(a);
          final idB = _getContainerId(b);
          return idB.compareTo(idA);
        });
        break;

      case SortCriteria.dateAsc:
        sortedContainers.sort((a, b) {
          final dateA = _getContainerCreationDate(a);
          final dateB = _getContainerCreationDate(b);
          return dateA.compareTo(dateB);
        });
        break;

      case SortCriteria.dateDesc:
        sortedContainers.sort((a, b) {
          final dateA = _getContainerCreationDate(a);
          final dateB = _getContainerCreationDate(b);
          return dateB.compareTo(dateA);
        });
        break;
    }

    return sortedContainers;
  }

  /// Filtert und sortiert Container in einem Schritt
  static List<Map<String, dynamic>> filterAndSortContainers(
    List<Map<String, dynamic>> containers,
    String searchTerm,
    SortCriteria sortCriteria,
  ) {
    final filteredContainers = filterContainers(containers, searchTerm);
    return sortContainers(filteredContainers, sortCriteria);
  }

  /// Hilfsfunktion: Gibt den Anzeigenamen eines Containers zurück
  static String _getContainerDisplayName(Map<String, dynamic> container) {
    final name = container["identity"]["name"]?.toString();
    if (name != null && name.trim().isNotEmpty) {
      return name;
    }

    // Fallback auf Container-Typ, wenn kein Name verfügbar ist
    final ralType = container["template"]?["RALType"]?.toString() ?? '';
    return ralType.isEmpty ? 'Unbenannter Container' : ralType;
  }

  /// Hilfsfunktion: Gibt die Container-ID zurück
  static String _getContainerId(Map<String, dynamic> container) {
    return container["identity"]["alternateIDs"]?[0]?["UID"]?.toString() ?? '';
  }

  /// Hilfsfunktion: Gibt das Erstellungsdatum des Containers zurück
  static DateTime _getContainerCreationDate(Map<String, dynamic> container) {
    // Versuche verschiedene Felder für das Erstellungsdatum
    final existenceStarts = container["existenceStarts"];
    if (existenceStarts != null) {
      final date = DateTime.tryParse(existenceStarts.toString());
      if (date != null) return date;
    }

    // Fallback auf das aktuelle Datum, wenn kein Erstellungsdatum gefunden wird
    return DateTime.now();
  }
}
