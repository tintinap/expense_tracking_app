import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../../shared/providers/shared_providers.dart';
import '../utils/budget_period_calculator.dart';

class BudgetProgress {
  final BudgetData budget;
  final BudgetPeriod currentPeriod;
  final double spentAmount;
  final double limitAmount;
  final double percentageUsed;
  final String currency;
  final bool isExpired;
  final List<String> categoryNames;

  const BudgetProgress({
    required this.budget,
    required this.currentPeriod,
    required this.spentAmount,
    required this.limitAmount,
    required this.percentageUsed,
    required this.currency,
    required this.isExpired,
    required this.categoryNames,
  });
  
  bool get isWarning => percentageUsed >= 0.75 && percentageUsed < 0.90;
  bool get isCritical => percentageUsed >= 0.90 && percentageUsed <= 1.0;
  bool get isOverBudget => percentageUsed > 1.0;

  double get remainingAmount => (limitAmount - spentAmount).clamp(0, double.infinity);
}

class BudgetPeriodHistory {
  final BudgetPeriod period;
  final double spentAmount;
  final double limitAmount;
  final double percentageUsed;

  const BudgetPeriodHistory({
    required this.period,
    required this.spentAmount,
    required this.limitAmount,
    required this.percentageUsed,
  });
}

/// Expand a list of category IDs so any parent ID also includes its direct
/// children. This ensures that a budget scoped to "Food" (parent) correctly
/// counts transactions logged under "Restaurant" or "Café" (children of Food).
List<String> _expandCategoryIds(
  List<String> ids,
  List<CategoryData> allCategories,
) {
  final expanded = <String>{...ids};
  for (final id in ids) {
    for (final cat in allCategories) {
      if (cat.parentId == id) expanded.add(cat.id);
    }
  }
  return expanded.toList();
}

final budgetProgressListProvider = FutureProvider<List<BudgetProgress>>((ref) async {
  // Watch the all-time transaction count stream so this provider re-runs
  // whenever any transaction row is inserted, updated, or deleted.
  ref.watch(transactionCountByCurrencyProvider);

  final budgetsAsync = ref.watch(budgetListProvider);
  final budgets = budgetsAsync.valueOrNull ?? [];
  final txDao = ref.watch(transactionDaoProvider);
  final categoriesAsync = ref.watch(categoryListProvider);
  final categories = categoriesAsync.valueOrNull ?? [];
  
  final List<BudgetProgress> results = [];
  
  for (final budget in budgets) {
    final currentPeriod = BudgetPeriodCalculator.currentPeriod(budget);
    final isExpired = BudgetPeriodCalculator.isExpired(budget);
    
    double spent = 0;
    
    if (budget.scopeType == 'all') {
      spent = await txDao.sumExpensesByCurrency(budget.currency, currentPeriod.from, currentPeriod.to);
    } else if (budget.scopeType == 'include' && budget.categoryIds != null) {
      try {
        final ids = (jsonDecode(budget.categoryIds!) as List).cast<String>();
        final expanded = _expandCategoryIds(ids, categories);
        spent = await txDao.sumExpensesByCurrencyAndCategories(budget.currency, expanded, currentPeriod.from, currentPeriod.to);
      } catch (_) {}
    } else if (budget.scopeType == 'exclude' && budget.categoryIds != null) {
      try {
        final ids = (jsonDecode(budget.categoryIds!) as List).cast<String>();
        final expanded = _expandCategoryIds(ids, categories);
        spent = await txDao.sumExpensesByCurrencyExcludingCategories(budget.currency, expanded, currentPeriod.from, currentPeriod.to);
      } catch (_) {}
    }
    
    final percentage = budget.amountBase > 0 ? spent / budget.amountBase : (spent > 0 ? 1.0 : 0.0);
    
    List<String> categoryNames = [];
    if (budget.scopeType != 'all' && budget.categoryIds != null) {
      try {
        final ids = (jsonDecode(budget.categoryIds!) as List).cast<String>();
        for (final id in ids) {
          final cat = categories.where((c) => c.id == id).firstOrNull;
          if (cat != null) categoryNames.add(cat.name);
        }
      } catch (_) {}
    }
    
    results.add(BudgetProgress(
      budget: budget,
      currentPeriod: currentPeriod,
      spentAmount: spent,
      limitAmount: budget.amountBase,
      percentageUsed: percentage,
      currency: budget.currency,
      isExpired: isExpired,
      categoryNames: categoryNames,
    ));
  }
  
  return results;
});

final activeBudgetWarningsProvider = Provider<List<BudgetProgress>>((ref) {
  final progressAsync = ref.watch(budgetProgressListProvider);
  final progressList = progressAsync.valueOrNull ?? [];
  
  return progressList.where((p) => !p.isExpired && (p.isCritical || p.isOverBudget)).toList();
});

final budgetHistoryProvider = FutureProvider.family<List<BudgetPeriodHistory>, String>((ref, budgetId) async {
  // Re-run whenever transactions change so history totals stay current.
  ref.watch(transactionCountByCurrencyProvider);

  final budgetsAsync = ref.watch(budgetListProvider);
  final budgets = budgetsAsync.valueOrNull ?? [];
  final budget = budgets.where((b) => b.id == budgetId).firstOrNull;
  
  if (budget == null || !budget.isRecurring) return [];
  
  final pastPeriods = BudgetPeriodCalculator.pastPeriods(budget);
  if (pastPeriods.isEmpty) return [];
  
  final txDao = ref.watch(transactionDaoProvider);
  final List<BudgetPeriodHistory> history = [];
  
  final categoriesForHistory = (ref.watch(categoryListProvider)).valueOrNull ?? [];

  for (final period in pastPeriods) {
    double spent = 0;
    
    if (budget.scopeType == 'all') {
      spent = await txDao.sumExpensesByCurrency(budget.currency, period.from, period.to);
    } else if (budget.scopeType == 'include' && budget.categoryIds != null) {
      try {
        final ids = (jsonDecode(budget.categoryIds!) as List).cast<String>();
        final expanded = _expandCategoryIds(ids, categoriesForHistory);
        spent = await txDao.sumExpensesByCurrencyAndCategories(budget.currency, expanded, period.from, period.to);
      } catch (_) {}
    } else if (budget.scopeType == 'exclude' && budget.categoryIds != null) {
      try {
        final ids = (jsonDecode(budget.categoryIds!) as List).cast<String>();
        final expanded = _expandCategoryIds(ids, categoriesForHistory);
        spent = await txDao.sumExpensesByCurrencyExcludingCategories(budget.currency, expanded, period.from, period.to);
      } catch (_) {}
    }
    
    final percentage = budget.amountBase > 0 ? spent / budget.amountBase : (spent > 0 ? 1.0 : 0.0);
    
    history.add(BudgetPeriodHistory(
      period: period,
      spentAmount: spent,
      limitAmount: budget.amountBase,
      percentageUsed: percentage,
    ));
  }
  
  return history;
});
