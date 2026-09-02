import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/shared_providers.dart';

class DashboardSummaryCards extends ConsumerWidget {
  const DashboardSummaryCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final viewCurrency = ref.watch(viewCurrencyProvider);
    final viewRate = ref.watch(viewCurrencyRateProvider).valueOrNull ?? 1.0;
    final summary = ref.watch(dashboardSummaryProvider);
    final theme = Theme.of(context);

    final String netBalanceTooltip = baseCurrency != viewCurrency
        ? 'Income: +$baseCurrency ${summary.totalIncome.toStringAsFixed(2)} (≈ $viewCurrency ${(summary.totalIncome * viewRate).toStringAsFixed(2)})\n'
            'Expenses: -$baseCurrency ${summary.totalSpent.toStringAsFixed(2)} (≈ $viewCurrency ${(summary.totalSpent * viewRate).toStringAsFixed(2)})'
        : 'Income: +$baseCurrency ${summary.totalIncome.toStringAsFixed(2)}\n'
            'Expenses: -$baseCurrency ${summary.totalSpent.toStringAsFixed(2)}';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCard(
                theme: theme,
                title: 'Total Spent',
                value: '$baseCurrency ${summary.totalSpent.toStringAsFixed(2)}',
                secondaryValue: baseCurrency != viewCurrency 
                    ? '≈ $viewCurrency ${(summary.totalSpent * viewRate).toStringAsFixed(2)}'
                    : null,
                subtitle: '${summary.transactionCount} transactions',
                color: theme.colorScheme.primaryContainer,
                onColor: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCard(
                theme: theme,
                title: 'Net Balance',
                value: '$baseCurrency ${summary.netBalance.toStringAsFixed(2)}',
                secondaryValue: baseCurrency != viewCurrency 
                    ? '≈ $viewCurrency ${(summary.netBalance * viewRate).toStringAsFixed(2)}'
                    : null,
                subtitle: 'Total Net Flow',
                color: theme.colorScheme.tertiaryContainer,
                onColor: theme.colorScheme.onTertiaryContainer,
                tooltipMessage: netBalanceTooltip,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCard(
          theme: theme,
          title: 'Top Category',
          value: summary.topCategoryName,
          secondaryValue: baseCurrency != viewCurrency && summary.topCategoryAmount > 0
              ? '≈ $viewCurrency ${(summary.topCategoryAmount * viewRate).toStringAsFixed(2)}'
              : null,
          subtitle: '$baseCurrency ${summary.topCategoryAmount.toStringAsFixed(2)} spent',
          color: theme.colorScheme.secondaryContainer,
          onColor: theme.colorScheme.onSecondaryContainer,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildCard({
    required ThemeData theme,
    required String title,
    required String value,
    String? secondaryValue,
    required String subtitle,
    required Color color,
    required Color onColor,
    bool isFullWidth = false,
    String? tooltipMessage,
  }) {
    final card = Container(
      width: isFullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(color: onColor),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onColor,
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
                color: onColor.withValues(alpha: 0.8),
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
              color: onColor.withOpacity(0.8),
            ),
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
