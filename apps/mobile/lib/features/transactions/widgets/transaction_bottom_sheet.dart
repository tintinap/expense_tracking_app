import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../../categories/widgets/category_bottom_sheet.dart';
import '../../shared/providers/shared_providers.dart';
import '../../budgets/providers/budget_providers.dart';
import '../providers/exchange_rate_providers.dart';
import 'package:drift/drift.dart' hide Column;
import 'currency_prefix_dropdown.dart';
import 'interactive_time_picker.dart';

enum TransactionTabType { expense, income, exchange }

class TransactionBottomSheet extends ConsumerStatefulWidget {
  final TransactionData? initialTransaction;
  final TransactionData? pairedTransaction;

  const TransactionBottomSheet({super.key, this.initialTransaction, this.pairedTransaction});

  static Future<void> show(BuildContext context, {TransactionData? transaction, TransactionData? pairedTransaction}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TransactionBottomSheet(initialTransaction: transaction, pairedTransaction: pairedTransaction),
    );
  }

  @override
  ConsumerState<TransactionBottomSheet> createState() => _TransactionBottomSheetState();
}

class _TransactionBottomSheetState extends ConsumerState<TransactionBottomSheet> {
  TransactionTabType _selectedTab = TransactionTabType.expense;
  
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _exchangeToAmountController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  late String _fromCurrency;
  late String _toCurrency;
  /// The top-level (parent) category the user picked
  String? _selectedCategoryId;
  /// The optional sub-category within the selected parent
  String? _selectedSubCategoryId;

  // Tracks which field the user is currently editing to prevent infinite update loops
  String? _lastEditedField;
  // Loading state for the "Get Rate" button
  bool _isFetchingRate = false;
  // Error message for the rate fetch
  // Error message for the rate fetch
  String? _rateError;

  bool _isRecurring = false;
  String? _recurrenceType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default currency to the user's base currency setting
    final baseCurrency = ref.read(baseCurrencyProvider);
    _fromCurrency = baseCurrency;
    _toCurrency = baseCurrency;

