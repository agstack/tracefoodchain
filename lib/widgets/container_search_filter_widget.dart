import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

enum SortCriteria {
  nameAsc,
  nameDesc,
  idAsc,
  idDesc,
  dateAsc,
  dateDesc,
}

class ContainerSearchFilterWidget extends StatefulWidget {
  final Function(String searchTerm) onSearchChanged;
  final Function(SortCriteria sortCriteria) onSortChanged;
  final String initialSearchTerm;
  final SortCriteria initialSortCriteria;

  const ContainerSearchFilterWidget({
    super.key,
    required this.onSearchChanged,
    required this.onSortChanged,
    this.initialSearchTerm = '',
    this.initialSortCriteria = SortCriteria.dateDesc,
  });

  @override
  State<ContainerSearchFilterWidget> createState() =>
      _ContainerSearchFilterWidgetState();
}

class _ContainerSearchFilterWidgetState
    extends State<ContainerSearchFilterWidget> {
  late TextEditingController _searchController;
  late SortCriteria _currentSortCriteria;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearchTerm);
    _currentSortCriteria = widget.initialSortCriteria;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getSortIcon() {
    switch (_currentSortCriteria) {
      case SortCriteria.nameAsc:
      case SortCriteria.idAsc:
      case SortCriteria.dateAsc:
        return Icons.arrow_upward;
      case SortCriteria.nameDesc:
      case SortCriteria.idDesc:
      case SortCriteria.dateDesc:
        return Icons.arrow_downward;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchContainers,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          widget.onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {});
                widget.onSearchChanged(value);
              },
            ),
          ),
          const SizedBox(width: 12.0),
          // Sort button
          PopupMenuButton<SortCriteria>(
            onSelected: (SortCriteria criteria) {
              setState(() {
                _currentSortCriteria = criteria;
              });
              widget.onSortChanged(criteria);
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<SortCriteria>(
                value: SortCriteria.nameAsc,
                child: Row(
                  children: [
                    const Icon(Icons.sort_by_alpha),
                    const SizedBox(width: 8),
                    Text(l10n.sortByNameAsc),
                    const Spacer(),
                    const Icon(Icons.arrow_upward, size: 16),
                  ],
                ),
              ),
              PopupMenuItem<SortCriteria>(
                value: SortCriteria.nameDesc,
                child: Row(
                  children: [
                    const Icon(Icons.sort_by_alpha),
                    const SizedBox(width: 8),
                    Text(l10n.sortByNameDesc),
                    const Spacer(),
                    const Icon(Icons.arrow_downward, size: 16),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<SortCriteria>(
                value: SortCriteria.idAsc,
                child: Row(
                  children: [
                    const Icon(Icons.tag),
                    const SizedBox(width: 8),
                    Text(l10n.sortByIdAsc),
                    const Spacer(),
                    const Icon(Icons.arrow_upward, size: 16),
                  ],
                ),
              ),
              PopupMenuItem<SortCriteria>(
                value: SortCriteria.idDesc,
                child: Row(
                  children: [
                    const Icon(Icons.tag),
                    const SizedBox(width: 8),
                    Text(l10n.sortByIdDesc),
                    const Spacer(),
                    const Icon(Icons.arrow_downward, size: 16),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<SortCriteria>(
                value: SortCriteria.dateAsc,
                child: Row(
                  children: [
                    const Icon(Icons.date_range),
                    const SizedBox(width: 8),
                    Text(l10n.sortByDateAsc),
                    const Spacer(),
                    const Icon(Icons.arrow_upward, size: 16),
                  ],
                ),
              ),
              PopupMenuItem<SortCriteria>(
                value: SortCriteria.dateDesc,
                child: Row(
                  children: [
                    const Icon(Icons.date_range),
                    const SizedBox(width: 8),
                    Text(l10n.sortByDateDesc),
                    const Spacer(),
                    const Icon(Icons.arrow_downward, size: 16),
                  ],
                ),
              ),
            ],
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, color: Colors.grey),
                  const SizedBox(width: 4),
                  Icon(_getSortIcon(), size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    l10n.sort,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
