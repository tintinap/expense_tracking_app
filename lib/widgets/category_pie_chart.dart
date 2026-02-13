import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/currency_helper.dart';
import '../providers/settings_provider.dart';
import '../data/models/category.dart';
import '../data/models/expense.dart';
import '../providers/expense_provider.dart';

class CategoryPieChart extends StatelessWidget {
  final List<Expense> expenses;
  final FilterType filter;

  const CategoryPieChart({
    super.key,
    required this.expenses,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final data = _aggregateByCategory();
    if (data.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No data for the selected period',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final total = data.values.fold<double>(0, (a, b) => a + b.abs());
    if (total == 0) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No expenses in this period',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final sections = data.entries
        .where((e) => e.value.abs() > 0)
        .map((e) => PieChartSectionData(
              value: e.value.abs(),
              title: '',
              color: e.key.color,
              radius: 80,
            ))
        .toList();

    final currency = context.read<SettingsProvider>().currency;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: data.entries
              .where((e) => e.value.abs() > 0)
              .map((e) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: e.key.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${e.key.label}: ${currency.format(e.value.abs())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ))
              .toList(),
        ),
      ],
    );
  }

  Map<Category, double> _aggregateByCategory() {
    final result = <Category, double>{};
    for (final cat in Category.values) {
      result[cat] = 0;
    }
    for (final expense in expenses) {
      result[expense.category] =
          (result[expense.category] ?? 0) + expense.amount;
    }
    return result;
  }
}