    if (widget.initialTransaction != null) {
      final tx = widget.initialTransaction!;
      _noteController.text = tx.note ?? '';
      _selectedDate = tx.transactionDate;
      _selectedCategoryId = tx.categoryId;
      // If editing a sub-category, resolve the parent
      // (handled in build via category list lookup)
      
      if (tx.transactionType == 'expense') {
        _selectedTab = TransactionTabType.expense;
        _amountController.text = tx.originalAmount.toString();
        _fromCurrency = tx.originalCurrency;
        _isRecurring = tx.isRecurring;
        _recurrenceType = tx.recurrenceType;
      } else if (tx.transactionType == 'currency_income') {
        _selectedTab = TransactionTabType.income;
        _amountController.text = tx.originalAmount.toString();
        _fromCurrency = tx.originalCurrency;
      } else {
        // Exchange transaction — determine out/in sides
        _selectedTab = TransactionTabType.exchange;
        final paired = widget.pairedTransaction;
        final isOut = tx.transactionType == 'currency_exchange_out';
        final outTx = isOut ? tx : paired;
        final inTx = isOut ? paired : tx;
        
        _fromCurrency = outTx?.originalCurrency ?? tx.originalCurrency;
        _amountController.text = (outTx?.originalAmount ?? tx.originalAmount).toString();
        
        if (inTx != null) {
          _toCurrency = inTx.originalCurrency;
          _exchangeToAmountController.text = inTx.originalAmount.toString();
          
          // Rate = fromAmount / toAmount (how many from-currency per 1 to-currency)
          final fromAmt = outTx?.originalAmount ?? tx.originalAmount;
          if (inTx.originalAmount > 0) {
            _exchangeRateController.text = (fromAmt / inTx.originalAmount).toStringAsFixed(2);
          }
        }
      }
    }
    _amountController.addListener(_onFromAmountChanged);
    _exchangeToAmountController.addListener(_onToAmountChanged);
    _exchangeRateController.addListener(_onRateChanged);
  }

  void _onFromAmountChanged() {
    if (_lastEditedField == 'from') return;
    _lastEditedField = 'from';
    _syncExchangeFields('from');
    _lastEditedField = null;
    setState(() {});
  }

  void _onToAmountChanged() {
    if (_lastEditedField == 'to') return;
    _lastEditedField = 'to';
    _syncExchangeFields('to');
    _lastEditedField = null;
    setState(() {});
  }

  void _onRateChanged() {
    if (_lastEditedField == 'rate') return;
    _lastEditedField = 'rate';
    _syncExchangeFields('rate');
    _lastEditedField = null;
    setState(() {});
  }

  /// Rate means: 1 TO-currency = Rate FROM-currency
  /// E.g. Rate 23.90 means 1 AUD = 23.90 THB
  /// Formulas: to = from / rate, from = to × rate, rate = from / to
  ///
  /// When exchange rate is filled:
  ///   - editing from → update to
  ///   - editing to → update from
  ///   - editing rate → update to only (from stays unchanged)
  /// When exchange rate is empty:
  ///   - any two filled fields → compute the third

  double? _parsePositiveAmount(String text) {
    final value = double.tryParse(text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  void _updateFieldWithoutListener(
    TextEditingController controller,
    VoidCallback listener,
    String value,
  ) {
    controller.removeListener(listener);
    controller.text = value;
    controller.addListener(listener);
  }

  void _syncExchangeFields(String editedField) {
    final from = _parsePositiveAmount(_amountController.text);
    final to = _parsePositiveAmount(_exchangeToAmountController.text);
    final rate = _parsePositiveAmount(_exchangeRateController.text);

    if (editedField == 'rate') {
      // Rate changed → keep from, recalculate to
      if (rate != null && from != null) {
        _updateFieldWithoutListener(
          _exchangeToAmountController,
          _onToAmountChanged,
          (from / rate).toStringAsFixed(2),
        );
      }
      return;
    }

    if (rate != null) {
      if (editedField == 'from' && from != null) {
        _updateFieldWithoutListener(
          _exchangeToAmountController,
          _onToAmountChanged,
          (from / rate).toStringAsFixed(2),
        );
      } else if (editedField == 'to' && to != null) {
        _updateFieldWithoutListener(
          _amountController,
          _onFromAmountChanged,
          (to * rate).toStringAsFixed(2),
        );
      }
      return;
    }

    // Rate empty → fill whichever field is missing when two are known
    if (from != null && to != null) {
      _updateFieldWithoutListener(
        _exchangeRateController,
        _onRateChanged,
        (from / to).toStringAsFixed(2),
      );
    }
  }

  /// Fetches the recommended exchange rate via the 3-tier strategy:
  /// Local DB → Backend Server → Direct Frankfurter API
  Future<void> _fetchRecommendedRate() async {
    if (_fromCurrency == _toCurrency) return;

    setState(() {
      _isFetchingRate = true;
      _rateError = null;
    });

    try {
      final repo = ref.read(exchangeRateRepositoryProvider);

      // The UI rate = "1 _toCurrency = ? _fromCurrency"
      // So baseCurrency = _toCurrency, quoteCurrency = _fromCurrency
      final result = await repo.getRecommendedRate(
        baseCurrency: _toCurrency,
        quoteCurrency: _fromCurrency,
        date: _selectedDate,
      );

      if (!mounted) return;

      _updateFieldWithoutListener(
        _exchangeRateController,
        _onRateChanged,
        result.rate.toStringAsFixed(2),
      );

      // Recalculate to amount from from amount (rate change keeps from fixed)
      _syncExchangeFields('rate');

      setState(() => _isFetchingRate = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rate loaded from ${result.source}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingRate = false;
        _rateError = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onFromAmountChanged);
    _exchangeToAmountController.removeListener(_onToAmountChanged);
    _exchangeRateController.removeListener(_onRateChanged);
    _amountController.dispose();
    _noteController.dispose();
    _exchangeToAmountController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  /// Formats a [TimeOfDay] respecting the system 24h / AM-PM preference.
  String _formatTime(BuildContext context, TimeOfDay time) {
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    if (use24h) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  /// Return only top-level (parent) categories for the first dropdown.
  List<DropdownMenuItem<String>> _buildParentDropdownItems(List<CategoryData> allCategories) {
    final parents = allCategories.where((c) => c.parentId == null).toList();
    return parents.map((c) => DropdownMenuItem<String>(
      value: c.id,
      child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    )).toList();
  }

  /// Return sub-category items for the selected parent.
  List<DropdownMenuItem<String?>> _buildSubDropdownItems(
    List<CategoryData> allCategories,
    String parentId,
  ) {
    final children = allCategories.where((c) => c.parentId == parentId).toList();
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('— None —'),
      ),
    ];
    items.addAll(children.map((c) => DropdownMenuItem<String?>(
      value: c.id,
      child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    )));
    return items;
  }

  /// Opens [CategoryBottomSheet] in sub-category mode, then auto-selects the
  /// newly created sub-category once it appears in the category list.
  Future<void> _addSubCategory(CategoryData parent) async {
    // Need the full list (incl. hidden) so the diff isn't skewed by hidden ones.
    final beforeIds = (ref.read(categoryListProvider).valueOrNull ?? const [])
        .map((c) => c.id)
        .toSet();

    await CategoryBottomSheet.show(
      context,
      parentId: parent.id,
      parentName: parent.name,
      parentColor: parent.colourHex,
      parentIconCodePoint: parent.iconCodePoint,
    );

    if (!mounted) return;

    // Find the newly created sub-category for this parent.
    final after = ref.read(categoryListProvider).valueOrNull ?? const [];
    final newSubs = after
        .where((c) => c.parentId == parent.id && !beforeIds.contains(c.id))
        .toList();
    if (newSubs.isNotEmpty) {
      setState(() => _selectedSubCategoryId = newSubs.first.id);
    }
  }

  void _save() async {
    if (_isSaving) return;

    final amountText = _amountController.text;
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    if (_selectedTab == TransactionTabType.exchange && _fromCurrency == _toCurrency) {
      return;
    }

    if (_selectedTab == TransactionTabType.expense && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dao = ref.read(transactionDaoProvider);
    final db = ref.read(databaseProvider);
    final balanceDao = ref.read(currencyBalanceDaoProvider);
    final baseCurrency = ref.read(baseCurrencyProvider);
    final viewCurrency = ref.read(viewCurrencyProvider);
    final rateDao = ref.read(exchangeRateDaoProvider);

    final id = widget.initialTransaction?.id ?? const Uuid().v4();
    final now = DateTime.now();

    if (_selectedTab == TransactionTabType.exchange) {
      final toAmount = double.tryParse(_exchangeToAmountController.text);
      if (toAmount == null || toAmount <= 0) return;

      final isEditing = widget.initialTransaction != null;
      
      // Determine which side is the out and which is the in
      final initTx = widget.initialTransaction;
      final pairedTx = widget.pairedTransaction;
      final isInitOut = initTx?.transactionType == 'currency_exchange_out';
      
      // Preserve existing IDs when editing, generate new ones when creating
      final eventId = isEditing 
          ? (initTx!.exchangeEventId ?? const Uuid().v4())
          : const Uuid().v4();
      final outId = isEditing
          ? (isInitOut ? initTx!.id : pairedTx?.id ?? const Uuid().v4())
          : id;
      final inId = isEditing
          ? (isInitOut ? pairedTx?.id ?? const Uuid().v4() : initTx!.id)
          : const Uuid().v4();

      double outExchangeRate = 1.0;
      double outAmountBase = amount;
      if (_fromCurrency != baseCurrency) {
        outExchangeRate = await rateDao.getMostRecentOrFetch(_fromCurrency, baseCurrency);
        outAmountBase = amount * outExchangeRate;
        // Also cache originalCurrency → viewCurrency so the list tile can show
        // a direct VND→THB estimate instead of hiding it.
        if (viewCurrency != baseCurrency && viewCurrency != _fromCurrency) {
          await rateDao.getMostRecentOrFetch(_fromCurrency, viewCurrency);
        }
      }

      double inExchangeRate = 1.0;
      double inAmountBase = toAmount;
      if (_toCurrency != baseCurrency) {
        inExchangeRate = await rateDao.getMostRecentOrFetch(_toCurrency, baseCurrency);
        inAmountBase = toAmount * inExchangeRate;
        // Same for the in-side currency.
        if (viewCurrency != baseCurrency && viewCurrency != _toCurrency) {
          await rateDao.getMostRecentOrFetch(_toCurrency, viewCurrency);
        }
      }
      
      final outSide = TransactionsCompanion.insert(
        id: outId,
        transactionType: 'currency_exchange_out',
        amountBase: outAmountBase,
        originalAmount: amount,
        originalCurrency: _fromCurrency,
        exchangeRate: outExchangeRate,
        rateDate: _selectedDate,
        exchangeEventId: Value(eventId),
        transactionDate: _selectedDate,
        note: Value(_noteController.text),
      );

      final inSide = TransactionsCompanion.insert(
        id: inId,
        transactionType: 'currency_exchange_in',
        amountBase: inAmountBase,
        originalAmount: toAmount,
        originalCurrency: _toCurrency,
        exchangeRate: inExchangeRate,
        rateDate: _selectedDate,
        exchangeEventId: Value(eventId),
        transactionDate: _selectedDate,
        note: Value(_noteController.text),
      );

      if (isEditing) {
        await dao.updateTransaction(outSide);
        await dao.updateTransaction(inSide);
      } else {
        await dao.insertTransaction(outSide);
        await dao.insertTransaction(inSide);
        // Adjust balances only on create
        await balanceDao.adjustBalance(_fromCurrency, -amount);
        await balanceDao.adjustBalance(_toCurrency, toAmount);
      }
      
      if (mounted) Navigator.pop(context);
      return;
    }

    String txType = _selectedTab == TransactionTabType.income ? 'currency_income' : 'expense';

    double exchangeRate = 1.0;
    double amountBase = amount;
    if (_fromCurrency != baseCurrency) {
      exchangeRate = await rateDao.getMostRecentOrFetch(_fromCurrency, baseCurrency);
      amountBase = amount * exchangeRate;
      // Also cache originalCurrency → viewCurrency so the list tile and
      // detail sheet can show a direct VND→THB estimate rather than hiding
      // it or falling back to the indirect AUD path.
      if (viewCurrency != baseCurrency && viewCurrency != _fromCurrency) {
        await rateDao.getMostRecentOrFetch(_fromCurrency, viewCurrency);
      }
    }
    
    final entry = TransactionsCompanion.insert(
      id: id,
      transactionType: txType,
      amountBase: amountBase,
      originalAmount: amount,
      originalCurrency: _fromCurrency,
      exchangeRate: exchangeRate,
      rateDate: _selectedDate,
      categoryId: Value(_selectedSubCategoryId ?? _selectedCategoryId),
      note: Value(_noteController.text),
      transactionDate: _selectedDate,
      isRecurring: Value(_selectedTab == TransactionTabType.expense ? _isRecurring : false),
      recurrenceType: Value(_selectedTab == TransactionTabType.expense && _isRecurring ? _recurrenceType : null),
      updatedAt: Value(now),
      syncStatus: const Value('pending'),
    );

    if (widget.initialTransaction != null) {
      await dao.updateTransaction(entry);
    } else {
      await dao.insertTransaction(entry);
      // Adjust balance: income adds, expense subtracts
      final delta = _selectedTab == TransactionTabType.income ? amount : -amount;
      await balanceDao.adjustBalance(_fromCurrency, delta);
    }

    await db.addToSyncQueue(
      id: const Uuid().v4(),
      recordType: 'transaction',
      recordId: id,
      operation: widget.initialTransaction != null ? 'update' : 'insert',
      payload: '{}',
    );

    if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    // Check for negative balance warning
    bool showNegativeWarning = false;
    double currentBalance = 0;
    if (_selectedTab != TransactionTabType.income) {
      final amount = double.tryParse(_amountController.text) ?? 0;
      final balances = ref.watch(currencyBalancesProvider).valueOrNull ?? [];
      final match = balances.where((b) => b.currency == _fromCurrency).firstOrNull;
      currentBalance = match?.balance ?? 0;
      if (amount > 0 && (currentBalance - amount < 0)) {
        showNegativeWarning = true;
      }
    }

    final isExchangeInvalid = _selectedTab == TransactionTabType.exchange && _fromCurrency == _toCurrency;
    
    // Effective category for matching (sub overrides parent).
    // _selectedCategoryId is always the top-level parent.
    final effectiveCategoryId = _selectedSubCategoryId ?? _selectedCategoryId;

    // All IDs the current transaction "belongs to":
    // the effective (leaf) category plus its parent (if a sub-category was picked).
    final txCategoryIds = <String>{
      if (effectiveCategoryId != null) effectiveCategoryId,
      if (_selectedCategoryId != null) _selectedCategoryId!,
    };

    final allCategoriesForBudget = ref.watch(activeCategoryListProvider);

    // Expand a list of budget category IDs so that any parent ID also covers
    // all of its children (budget for "Food" should fire for "Restaurant").
    Set<String> expandBudgetIds(List<String> ids) {
      final expanded = <String>{...ids};
      for (final id in ids) {
        for (final child in allCategoriesForBudget) {
          if (child.parentId == id) expanded.add(child.id);
        }
      }
      return expanded;
    }

    // Returns true if a budget's scope covers the current expense category.
    bool budgetCoversCategory(BudgetProgress prog) {
      switch (prog.budget.scopeType) {
        case 'all':
          return true;
        case 'include':
          try {
            final ids =
                (jsonDecode(prog.budget.categoryIds!) as List).cast<String>();
            final expanded = expandBudgetIds(ids);
            return txCategoryIds.any(expanded.contains);
          } catch (_) {
            return false;
          }
        case 'exclude':
          try {
            final ids =
                (jsonDecode(prog.budget.categoryIds!) as List).cast<String>();
            final expanded = expandBudgetIds(ids);
            // Require a category to be selected; no selection = no warning.
            return txCategoryIds.isNotEmpty &&
                txCategoryIds.every((id) => !expanded.contains(id));
          } catch (_) {
            return true;
          }
        default:
          return false;
      }
    }

    // Budget warnings: budgets already over threshold (90 % / 100 %)
    final budgetWarnings = ref.watch(activeBudgetWarningsProvider);
    final activeWarningsForCurrency = budgetWarnings.where((w) {
      if (_selectedTab != TransactionTabType.expense) return false;
      if (w.currency != _fromCurrency) return false;
      return budgetCoversCategory(w);
    }).toList();

    // "Would exceed" warnings: this expense would push a budget over its limit
    final wouldExceedWarnings = () {
      if (_selectedTab != TransactionTabType.expense) return <BudgetProgress>[];
      final newAmount = double.tryParse(_amountController.text) ?? 0.0;
      if (newAmount <= 0) return <BudgetProgress>[];

      final progressList =
          ref.watch(budgetProgressListProvider).valueOrNull ?? [];

      return progressList.where((prog) {
        if (prog.isExpired) return false;
        if (prog.budget.currency != _fromCurrency) return false;
        if (prog.isOverBudget) return false;
        if (!budgetCoversCategory(prog)) return false;

        if (_selectedDate.isBefore(prog.currentPeriod.from) ||
            _selectedDate.isAfter(prog.currentPeriod.to)) {
          return false;
        }

        return prog.spentAmount + newAmount > prog.limitAmount;
      }).toList();
    }();
    
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomPadding + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<TransactionTabType>(
              segments: const [
                ButtonSegment(value: TransactionTabType.expense, label: Text('Expense')),
                ButtonSegment(value: TransactionTabType.income, label: Text('Income')),
                ButtonSegment(value: TransactionTabType.exchange, label: Text('Exchange')),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (set) => setState(() {
                final newTab = set.first;
                _selectedTab = newTab;
                // Clear category when switching away from Expense tab so that
                // income/exchange transactions don't retain a leftover category
                // (which would show the wrong icon in the transaction list).
                if (newTab != TransactionTabType.expense) {
                  _selectedCategoryId = null;
                  _selectedSubCategoryId = null;
                }
              }),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _selectedTab == TransactionTabType.exchange ? 'From Amount' : 'Amount',
                prefixIcon: CurrencyPrefixDropdown(
                  selectedCurrency: _fromCurrency,
                  onChanged: (val) => setState(() => _fromCurrency = val),
                ),
              ),
              autofocus: true,
            ),
            
            if (showNegativeWarning) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ This transaction exceeds your $_fromCurrency balance ($currentBalance).',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ],
            
            if (activeWarningsForCurrency.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: activeWarningsForCurrency.map((w) {
                    final budgetName = w.budget.name?.isNotEmpty == true
                        ? w.budget.name!
                        : (w.budget.scopeType == 'all'
                            ? 'Global Budget'
                            : 'Category Budget');
                    return Text(
                      '⚠️ "$budgetName" is ${w.isOverBudget ? "exceeded" : "near its limit"}!',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            if (wouldExceedWarnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Budget limit alert',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...wouldExceedWarnings.map((prog) {
                      final newAmount = double.tryParse(_amountController.text) ?? 0.0;
                      final projectedSpent = prog.spentAmount + newAmount;
                      final overage = projectedSpent - prog.limitAmount;
                      final budgetName = prog.budget.name?.isNotEmpty == true
                          ? prog.budget.name!
                          : (prog.budget.scopeType == 'all'
                              ? 'Global Budget'
                              : 'Category Budget');
                      return Text(
                        '"$budgetName" (${prog.budget.currency}): ${prog.spentAmount.toStringAsFixed(2)} + ${newAmount.toStringAsFixed(2)} = ${projectedSpent.toStringAsFixed(2)} / ${prog.limitAmount.toStringAsFixed(2)}  (+${overage.toStringAsFixed(2)} over limit)',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                          fontSize: 12,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            
            if (_selectedTab == TransactionTabType.exchange) ...[
              const SizedBox(height: 12),
              // Exchange Rate field with "Get Rate" button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _exchangeRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Exchange Rate',
                        hintText: '1 $_toCurrency = ? $_fromCurrency',
                        prefixIcon: const Icon(Icons.swap_horiz),
                        helperText: 'How many $_fromCurrency per 1 $_toCurrency',
                        errorText: _rateError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _isFetchingRate
                        ? const SizedBox(
                            width: 48,
                            height: 48,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton.filled(
                            onPressed: (_fromCurrency == _toCurrency)
                                ? null
                                : _fetchRecommendedRate,
                            icon: const Icon(Icons.auto_awesome),
                            tooltip: 'Get recommended rate',
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _exchangeToAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'To Amount',
                  prefixIcon: CurrencyPrefixDropdown(
                    selectedCurrency: _toCurrency,
                    onChanged: (val) => setState(() => _toCurrency = val),
                  ),
                ),
              ),
              if (isExchangeInvalid) ...[
                const SizedBox(height: 8),
                Text(
                  '❌ "From" and "To" currencies must be different.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ],
            ],
            
            if (_selectedTab == TransactionTabType.expense) ...[
              const SizedBox(height: 16),
              Builder(builder: (context) {
                final allCategories = ref.watch(activeCategoryListProvider);
                final subItems = _selectedCategoryId != null
                    ? _buildSubDropdownItems(allCategories, _selectedCategoryId!)
                    : <DropdownMenuItem<String?>>[];
                
                // When editing a sub-category, resolve initial parent
                if (_selectedCategoryId != null && _selectedSubCategoryId == null) {
                  final cat = allCategories.where((c) => c.id == _selectedCategoryId).firstOrNull;
                  if (cat != null && cat.parentId != null) {
                    // This is actually a sub-category; separate parent from sub
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _selectedSubCategoryId = cat.id;
                          _selectedCategoryId = cat.parentId;
                        });
                      }
                    });
                  }
                }

                final selectedParent = _selectedCategoryId == null
                    ? null
                    : allCategories
                        .where((c) => c.id == _selectedCategoryId)
                        .firstOrNull;
                final hasSubCategories = subItems.length > 1;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // First dropdown: parent category
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedCategoryId,
                      hint: const Text('Select Category', maxLines: 1, overflow: TextOverflow.ellipsis),
                      items: _buildParentDropdownItems(allCategories),
                      onChanged: (id) => setState(() {
                        _selectedCategoryId = id;
                        _selectedSubCategoryId = null;
                      }),
                    ),
                    // Sub-category row: dropdown + "add sub" button.
                    if (selectedParent != null) ...[
                      const SizedBox(height: 12),
                      if (hasSubCategories)
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                isExpanded: true,
                                initialValue: _selectedSubCategoryId,
                                hint: const Text(
                                  'Select Sub-category (optional)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                items: subItems,
                                onChanged: (id) =>
                                    setState(() => _selectedSubCategoryId = id),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: 'Add sub-category',
                              icon: const Icon(Icons.add),
                              onPressed: () => _addSubCategory(selectedParent),
                            ),
                          ],
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _addSubCategory(selectedParent),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add sub-category'),
                          ),
                        ),
                    ],
                  ],
                );
              }),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDate.toString().split(' ')[0]),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          // Preserve the already-selected time when changing date
                          _selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            _selectedDate.hour,
                            _selectedDate.minute,
                            _selectedDate.second,
                          );
                        });
                      }
                    },
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    _formatTime(context, TimeOfDay.fromDateTime(_selectedDate)),
                  ),
                  onPressed: () async {
                    final time = await InteractiveTimePicker.show(
                      context,
                      TimeOfDay.fromDateTime(_selectedDate),
                    );
                    if (time != null) {
                      setState(() {
                        _selectedDate = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (Optional)'),
            ),

            if (_selectedTab == TransactionTabType.expense) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Recurring Expense'),
                subtitle: const Text('Auto-logs in the future'),
                value: _isRecurring,
                onChanged: (val) {
                  setState(() {
                    _isRecurring = val;
                    if (val && _recurrenceType == null) {
                      _recurrenceType = 'monthly';
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (_isRecurring)
                DropdownButtonFormField<String>(
                  value: _recurrenceType,
                  decoration: const InputDecoration(labelText: 'Repeats'),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'fortnightly', child: Text('Fortnightly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (val) => setState(() => _recurrenceType = val),
                ),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: (isExchangeInvalid || _isSaving) ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
