import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/database_providers.dart';
import '../providers/budget_providers.dart';
import '../widgets/budget_bottom_sheet.dart';

class BudgetDetailScreen extends ConsumerWidget {
  final String id;

  const BudgetDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressList = ref.watch(budgetProgressListProvider).valueOrNull ?? [];
    final progress = progressList.where((p) => p.budget.id == id).firstOrNull;
    final theme = Theme.of(context);

    if (progress == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Budget Detail')),
        body: const Center(child: Text('Budget not found')),
      );
    }

    final b = progress.budget;
    final title = (b.name?.isNotEmpty == true)
        ? b.name!
        : (b.scopeType == 'all'
            ? 'Global Budget'
            : '${b.scopeType.capitalize()} Budget');

    Color progressColor = Colors.green;
    if (progress.isOverBudget) {
      progressColor = Colors.red;
    } else if (progress.isCritical) {
      progressColor = Colors.redAccent.shade100;
    } else if (progress.isWarning) {
      progressColor = Colors.amber;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (context) => BudgetBottomSheet(initialBudget: b),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            tooltip: 'Delete budget',
            onPressed: () => _confirmDelete(context, ref, b.id, title),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        '${(progress.percentageUsed * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.displayMedium?.copyWith(
                          color: progressColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('of ${progress.currency} ${progress.limitAmount.toStringAsFixed(2)} used', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 24),
                      LinearProgressIndicator(
                        value: progress.percentageUsed.clamp(0.0, 1.0),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Spent', style: theme.textTheme.bodySmall),
                              Text('${progress.currency} ${progress.spentAmount.toStringAsFixed(2)}', style: theme.textTheme.titleMedium),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Remaining', style: theme.textTheme.bodySmall),
                              Text(
                                '${progress.currency} ${progress.remainingAmount.toStringAsFixed(2)}', 
                                style: theme.textTheme.titleMedium
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  const Text('Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ListTile(
                    title: const Text('Period Mode'),
                    trailing: Text(b.periodType.capitalize()),
                  ),
                  ListTile(
                    title: const Text('Recurring'),
                    trailing: Text(b.isRecurring ? 'Yes' : 'No'),
                  ),
                  ListTile(
                    title: const Text('Scope'),
                    trailing: Text(b.scopeType.capitalize()),
                  ),
                  if (progress.categoryNames.isNotEmpty)
                    ListTile(
                      title: const Text('Categories'),
                      subtitle: Text(progress.categoryNames.join(', ')),
                    ),
                  ListTile(
                    title: const Text('Current Period'),
                    subtitle: Text('${DateFormat.yMMMd().format(progress.currentPeriod.from)} - ${DateFormat.yMMMd().format(progress.currentPeriod.to)}'),
                    trailing: progress.isExpired ? const Chip(label: Text('Expired')) : const Chip(label: Text('Active')),
                  ),
                  const SizedBox(height: 24),
                  if (b.isRecurring)
                    const Text('History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          
          if (b.isRecurring)
            _buildHistorySection(ref, id),
            
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
  
  void _confirmDelete(
      BuildContext context, WidgetRef ref, String budgetId, String title) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(budgetDaoProvider).deleteBudget(budgetId);
              if (context.mounted) context.go('/budgets');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(WidgetRef ref, String budgetId) {
    final historyAsync = ref.watch(budgetHistoryProvider(budgetId));

    return historyAsync.when(
      loading: () => const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          )),
      error: (err, stack) =>
          SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
      data: (history) {
        if (history.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('No past periods yet.'),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final h = history[index];
                final theme = Theme.of(context);
                final pct = h.percentageUsed;
                final isOver = pct > 1.0;

                Color barColor = Colors.green;
                if (pct > 1.0) {
                  barColor = Colors.red;
                } else if (pct >= 0.90) {
                  barColor = Colors.redAccent.shade100;
                } else if (pct >= 0.75) {
                  barColor = Colors.amber;
                }

                final remaining = (h.limitAmount - h.spentAmount)
                    .clamp(0, double.infinity);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Date range
                          Text(
                            '${DateFormat.yMMMd().format(h.period.from)}  –  ${DateFormat.yMMMd().format(h.period.to)}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Spent / limit row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Spent  ${h.spentAmount.toStringAsFixed(2)}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                'Limit  ${h.limitAmount.toStringAsFixed(2)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Progress bar
                          LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(barColor),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 6),
                          // Remaining / percentage
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isOver
                                    ? 'Over by ${(h.spentAmount - h.limitAmount).toStringAsFixed(2)}'
                                    : '${remaining.toStringAsFixed(2)} remaining',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isOver
                                      ? theme.colorScheme.error
                                      : Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${(pct * 100).toStringAsFixed(1)}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: barColor,
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
              },
              childCount: history.length,
            ),
          ),
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
