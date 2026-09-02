import 'package:flutter/material.dart' show Color, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../../shared/providers/shared_providers.dart';

// ── Data classes ──────────────────────────────────────────────

class CategorySpend {
  final String categoryId;
  final String name;
  final String colourHex;
  final int iconCodePoint;
  final double amount;
  final double percentage;

  const CategorySpend({
    required this.categoryId,
    required this.name,
    required this.colourHex,
    required this.iconCodePoint,
    required this.amount,
    required this.percentage,
  });

  Color get color {
    if (colourHex.startsWith('#') && colourHex.length >= 7) {
      try {
        return Color(
            int.parse(colourHex.substring(1, 7), radix: 16) + 0xFF000000);
      } catch (_) {}
    }
    return const Color(0xFF9E9E9E);
  }
}

class TrendPoint {
  final DateTime date;
  final double cumulativeAmount;

  const TrendPoint({required this.date, required this.cumulativeAmount});
}

class PeriodComparison {
  final double currentTotal;
  final double previousTotal;
  final double absoluteDiff;
  final double percentDiff;
  final bool hasPreviousData;

  const PeriodComparison({
    required this.currentTotal,
    required this.previousTotal,
    required this.absoluteDiff,
    required this.percentDiff,
    required this.hasPreviousData,
  });
}

// ── Providers ─────────────────────────────────────────────────

/// Computes the previous period's date range from the current period.
PeriodState _previousPeriod(PeriodState current) {
  DateTime from;
  DateTime to;

  switch (current.type) {
    case PeriodType.daily:
      from = current.from.subtract(const Duration(days: 1));
      to = DateTime(from.year, from.month, from.day, 23, 59, 59);
    case PeriodType.weekly:
      from = current.from.subtract(const Duration(days: 7));
      to = from.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    case PeriodType.fortnightly:
      from = current.from.subtract(const Duration(days: 14));
      to = from.add(const Duration(days: 13, hours: 23, minutes: 59, seconds: 59));
    case PeriodType.monthly:
      from = DateTime(current.from.year, current.from.month - 1, 1);
      to = DateTime(current.from.year, current.from.month, 0, 23, 59, 59);
    case PeriodType.yearly:
      from = DateTime(current.from.year - 1, 1, 1);
      to = DateTime(current.from.year - 1, 12, 31, 23, 59, 59);
    case PeriodType.custom:
      final duration = current.to.difference(current.from);
      to = current.from.subtract(const Duration(seconds: 1));
      from = to.subtract(duration);
  }

  return PeriodState(type: current.type, from: from, to: to);
}

/// Streams transactions for the period immediately before the selected period.
final previousPeriodTransactionsProvider =
    StreamProvider<List<TransactionData>>((ref) {
  final currentPeriod = ref.watch(selectedPeriodProvider);
  final prev = _previousPeriod(currentPeriod);
  final dao = ref.watch(transactionDaoProvider);
  return dao.watchByDateRange(prev.from, prev.to);
});

/// Day → total spend for the selected period (expenses only, converted to view currency).
final dailySpendAggregateProvider = Provider<Map<DateTime, double>>((ref) {
  final transactions = ref.watch(transactionListProvider).valueOrNull ?? [];
  final enabledCurrencies = ref.watch(enabledCurrenciesProvider);

  final expenses = transactions.where((t) =>
      t.transactionType == 'expense' &&
      enabledCurrencies.contains(t.originalCurrency));

  final result = <DateTime, double>{};
  for (final tx in expenses) {
    final day = DateTime(
      tx.transactionDate.year,
      tx.transactionDate.month,
      tx.transactionDate.day,
    );
    result[day] = (result[day] ?? 0) + tx.amountBase.abs();
  }
  return result;
});

/// Sorted list of category spend breakdowns for the selected period.
final categorySpendProvider = Provider<List<CategorySpend>>((ref) {
  final transactions = ref.watch(transactionListProvider).valueOrNull ?? [];
  final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
  final enabledCurrencies = ref.watch(enabledCurrenciesProvider);

  final expenses = transactions.where((t) =>
      t.transactionType == 'expense' &&
      enabledCurrencies.contains(t.originalCurrency));

  // Aggregate by parent category
  final totals = <String, double>{};
  double grandTotal = 0;

  for (final tx in expenses) {
    if (tx.categoryId != null) {
      final cat =
          categories.where((c) => c.id == tx.categoryId).firstOrNull;
      final displayId =
          (cat != null && cat.parentId != null) ? cat.parentId! : tx.categoryId!;
      final amount = tx.amountBase.abs();
      totals[displayId] = (totals[displayId] ?? 0) + amount;
      grandTotal += amount;
    }
  }

  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return sorted.map((e) {
    final cat = categories.where((c) => c.id == e.key).firstOrNull;
    return CategorySpend(
      categoryId: e.key,
      name: cat?.name ?? 'Unknown',
      colourHex: cat?.colourHex ?? '#9E9E9E',
      iconCodePoint: cat?.iconCodePoint ?? Icons.category.codePoint,
      amount: e.value,
      percentage: grandTotal > 0 ? e.value / grandTotal : 0,
    );
  }).toList();
});

/// Cumulative daily spend trend points for the selected period.
final trendSpendProvider = Provider<List<TrendPoint>>((ref) {
  final dailyMap = ref.watch(dailySpendAggregateProvider);
  if (dailyMap.isEmpty) return [];

  final sortedDays = dailyMap.keys.toList()..sort();
  double cumulative = 0;

  return sortedDays.map((day) {
    cumulative += dailyMap[day]!;
    return TrendPoint(date: day, cumulativeAmount: cumulative);
  }).toList();
});

/// Comparison between current and previous period spend totals.
final periodComparisonProvider = Provider<PeriodComparison>((ref) {
  final enabledCurrencies = ref.watch(enabledCurrenciesProvider);

  final currentTxs = ref.watch(transactionListProvider).valueOrNull ?? [];
  final previousTxs =
      ref.watch(previousPeriodTransactionsProvider).valueOrNull ?? [];

  double currentTotal = currentTxs
      .where((t) =>
          t.transactionType == 'expense' &&
          enabledCurrencies.contains(t.originalCurrency))
      .fold(0.0, (sum, t) => sum + t.amountBase.abs());

  double previousTotal = previousTxs
      .where((t) =>
          t.transactionType == 'expense' &&
          enabledCurrencies.contains(t.originalCurrency))
      .fold(0.0, (sum, t) => sum + t.amountBase.abs());

  final hasPreviousData = previousTxs.isNotEmpty;
  final absoluteDiff = currentTotal - previousTotal;
  final percentDiff =
      previousTotal > 0 ? (absoluteDiff / previousTotal) : 0.0;

  return PeriodComparison(
    currentTotal: currentTotal,
    previousTotal: previousTotal,
    absoluteDiff: absoluteDiff,
    percentDiff: percentDiff,
    hasPreviousData: hasPreviousData,
  );
});
