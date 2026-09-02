import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:convert';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../../shared/providers/shared_providers.dart';
import '../../shared/widgets/transaction_list_tile.dart';

final currencyTransactionsProvider = StreamProvider.family<List<TransactionData>, String>((ref, currency) {
  final dao = ref.watch(transactionDaoProvider);
  return dao.watchByCurrency(currency);
});

class CurrencyDetailScreen extends ConsumerWidget {
  final String currency;

  const CurrencyDetailScreen({super.key, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactionsAsync = ref.watch(currencyTransactionsProvider(currency));

    return Scaffold(
      appBar: AppBar(
        title: Text('$currency Wallet'),
        actions: [
          IconButton(
            tooltip: 'Manual balance adjustment',
            icon: const Icon(Icons.tune),
            onPressed: () => _showAdjustmentDialog(context, ref),
          ),
        ],
      ),
      body: SlidableAutoCloseBehavior(
        child: CustomScrollView(
        slivers: [
          // Balance Header
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) {
                final balances = ref.watch(currencyBalancesProvider).valueOrNull ?? [];
                final balanceData = balances.where((b) => b.currency == currency).firstOrNull;
                final balance = balanceData?.balance ?? 0.0;
                
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Current Balance', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            '$currency ${balance.toStringAsFixed(2)}',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: balance < 0 ? theme.colorScheme.error : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // List Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Transaction History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Transaction List
          transactionsAsync.when(
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (err, _) => SliverFillRemaining(child: Center(child: Text('Error: $err'))),
            data: (transactions) {
              if (transactions.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No transactions found for this currency.')),
                );
              }

              // Sort transactions by date descending
              final sortedTransactions = List.of(transactions)
                ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

              // Group transactions by date
              final listItems = [];
              String? lastDateStr;
              
              for (final tx in sortedTransactions) {
                final dateStr = DateFormat.yMMMd().format(tx.transactionDate);
                if (dateStr != lastDateStr) {
                  listItems.add(dateStr); // Add date header
                  lastDateStr = dateStr;
                }
                listItems.add(tx);
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = listItems[index];
                    
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              item,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Divider(
                                color: theme.colorScheme.primary.withOpacity(0.2),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    final tx = item as TransactionData;
                    return TransactionListTile(transaction: tx);
                  },
                  childCount: listItems.length,
                ),
              );
            },
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _showAdjustmentDialog(BuildContext context, WidgetRef ref) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: 'balance_adjustment');
    final isIncome = ValueNotifier<bool>(true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual balance adjustment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: isIncome,
              builder: (_, value, __) => SwitchListTile(
                value: value,
                onChanged: (v) => isIncome.value = v,
                title: Text(value ? 'Increase balance' : 'Decrease balance'),
              ),
            ),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Amount ($currency)'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );

    if (confirmed != true) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final txId = const Uuid().v4();
    final txType = isIncome.value ? 'currency_income' : 'expense';

    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: txId,
        transactionType: txType,
        amountBase: amount,
        originalAmount: amount,
        originalCurrency: currency,
        exchangeRate: 1.0,
        rateDate: now,
        transactionDate: now,
        note: drift.Value(noteCtrl.text.trim().isEmpty ? 'balance_adjustment' : noteCtrl.text.trim()),
      ),
    );

    await db.addToSyncQueue(
      id: const Uuid().v4(),
      recordType: 'transaction',
      recordId: txId,
      operation: 'insert',
      payload: jsonEncode({
        'transactionType': txType,
        'amountBase': amount,
        'originalAmount': amount,
        'originalCurrency': currency,
        'exchangeRate': 1.0,
        'rateDate': now.toIso8601String(),
        'rateEstimated': false,
        'rateSource': 'manual',
        'exchangeEventId': null,
        'categoryId': null,
        'note': noteCtrl.text.trim().isEmpty ? 'balance_adjustment' : noteCtrl.text.trim(),
        'sourceLabel': 'manual_adjustment',
        'transactionDate': now.toIso8601String(),
        'isRecurring': false,
        'recurrenceType': null,
        'updatedAt': now.toIso8601String(),
      }),
    );
  }
}
