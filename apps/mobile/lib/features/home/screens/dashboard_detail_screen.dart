import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/period_selector.dart';
import '../../shared/providers/shared_providers.dart';
import '../widgets/category_donut_chart.dart';
import '../widgets/category_transactions_sheet.dart';

class DashboardDetailScreen extends ConsumerStatefulWidget {
  const DashboardDetailScreen({super.key});

  @override
  ConsumerState<DashboardDetailScreen> createState() => _DashboardDetailScreenState();
}

class _DashboardDetailScreenState extends ConsumerState<DashboardDetailScreen> {
  final Set<String> _excludedCategoryIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final viewCurrency = ref.watch(viewCurrencyProvider);
    final viewRate = ref.watch(viewCurrencyRateProvider).valueOrNull ?? 1.0;
    final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
    final expenses = ref.watch(expenseListProvider);
    final enabledCurrencies = ref.watch(enabledCurrenciesProvider);
    final rawTransactions = ref.watch(transactionListProvider).valueOrNull ?? [];
    final transactions = rawTransactions.where((t) => enabledCurrencies.contains(t.originalCurrency)).toList();

    // Get unique categories actively used in current period's expenses
    final activeCategoryIds = expenses
        .where((e) => e.categoryId != null)
        .map((e) => e.categoryId!)
        .toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: PeriodSelector(),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Builder(
                builder: (context) {
                  final filteredExpenses = expenses.where((e) => 
                      !_excludedCategoryIds.contains(e.categoryId)
                  );
                  final totalSpent = filteredExpenses.fold(0.0, (sum, e) => sum + e.amountBase.abs());
                  
                  final totalIncome = transactions
                      .where((t) => t.transactionType == 'currency_income')
                      .fold(0.0, (sum, t) => sum + t.amountBase.abs());
                      
                  final netBalance = totalIncome - totalSpent;

                  final categoryTotals = <String, double>{};
                  for (final expense in filteredExpenses) {
                    if (expense.categoryId != null) {
                      categoryTotals[expense.categoryId!] = (categoryTotals[expense.categoryId!] ?? 0) + expense.amountBase.abs();
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
                  
                  final topCategoryName = categories.where((c) => c.id == topCategoryId).firstOrNull?.name ?? 'None';
                  
                  final String netBalanceTooltip = baseCurrency != viewCurrency
                      ? 'Income: +$baseCurrency ${totalIncome.toStringAsFixed(2)} (≈ $viewCurrency ${(totalIncome * viewRate).toStringAsFixed(2)})\n'
                          'Expenses: -$baseCurrency ${totalSpent.toStringAsFixed(2)} (≈ $viewCurrency ${(totalSpent * viewRate).toStringAsFixed(2)})'
                      : 'Income: +$baseCurrency ${totalIncome.toStringAsFixed(2)}\n'
                          'Expenses: -$baseCurrency ${totalSpent.toStringAsFixed(2)}';

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              context, 
                              'Total Spent', 
                              '$baseCurrency ${totalSpent.toStringAsFixed(2)}', 
                              '${filteredExpenses.length} transactions',
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.onPrimaryContainer,
                              secondaryValue: baseCurrency != viewCurrency
                                  ? '≈ $viewCurrency ${(totalSpent * viewRate).toStringAsFixed(2)}'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSummaryCard(
                              context, 
                              'Net Balance', 
                              '$baseCurrency ${netBalance.toStringAsFixed(2)}', 
                              'Total Net Flow',
                              theme.colorScheme.tertiaryContainer,
                              theme.colorScheme.onTertiaryContainer,
                              secondaryValue: baseCurrency != viewCurrency
                                  ? '≈ $viewCurrency ${(netBalance * viewRate).toStringAsFixed(2)}'
                                  : null,
                              tooltipMessage: netBalanceTooltip,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryCard(
                        context,
                        'Top Category',
                        topCategoryName,
                        '$baseCurrency ${maxAmount.toStringAsFixed(2)} spent',
                        theme.colorScheme.secondaryContainer,
                        theme.colorScheme.onSecondaryContainer,
                        secondaryValue: baseCurrency != viewCurrency && maxAmount > 0
                            ? '≈ $viewCurrency ${(maxAmount * viewRate).toStringAsFixed(2)}'
                            : null,
                        isFullWidth: true,
                      ),
                    ],
                  );
                }
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Spend by Category',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CategoryDonutChart(
                        showViewCurrency: true,
                        excludedCategoryIds: _excludedCategoryIds,
                        onSliceTap: (parentId) =>
                            CategoryTransactionsSheet.show(
                          context,
                          parentCategoryId: parentId,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Categories',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),

          if (activeCategoryIds.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text('No categories in this period.', style: theme.textTheme.bodyMedium),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final catId = activeCategoryIds.elementAt(index);
                  final category = categories.where((c) => c.id == catId).firstOrNull;
                  final name = category?.name ?? 'Unknown Category';
                  final isExcluded = _excludedCategoryIds.contains(catId);

                  Color catColor = Colors.grey;
                  if (category != null && category.colourHex.startsWith('#')) {
                    try {
                       catColor = Color(int.parse(category.colourHex.substring(1, 7), radix: 16) + 0xFF000000);
                    } catch (_) {}
                  }

                  return CheckboxListTile(
                    title: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(name),
                      ],
                    ),
                    value: !isExcluded,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _excludedCategoryIds.remove(catId);
                        } else {
                          _excludedCategoryIds.add(catId);
                        }
                      });
                    },
                  );
                },
                childCount: activeCategoryIds.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, 
    String title, 
    String value, 
    String subtitle, 
    Color bgColor, 
    Color textColor, {
    String? secondaryValue,
    bool isFullWidth = false,
    String? tooltipMessage,
  }) {
    final theme = Theme.of(context);
    final card = Container(
      width: isFullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
            ),
          ),
          if (secondaryValue != null) ...[
            const SizedBox(height: 2),
            Text(
              secondaryValue,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor.withValues(alpha: 0.8),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor.withOpacity(0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (tooltipMessage != null) {
      return Tooltip(
        message: tooltipMessage,
        triggerMode: TooltipTriggerMode.longPress,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withOpacity(0.95),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: theme.colorScheme.surface,
          fontSize: 13,
          height: 1.4,
        ),
        child: card,
      );
    }
    return card;
  }
}

