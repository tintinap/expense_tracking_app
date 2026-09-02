import 'dart:convert';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/daos/transaction_dao.dart' show CurrencyBreakdown;
import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';


/// PRD §21 — Period Selector State
enum PeriodType { daily, weekly, fortnightly, monthly, yearly, custom }

class PeriodState {
  final PeriodType type;
  final DateTime from;
  final DateTime to;

  const PeriodState({
    required this.type,
    required this.from,
    required this.to,
  });
}

class PeriodNotifier extends Notifier<PeriodState> {
  @override
  PeriodState build() {
    final now = DateTime.now();
    return _calculatePeriod(PeriodType.daily, now);
  }

  PeriodState _calculatePeriod(PeriodType type, DateTime referenceDate) {
    DateTime from;
    DateTime to;

    switch (type) {
      case PeriodType.daily:
        from = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
        to = DateTime(referenceDate.year, referenceDate.month, referenceDate.day, 23, 59, 59);
        break;
      case PeriodType.weekly:
        // Assuming Monday is start of week
        final daysToMonday = referenceDate.weekday - 1;
        from = DateTime(referenceDate.year, referenceDate.month, referenceDate.day - daysToMonday);
        to = from.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case PeriodType.fortnightly:
        final daysToMonday = referenceDate.weekday - 1;
        from = DateTime(referenceDate.year, referenceDate.month, referenceDate.day - daysToMonday);
        to = from.add(const Duration(days: 13, hours: 23, minutes: 59, seconds: 59));
        break;
      case PeriodType.monthly:
        from = DateTime(referenceDate.year, referenceDate.month, 1);
        to = DateTime(referenceDate.year, referenceDate.month + 1, 0, 23, 59, 59);
        break;
      case PeriodType.yearly:
        from = DateTime(referenceDate.year, 1, 1);
        to = DateTime(referenceDate.year, 12, 31, 23, 59, 59);
        break;
      case PeriodType.custom:
        from = state.from;
        to = state.to;
        break;
    }

    return PeriodState(type: type, from: from, to: to);
  }

  void setType(PeriodType type) {
    if (type == PeriodType.custom) return; // Custom handled separately
    state = _calculatePeriod(type, DateTime.now());
  }

  void setToday() {
    state = _calculatePeriod(state.type, DateTime.now());
  }

  void setDate(DateTime date) {
    if (state.type == PeriodType.custom) return;
    state = _calculatePeriod(state.type, date);
  }

  void previous() {
    if (state.type == PeriodType.custom) return;
    
    DateTime ref;
    switch (state.type) {
      case PeriodType.daily:
        ref = state.from.subtract(const Duration(days: 1));
      case PeriodType.weekly:
        ref = state.from.subtract(const Duration(days: 7));
      case PeriodType.fortnightly:
        ref = state.from.subtract(const Duration(days: 14));
      case PeriodType.monthly:
        ref = DateTime(state.from.year, state.from.month - 1, 1);
      case PeriodType.yearly:
        ref = DateTime(state.from.year - 1, 1, 1);
      case PeriodType.custom:
        return;
    }
    state = _calculatePeriod(state.type, ref);
  }

  void next() {
    if (state.type == PeriodType.custom) return;

    DateTime ref;
    switch (state.type) {
      case PeriodType.daily:
        ref = state.from.add(const Duration(days: 1));
      case PeriodType.weekly:
        ref = state.from.add(const Duration(days: 7));
      case PeriodType.fortnightly:
        ref = state.from.add(const Duration(days: 14));
      case PeriodType.monthly:
        ref = DateTime(state.from.year, state.from.month + 1, 1);
      case PeriodType.yearly:
        ref = DateTime(state.from.year + 1, 1, 1);
      case PeriodType.custom:
        return;
    }
    state = _calculatePeriod(state.type, ref);
  }
}

/// Provides the currently selected period for filtering transactions
final selectedPeriodProvider = NotifierProvider<PeriodNotifier, PeriodState>(() => PeriodNotifier());

/// PRD §21 — Transaction List Provider (Filtered by period)
final transactionListProvider = StreamProvider<List<TransactionData>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  final dao = ref.watch(transactionDaoProvider);
  return dao.watchByDateRange(period.from, period.to);
});

/// Cached `currency → number of non-deleted transactions` (all-time).
///
/// Backed by a Drift watched aggregate query, so it only re-runs when the
/// `transactions` table actually changes. Riverpod then caches the latest
/// emission and shares it across every consumer (single read per change).
final transactionCountByCurrencyProvider =
    StreamProvider<Map<String, int>>((ref) {
  final dao = ref.watch(transactionDaoProvider);
  return dao.watchCountByCurrency();
});

