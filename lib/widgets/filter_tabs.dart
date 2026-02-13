import 'package:flutter/material.dart';

import '../core/constants.dart';

class FilterTabs extends StatelessWidget {
  final FilterType selectedFilter;
  final ValueChanged<FilterType> onFilterChanged;

  const FilterTabs({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<FilterType>(
      segments: const [
        ButtonSegment(
          value: FilterType.weekly,
          label: Text('Weekly'),
          icon: Icon(Icons.view_week),
        ),
        ButtonSegment(
          value: FilterType.fortnightly,
          label: Text('Fortnightly'),
          icon: Icon(Icons.view_module),
        ),
        ButtonSegment(
          value: FilterType.monthly,
          label: Text('Monthly'),
          icon: Icon(Icons.calendar_month),
        ),
        ButtonSegment(
          value: FilterType.yearly,
          label: Text('Yearly'),
          icon: Icon(Icons.calendar_today),
        ),
      ],
      selected: {selectedFilter},
      onSelectionChanged: (selection) => onFilterChanged(selection.first),
    );
  }
}
