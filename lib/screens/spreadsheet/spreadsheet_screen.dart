import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/currency_helper.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/category.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/filter_tabs.dart';

class SpreadsheetScreen extends StatefulWidget {
  const SpreadsheetScreen({super.key});

  @override
  State<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends State<SpreadsheetScreen> {
  FilterType _filter = FilterType.monthly;
  final List<PlutoGridStateManager> _stateManagers = [];

  @override
  void dispose() {
    for (final stateManager in _stateManagers) {
      stateManager.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final configuration = isDark
        ? PlutoGridConfiguration.dark()
        : const PlutoGridConfiguration();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spreadsheet View'),
      ),
      body: Consumer2<ExpenseProvider, SettingsProvider>(
        builder: (context, provider, settings, _) {
          final periodKeys = provider.getPeriodKeys(_filter);
          final periodLabels = provider.getPeriodLabels(_filter);
          final currency = settings.currency;
          final columns = _buildColumns(
            context,
            periodKeys,
            periodLabels,
            currency,
          );

          return FutureBuilder<Map<Category, Map<String, double>>>(
            future: provider.getConvertedSpreadsheetData(
              _filter,
              currency.code,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilterTabs(
                        selectedFilter: _filter,
                        onFilterChanged: (f) => setState(() => _filter = f),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: snapshot.connectionState == ConnectionState.waiting
                            ? const CircularProgressIndicator()
                            : Text(
                                'No data. Add expenses to see the spreadsheet.',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                  ],
                );
              }
              final spreadsheetData = snapshot.data!;
              final rows = _buildRows(spreadsheetData, periodKeys);

              return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilterTabs(
                  selectedFilter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                ),
              ),
              Expanded(
                child: PlutoGrid(
                  columns: columns,
                  rows: rows,
                  onLoaded: (event) {
                    _stateManagers.add(event.stateManager);
                  },
                  onChanged: null,
                  configuration: configuration,
                  noRowsWidget: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No data. Add expenses to see the spreadsheet.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
            },
          );
        },
      ),
    );
  }

  List<PlutoColumn> _buildColumns(
    BuildContext context,
    List<String> periodKeys,
    List<String> periodLabels,
    CurrencyCode currency,
  ) {
    final columns = <PlutoColumn>[
      PlutoColumn(
        title: 'Category',
        field: 'category',
        type: PlutoColumnType.text(),
        readOnly: true,
        frozen: PlutoColumnFrozen.start,
        enableEditingMode: false,
        enableSorting: false,
        enableContextMenu: false,
        enableFilterMenuItem: false,
        width: 120,
      ),
    ];

    for (var i = 0; i < periodKeys.length; i++) {
      final key = periodKeys[i];
      final label = i < periodLabels.length ? periodLabels[i] : key;
      columns.add(
        PlutoColumn(
          title: label,
          field: key,
          type: PlutoColumnType.number(),
          readOnly: true,
          enableEditingMode: false,
          enableSorting: false,
          enableContextMenu: false,
          enableFilterMenuItem: false,
          width: 100,
          titleTextAlign: PlutoColumnTextAlign.center,
          textAlign: PlutoColumnTextAlign.end,
          formatter: (value) => value != null ? currency.format(value as num) : '',
        ),
      );
    }

    return columns;
  }

  List<PlutoRow> _buildRows(
    Map<Category, Map<String, double>> spreadsheetData,
    List<String> periodKeys,
  ) {
    final rows = <PlutoRow>[];
    final categories = Category.values;

    for (final category in categories) {
      final cells = <String, PlutoCell>{
        'category': PlutoCell(value: category.label),
      };
      double rowTotal = 0;
      for (final key in periodKeys) {
        final value = spreadsheetData[category]?[key] ?? 0.0;
        rowTotal += value;
        cells[key] = PlutoCell(value: value);
      }
      rows.add(PlutoRow(cells: cells));
    }

    final totalCells = <String, PlutoCell>{
      'category': PlutoCell(value: 'Total'),
    };
    for (final key in periodKeys) {
      double colTotal = 0;
      for (final category in categories) {
        colTotal += spreadsheetData[category]?[key] ?? 0;
      }
      totalCells[key] = PlutoCell(value: colTotal);
    }
    rows.add(PlutoRow(cells: totalCells));

    return rows;
  }
}