/// Cached `currency → CurrencyBreakdown` (income / spent / net exchanged).
///
/// PRD §11c — drives the per-currency breakdown row on each Currency Card.
/// Same caching rationale as [transactionCountByCurrencyProvider]: a single
/// watched aggregate query, shared across every card.
final currencyBreakdownProvider =
    StreamProvider<Map<String, CurrencyBreakdown>>((ref) {
  final dao = ref.watch(transactionDaoProvider);
  return dao.watchBreakdownByCurrency();
});

/// PRD §21 — Expense List Provider (Derived from transactionListProvider)
final expenseListProvider = Provider<List<TransactionData>>((ref) {
  final transactions = ref.watch(transactionListProvider).valueOrNull ?? [];
  final enabledCurrencies = ref.watch(enabledCurrenciesProvider);
  return transactions
      .where((t) => t.transactionType == 'expense' && enabledCurrencies.contains(t.originalCurrency))
      .toList();
});

/// PRD §21 — Category List Provider (All)
final categoryListProvider = StreamProvider<List<CategoryData>>((ref) {
  final dao = ref.watch(categoryDaoProvider);
  return dao.watchAll();
});

/// PRD §21 — Active Category List Provider (Non-hidden)
final activeCategoryListProvider = Provider<List<CategoryData>>((ref) {
  final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
  return categories.where((c) => !c.isHidden).toList();
});

/// PRD §21 — Budget List Provider
final budgetListProvider = StreamProvider<List<BudgetData>>((ref) {
  final dao = ref.watch(budgetDaoProvider);
  return dao.watchActive();
});

/// PRD §21 — Currency Balances Provider
final currencyBalancesProvider = StreamProvider<List<CurrencyBalanceData>>((ref) {
  final dao = ref.watch(currencyBalanceDaoProvider);
  return dao.watchBalances();
});

/// PRD §21 — Base Currency Provider (persisted in `settings` table).
class BaseCurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return 'AUD';
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final value = await db.getSetting('base_currency');
    final currentBase = (value != null && value.isNotEmpty) ? value : 'AUD';
    if (value != null && value.isNotEmpty) state = value;

    // Trigger full database re-conversion for transactions on startup to ensure consistency
    final txDao = ref.read(transactionDaoProvider);
    final rateDao = ref.read(exchangeRateDaoProvider);
    await txDao.recalculateBaseAmounts(currentBase, (from, to) async {
      return await rateDao.getMostRecentOrFetch(from, to);
    });
  }

  Future<void> set(String code) async {
    final upper = code.toUpperCase();
    if (state == upper) return;

    final db = ref.read(databaseProvider);
    await db.setSetting('base_currency', upper);
    state = upper;

    // Trigger full database re-conversion for transactions
    final txDao = ref.read(transactionDaoProvider);
    final rateDao = ref.read(exchangeRateDaoProvider);
    
    await txDao.recalculateBaseAmounts(upper, (from, to) async {
      return await rateDao.getMostRecentOrFetch(from, to);
    });
  }
}

final baseCurrencyProvider =
    NotifierProvider<BaseCurrencyNotifier, String>(BaseCurrencyNotifier.new);

/// PRD §21 — View Currency Provider (Display only, persisted in `settings`).
class ViewCurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return 'AUD';
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final value = await db.getSetting('view_currency');
    if (value != null && value.isNotEmpty) state = value;
  }

  Future<void> set(String code) async {
    final upper = code.toUpperCase();
    final db = ref.read(databaseProvider);
    await db.setSetting('view_currency', upper);
    state = upper;
  }
}

final viewCurrencyProvider =
    NotifierProvider<ViewCurrencyNotifier, String>(ViewCurrencyNotifier.new);

class EnabledCurrenciesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final base = ref.watch(baseCurrencyProvider);
    _load(base);
    return [base];
  }

  Future<void> _load(String base) async {
    final db = ref.read(databaseProvider);
    final value = await db.getSetting('enabled_calculation_currencies');
    if (value != null && value.isNotEmpty) {
      try {
        final list = (jsonDecode(value) as List).cast<String>();
        if (!list.contains(base)) {
          list.add(base);
        }
        state = list;
      } catch (_) {
        state = [base];
      }
    } else {
      state = [base];
    }
  }

  Future<void> toggleCurrency(String currency, bool enable) async {
    final base = ref.read(baseCurrencyProvider);
    if (currency == base && !enable) return;

    final newList = List<String>.from(state);
    if (enable) {
      if (!newList.contains(currency)) {
        newList.add(currency);
      }
    } else {
      newList.remove(currency);
    }

    final db = ref.read(databaseProvider);
    await db.setSetting('enabled_calculation_currencies', jsonEncode(newList));
    state = newList;
  }
}

