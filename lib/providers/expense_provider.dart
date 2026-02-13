import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../core/constants.dart';
import '../data/hive/hive_service.dart';
import '../data/models/category.dart';
import '../data/models/expense.dart';

class ExpenseProvider extends ChangeNotifier {
  Box<Expense> get _box => HiveService.expensesBox;

  List<Expense> get expenses =>
      _box.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  List<Expense> filteredExpenses(FilterType filter) {
    final now = DateTime.now();
    final range = _getDateRange(filter, now);
    if (range == null) return expenses;
    return expenses
        .where((e) =>
            !e.date.isBefore(range.start) && !e.date.isAfter(range.end))
        .toList();
  }

  void addExpense(Expense expense) {
    _box.add(expense);
    notifyListeners();
  }

  void updateExpense(Expense existingExpense, Expense updatedExpense) {
    final key = existingExpense.key;
    if (key != null) {
      _box.put(key, updatedExpense);
      notifyListeners();
    }
  }

  void deleteExpense(Expense expense) {
    expense.delete();
    notifyListeners();
  }

  void deleteExpenseByKey(dynamic key) {
    _box.delete(key);
    notifyListeners();
  }

  void clearAll() {
    _box.clear();
    notifyListeners();
  }

  Map<Category, Map<String, double>> getSpreadsheetData(FilterType filter) {
    final result = <Category, Map<String, double>>{};
    for (final category in Category.values) {
      result[category] = {};
    }

    final periodKeys = getPeriodKeys(filter);
    for (final key in periodKeys) {
      for (final category in Category.values) {
        result[category]![key] = 0.0;
      }
    }

    for (final expense in expenses) {
      final periodKey = _getPeriodKey(expense.date, filter);
      if (periodKey == null) continue;

      final category = expense.category;
      final value = expense.isIncome ? expense.amount : -expense.amount;
      result[category]![periodKey] =
          (result[category]![periodKey] ?? 0) + value;
    }

    return result;
  }

  List<String> getPeriodKeys(FilterType filter) {
    final keys = <String>{};
    for (final expense in expenses) {
      final key = _getPeriodKey(expense.date, filter);
      if (key != null) keys.add(key);
    }
    final list = keys.toList()..sort();
    return list;
  }

  List<String> getPeriodLabels(FilterType filter) {
    final keys = getPeriodKeys(filter);
    return keys.map((k) => _formatPeriodLabel(k, filter)).toList();
  }

  String _formatPeriodLabel(String key, FilterType filter) {
    switch (filter) {
      case FilterType.monthly:
        if (key.length >= 7) {
          final parts = key.split('-');
          if (parts.length >= 2) {
            final month = int.tryParse(parts[1]) ?? 0;
            const months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            return months[month - 1];
          }
        }
        return key;
      case FilterType.fortnightly:
        if (key.length >= 10) {
          final parts = key.split('-');
          if (parts.length >= 3) {
            final day = int.tryParse(parts[2]) ?? 1;
            final month = int.tryParse(parts[1]) ?? 1;
            final year = int.tryParse(parts[0]) ?? 2024;
            const months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            final endDay = day == 1 ? 15 : DateTime(year, month + 1, 0).day;
            return '$day-$endDay ${months[month - 1]}';
          }
        }
        return key;
      case FilterType.weekly:
        return key;
      case FilterType.yearly:
        return key;
    }
  }

  String? _getPeriodKey(DateTime date, FilterType filter) {
    switch (filter) {
      case FilterType.weekly:
        final weekNum = _getWeekNumber(date);
        return '${date.year}-W${weekNum.toString().padLeft(2, '0')}';
      case FilterType.fortnightly:
        final day = date.day;
        final periodStart = day <= 15 ? 1 : 16;
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${periodStart.toString().padLeft(2, '0')}';
      case FilterType.monthly:
        return '${date.year}-${date.month.toString().padLeft(2, '0')}';
      case FilterType.yearly:
        return date.year.toString();
    }
  }

  int _getWeekNumber(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(startOfYear).inDays;
    return ((days + startOfYear.weekday - 1) / 7).floor() + 1;
  }

  DateTimeRange? _getDateRange(FilterType filter, DateTime now) {
    switch (filter) {
      case FilterType.weekly:
        final weekday = now.weekday;
        final start = now.subtract(Duration(days: weekday - 1));
        return DateTimeRange(
          start: DateTime(start.year, start.month, start.day),
          end: now,
        );
      case FilterType.fortnightly:
        final day = now.day;
        final periodStart = day <= 15 ? 1 : 16;
        return DateTimeRange(
          start: DateTime(now.year, now.month, periodStart),
          end: now,
        );
      case FilterType.monthly:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      case FilterType.yearly:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now,
        );
    }
  }
}
