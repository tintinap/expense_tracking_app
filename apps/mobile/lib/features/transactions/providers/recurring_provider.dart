import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/database/database.dart';
import '../services/recurring_service.dart';

final recurringServiceProvider = Provider<RecurringService>((ref) {
  final dao = ref.watch(transactionDaoProvider);
  return RecurringService(dao);
});

final recurringEvaluationProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(recurringServiceProvider);
  await service.evaluateRecurringExpenses();
});

final recurringTemplatesProvider = FutureProvider<List<TransactionData>>((ref) async {
  final dao = ref.watch(transactionDaoProvider);
  return dao.getRecurringTransactions();
});

class RecurringTemplateActions {
  RecurringTemplateActions(this._ref);
  final Ref _ref;

  Future<void> pauseTemplate(TransactionData template) async {
    final dao = _ref.read(transactionDaoProvider);
    await dao.updateTransaction(
      TransactionsCompanion(
        id: Value(template.id),
        transactionType: Value(template.transactionType),
        amountBase: Value(template.amountBase),
        originalAmount: Value(template.originalAmount),
        originalCurrency: Value(template.originalCurrency),
        exchangeRate: Value(template.exchangeRate),
        rateDate: Value(template.rateDate),
        rateEstimated: Value(template.rateEstimated),
        rateSource: Value(template.rateSource),
        exchangeEventId: Value(template.exchangeEventId),
        categoryId: Value(template.categoryId),
        note: Value(template.note),
        sourceLabel: Value(template.sourceLabel),
        transactionDate: Value(template.transactionDate),
        isRecurring: const Value(true),
        recurrenceType: const Value(null),
        syncStatus: const Value('pending'),
        deletedAt: Value(template.deletedAt),
        createdAt: Value(template.createdAt),
        updatedAt: Value(DateTime.now()),
        isAggregate: Value(template.isAggregate),
      ),
    );
    _ref.invalidate(recurringTemplatesProvider);
  }

  Future<void> deleteTemplate(String id) async {
    final dao = _ref.read(transactionDaoProvider);
    await dao.softDelete(id);
    _ref.invalidate(recurringTemplatesProvider);
  }
}

final recurringTemplateActionsProvider = Provider<RecurringTemplateActions>((ref) {
  return RecurringTemplateActions(ref);
});
