import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/currency_helper.dart';
import '../data/models/category.dart';
import '../data/models/expense.dart';
import '../providers/expense_provider.dart';

class ExpenseList extends StatelessWidget {
  final List<Expense> expenses;
  final FilterType filter;
  final void Function(Expense)? onEdit;
  final void Function(Expense)? onDelete;

  const ExpenseList({
    super.key,
    required this.expenses,
    required this.filter,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate(expenses);
    if (grouped.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No transactions for the selected period',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                DateFormat.yMMMd().format(entry.key),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...entry.value.map((e) => _ExpenseTile(
                  expense: e,
                  onEdit: onEdit != null ? () => onEdit!(e) : null,
                  onDelete: onDelete != null ? () => onDelete!(e) : null,
                )),
          ],
        );
      },
    );
  }

  Map<DateTime, List<Expense>> _groupByDate(List<Expense> list) {
    final map = <DateTime, List<Expense>>{};
    for (final e in list) {
      final date = DateTime(e.date.year, e.date.month, e.date.day);
      map.putIfAbsent(date, () => []).add(e);
    }
    final sortedDates = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return Map.fromEntries(
      sortedDates.map((d) => MapEntry(d, map[d]!)),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ExpenseTile({
    required this.expense,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final amount = expense.isIncome ? expense.amount : -expense.amount;
    final isPositive = amount >= 0;
    final formatted = CurrencyCode.formatSignedInCurrency(amount, expense.currencyCode);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: expense.category.color.withOpacity(0.2),
          child: Icon(expense.category.icon, color: expense.category.color),
        ),
        title: Text(expense.category.label),
        subtitle: expense.note != null && expense.note!.isNotEmpty
            ? Text(expense.note!)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatted,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (onEdit != null || onDelete != null)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
