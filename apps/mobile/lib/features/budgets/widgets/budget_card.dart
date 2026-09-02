import 'package:flutter/material.dart';

import '../providers/budget_providers.dart';

class BudgetCard extends StatelessWidget {
  final BudgetProgress progress;
  final String? categoryName;
  final VoidCallback onTap;

  const BudgetCard({
    super.key,
    required this.progress,
    this.categoryName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color progressColor = Colors.green;
    if (progress.isOverBudget) {
      progressColor = Colors.red;
    } else if (progress.isCritical) {
      progressColor = Colors.redAccent.shade100;
    } else if (progress.isWarning) {
      progressColor = Colors.orange;
    }

    final title = progress.budget.name?.isNotEmpty == true
        ? progress.budget.name!
        : (progress.budget.scopeType == 'all'
            ? 'Global Budget'
            : (categoryName ?? 'Category Budget'));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      progress.budget.periodType.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Spent / Limit ────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.budget.currency} ${progress.spentAmount.toStringAsFixed(2)} spent',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    '${progress.budget.currency} ${progress.limitAmount.toStringAsFixed(2)} limit',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Progress bar ─────────────────────────────────────────
              LinearProgressIndicator(
                value: progress.percentageUsed.clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),

              const SizedBox(height: 8),

              // ── Remaining / % ────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    progress.isOverBudget
                        ? 'Over by ${progress.budget.currency} ${(progress.spentAmount - progress.limitAmount).toStringAsFixed(2)}'
                        : '${progress.budget.currency} ${progress.remainingAmount.toStringAsFixed(2)} remaining',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: progress.isOverBudget
                          ? theme.colorScheme.error
                          : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${(progress.percentageUsed * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