final enabledCurrenciesProvider =
    NotifierProvider<EnabledCurrenciesNotifier, List<String>>(EnabledCurrenciesNotifier.new);

/// PRD §21 — View Currency Exchange Rate
/// Provides the current exchange rate from Base Currency to View Currency
final viewCurrencyRateProvider = FutureProvider<double>((ref) async {
  final baseCurrency = ref.watch(baseCurrencyProvider);
  final viewCurrency = ref.watch(viewCurrencyProvider);
  if (baseCurrency == viewCurrency) return 1.0;

  final rateDao = ref.watch(exchangeRateDaoProvider);
  final rate = await rateDao.getMostRecentOrFetch(baseCurrency, viewCurrency);
  return rate;
});

/// Per-transaction view amount provider.
///
/// Converts [originalAmount] from [fromCurrency] to the current view currency
/// using a **DB-only cached rate** for the transaction's date.
///
/// Returns `null` when:
/// - [fromCurrency] == view currency (no conversion needed / don't show)
/// - No cached rate exists for this pair at all (no connectivity at save time)
///
/// Key format: "$fromCurrency|$toCurrency|$dateStr|$originalAmount"
typedef _TxViewKey = ({
  String fromCurrency,
  String toCurrency,
  String dateKey, // "yyyy-MM-dd"
  double originalAmount,
});

final txViewAmountProvider =
    FutureProvider.family<double?, _TxViewKey>((ref, args) async {
  if (args.fromCurrency == args.toCurrency) return null;

  final rateDao = ref.watch(exchangeRateDaoProvider);
  final date = DateTime.parse(args.dateKey);
  final rate = await rateDao.getForDateOrRecent(
    args.fromCurrency,
    args.toCurrency,
    date,
  );
  if (rate == null) return null;
  return args.originalAmount * rate;
});

/// Persisted theme-mode preference (system / light / dark).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final value = await db.getSetting('theme_mode');
    state = _decode(value);
  }

  Future<void> set(ThemeMode mode) async {
    final db = ref.read(databaseProvider);
    await db.setSetting('theme_mode', _encode(mode));
    state = mode;
  }

  static ThemeMode _decode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// PRD §21 — Dashboard Summary Provider
class DashboardSummary {
  final double totalSpent;
  final double totalIncome;
  final double netBalance;
  final String topCategoryName;
  final double topCategoryAmount;
  final int transactionCount;

  const DashboardSummary({
    required this.totalSpent,
    required this.totalIncome,
    required this.netBalance,
    required this.topCategoryName,
    required this.topCategoryAmount,
    required this.transactionCount,
  });
}

final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  final transactions = ref.watch(transactionListProvider).valueOrNull ?? [];
  final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
  final enabledCurrencies = ref.watch(enabledCurrenciesProvider);

  // Filter transactions by enabled currencies
  final filteredTransactions = transactions
      .where((t) => enabledCurrencies.contains(t.originalCurrency))
      .toList();

  final expenses = filteredTransactions.where((t) => t.transactionType == 'expense').toList();
  final incomes = filteredTransactions.where((t) => t.transactionType == 'currency_income').toList();
  
  double totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amountBase.abs());
  double totalIncome = incomes.fold(0.0, (sum, i) => sum + i.amountBase.abs());
  double netBalance = totalIncome - totalSpent;

  if (expenses.isEmpty) {
    return DashboardSummary(
      totalSpent: 0,
      totalIncome: totalIncome,
      netBalance: netBalance,
      topCategoryName: 'None',
      topCategoryAmount: 0,
      transactionCount: 0,
    );
  }

  final categoryTotals = <String, double>{};
  for (final expense in expenses) {
    if (expense.categoryId != null) {
      // Resolve sub-category to parent for display grouping
      final cat = categories.where((c) => c.id == expense.categoryId).firstOrNull;
      final displayId = (cat != null && cat.parentId != null) ? cat.parentId! : expense.categoryId!;
      categoryTotals[displayId] = (categoryTotals[displayId] ?? 0) + expense.amountBase.abs();
    }
  }

  String topCategoryId = '';
  double maxAmount = 0;
  
  categoryTotals.forEach((id, amount) {
    if (amount > maxAmount) {
      maxAmount = amount;
      topCategoryId = id;
    }
  });

  String topCategoryName = 'Unknown';
  if (topCategoryId.isNotEmpty) {
    final cat = categories.where((c) => c.id == topCategoryId).firstOrNull;
    if (cat != null) topCategoryName = cat.name;
  }

  return DashboardSummary(
    totalSpent: totalSpent,
    totalIncome: totalIncome,
    netBalance: netBalance,
    topCategoryName: topCategoryName,
    topCategoryAmount: maxAmount,
    transactionCount: expenses.length,
  );
});
