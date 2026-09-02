import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../../core/presentation/category_visuals.dart';
import '../../../core/providers/database_providers.dart';
import '../../shared/providers/shared_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

class TransactionDetailSheet extends ConsumerWidget {
  final TransactionData transaction;
  final TransactionData? pairedTransaction;
  final CategoryData? category;
  final CategoryData? parent;
  final String? exchangeRateLabel;

  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    this.pairedTransaction,
    this.category,
    this.parent,
    this.exchangeRateLabel,
  });

  bool get _isExchange =>
      transaction.transactionType == 'currency_exchange_out' ||
      transaction.transactionType == 'currency_exchange_in';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isIncome = transaction.transactionType == 'currency_income';
    final prefix = isIncome ? '+' : '-';
    final amountColor = isIncome ? Colors.green : theme.textTheme.bodyLarge?.color;

    final headerCategory = parent ?? category;
    final isSub = parent != null && category != null;
    final note = transaction.note?.trim();

    final baseCurrency = ref.watch(baseCurrencyProvider);
    final viewCurrency = ref.watch(viewCurrencyProvider);
    final viewRate = ref.watch(viewCurrencyRateProvider).valueOrNull ?? 1.0;
    // For 3rd-currency transactions (e.g. VND when base=AUD, view=THB),
    // prefer a direct originalCurrency→viewCurrency rate that was cached at
    // save time. Fall back to amountBase×viewRate only when no direct rate
    // exists (covers the case where the transaction was saved before this fix).
    final txOriginalCurrency = transaction.originalCurrency;
    final dateKey =
        '${transaction.transactionDate.year.toString().padLeft(4, '0')}-'
        '${transaction.transactionDate.month.toString().padLeft(2, '0')}-'
        '${transaction.transactionDate.day.toString().padLeft(2, '0')}';
    final directViewAsync = ref.watch(txViewAmountProvider((
      fromCurrency: txOriginalCurrency,
      toCurrency: viewCurrency,
      dateKey: dateKey,
      originalAmount: transaction.originalAmount.abs(),
    )));

    final showViewCurrencyEstimation = viewCurrency != baseCurrency &&
        viewCurrency != txOriginalCurrency;
    Widget? amountSecondaryWidget;
    if (showViewCurrencyEstimation) {
      // Use direct rate if cached (VND→THB), otherwise fall back via base.
      final directViewAmount = directViewAsync.valueOrNull;
      final estimatedAmount = directViewAmount ??
          (transaction.amountBase * viewRate).abs();
      final bool isDirect = directViewAmount != null;

      // Build a human-readable rate hint.
      String rateHint;
      if (isDirect && txOriginalCurrency != baseCurrency) {
        // Show the actual direct pair rate for clarity.
        final directRate = transaction.originalAmount.abs() > 0
            ? estimatedAmount / transaction.originalAmount.abs()
            : viewRate;
        final rateStr = directRate.toStringAsFixed(4)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
        rateHint = '1 $txOriginalCurrency = $rateStr $viewCurrency';
      } else {
        final rateStr = viewRate.toStringAsFixed(4)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
        rateHint = '1 $baseCurrency = $rateStr $viewCurrency';
      }

      amountSecondaryWidget = Text(
        '≈ $prefix $viewCurrency ${estimatedAmount.toStringAsFixed(2)} ($rateHint)',
        style: theme.textTheme.bodySmall?.copyWith(
          color: amountColor?.withValues(alpha: 0.7) ?? theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
        ),
        textAlign: TextAlign.right,
      );
    }

    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                if (headerCategory != null)
                  categoryGlyphAvatar(
                    colour: parseHexColour(headerCategory.colourHex),
                    iconCodePoint: headerCategory.iconCodePoint,
                    radius: 20,
                  )
                else
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _isExchange
                        ? theme.colorScheme.tertiaryContainer
                        : (isIncome
                            ? Colors.green.withValues(alpha: 0.2)
                            : theme.colorScheme.primaryContainer),
                    child: Icon(
                      _isExchange
                          ? Icons.currency_exchange
                          : (isIncome ? Icons.arrow_downward : Icons.receipt_long),
                      color: _isExchange
                          ? theme.colorScheme.onTertiaryContainer
                          : (isIncome ? Colors.green : theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerCategory?.name ??
                            (note != null && note.isNotEmpty
                                ? note
                                : _typeFallbackLabel(transaction.transactionType)),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isSub)
                        Row(
                          children: [
                            Icon(Icons.subdirectory_arrow_right, size: 14, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              category!.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Sync status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: transaction.syncStatus == 'synced'
                        ? Colors.green.withValues(alpha: 0.1)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        transaction.syncStatus == 'synced' ? Icons.cloud_done : Icons.cloud_sync,
                        size: 14,
                        color: transaction.syncStatus == 'synced'
                            ? Colors.green
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        transaction.syncStatus == 'synced' ? 'Synced' : 'Pending',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: transaction.syncStatus == 'synced'
                              ? Colors.green
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  theme,
                  Icons.calendar_today,
                  'Date',
                  DateFormat.yMMMMEEEEd().add_jm().format(transaction.transactionDate),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  theme,
                  Icons.payments_outlined,
                  'Amount',
                  '$prefix ${transaction.originalCurrency} ${transaction.originalAmount.toStringAsFixed(2)}',
                  valueColor: amountColor,
                  isBold: true,
                  secondaryWidget: amountSecondaryWidget,
                ),
                
                if (_isExchange && pairedTransaction != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    theme,
                    Icons.currency_exchange,
                    'Exchange Amount',
                    '+ ${pairedTransaction!.originalCurrency} ${pairedTransaction!.originalAmount.toStringAsFixed(2)}',
                    valueColor: Colors.green,
                    isBold: true,
                  ),
                ],

                if (exchangeRateLabel != null) ...[
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    theme,
                    Icons.timeline,
                    'Exchange Rate',
                    exchangeRateLabel!,
                  ),
                ],

                if (transaction.rateEstimated) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Estimated rate (${transaction.rateSource})',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Note',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      note,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (transaction.isRecurring) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final dao = ref.read(transactionDaoProvider);
                    final db = ref.read(databaseProvider);
                    // Update isRecurring to false
                    await dao.updateTransaction(
                      TransactionsCompanion(
                        id: drift.Value(transaction.id),
                        isRecurring: const drift.Value(false),
                        recurrenceType: const drift.Value(null),
                        syncStatus: const drift.Value('pending'),
                        updatedAt: drift.Value(DateTime.now()),
                      ),
                    );
                    await db.addToSyncQueue(
                      id: const Uuid().v4(),
                      recordType: 'transaction',
                      recordId: transaction.id,
                      operation: 'update',
                      payload: '{}',
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recurring expense cancelled')),
                      );
                    }
                  },
                  icon: const Icon(Icons.cancel_schedule_send),
                  label: const Text('Cancel Recurring'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme, 
    IconData icon, 
    String label, 
    String value, {
    Color? valueColor, 
    bool isBold = false,
    Widget? secondaryWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.right,
              ),
              if (secondaryWidget != null) ...[
                const SizedBox(height: 2),
                secondaryWidget,
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _typeFallbackLabel(String transactionType) {
    switch (transactionType) {
      case 'expense':
        return 'Expense';
      case 'currency_income':
        return 'Income';
      case 'currency_exchange_out':
        return 'Exchange out';
      case 'currency_exchange_in':
        return 'Exchange in';
      default:
        return transactionType;
    }
  }
}
