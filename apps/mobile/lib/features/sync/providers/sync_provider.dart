import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/providers/database_providers.dart';
import '../../auth/providers/auth_provider.dart';

bool shouldApplyRemoteLww(DateTime localUpdatedAt, DateTime remoteUpdatedAt) {
  return remoteUpdatedAt.isAfter(localUpdatedAt);
}

class SyncState {
  final bool isSyncing;
  final int pendingCount;
  final String? lastError;
  final DateTime? lastSync;

  const SyncState({
    this.isSyncing = false,
    this.pendingCount = 0,
    this.lastError,
    this.lastSync,
  });

  SyncState copyWith({
    bool? isSyncing,
    int? pendingCount,
    String? lastError,
    DateTime? lastSync,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: lastError, // Nullable to clear
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  Timer? _periodicTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isProcessing = false;

  SyncNotifier(this._ref) : super(const SyncState()) {
    _init();
  }

  Future<void> _init() async {
    await _updatePendingCount();
    await _loadLastSync();
    // Start periodic sync attempting every 30 seconds
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      processQueue();
    });
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        processQueue();
      }
    });
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLastSync() async {
    final db = _ref.read(databaseProvider);
    final value = await db.getSetting('last_sync_timestamp');
    if (value == null || value.isEmpty) {
      return;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      state = state.copyWith(lastSync: parsed);
    }
  }

  Future<void> _updatePendingCount() async {
    final db = _ref.read(databaseProvider);

    // All items in the sync queue are pending; completed items are deleted.
    // Items with attempts >= 5 are considered failed.
    final allItems = await db.select(db.syncQueue).get();
    final pendingCount = allItems.where((q) => q.attempts < 5).length;

    state = state.copyWith(pendingCount: pendingCount);
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    final authState = _ref.read(authStateProvider);
    if (!authState.isAuthenticated) return;

    _isProcessing = true;
    state = state.copyWith(isSyncing: true, lastError: null);

    final db = _ref.read(databaseProvider);
    final dio = _ref.read(dioProvider);

    try {
      // 1. Get pending queue items ordered by createdAt ascending
      final pendingItems = await (db.select(db.syncQueue)
            ..where((q) => q.attempts.isSmallerThanValue(5))
            ..orderBy([(q) => drift.OrderingTerm.asc(q.createdAt)]))
          .get();

      if (pendingItems.isNotEmpty) {
        try {
          final response = await dio.post(
            '/sync/push',
            data: {
              'records': pendingItems
                  .map(
                    (item) => {
                      'recordType': item.recordType,
                      'recordId': item.recordId,
                      'operation': item.operation,
                      'payload': jsonDecode(item.payload),
                    },
                  )
                  .toList(),
              'clientTimestamp': DateTime.now().toIso8601String(),
            },
          );
          final conflicts = ((response.data['conflicts'] as List?) ?? [])
              .whereType<Map>()
              .toList();
          final conflictedIds = conflicts
              .map((c) => c['recordId'] as String?)
              .whereType<String>()
              .toSet();

          for (final item in pendingItems) {
            if (!conflictedIds.contains(item.recordId)) {
              await (db.delete(db.syncQueue)..where((q) => q.id.equals(item.id)))
                  .go();
              continue;
            }
            await (db.update(db.syncQueue)..where((q) => q.id.equals(item.id)))
                .write(SyncQueueCompanion(
              attempts: drift.Value(item.attempts + 1),
              lastError: const drift.Value('Conflict from server'),
            ));
          }
        } catch (e) {
          for (final item in pendingItems) {
            final waitSeconds = math.pow(2, item.attempts).toInt() * 5;
            await Future.delayed(Duration(seconds: waitSeconds));
            await (db.update(db.syncQueue)..where((q) => q.id.equals(item.id)))
                .write(SyncQueueCompanion(
              attempts: drift.Value(item.attempts + 1),
              lastError: drift.Value(e.toString()),
            ));
          }
          rethrow;
        }
      }

      // 2. PRD §15 - Pull remote changes
      final lastSyncIso = state.lastSync?.toIso8601String() ??
          DateTime.fromMillisecondsSinceEpoch(0).toIso8601String();
      final pullResponse = await dio.post(
        '/sync/pull',
        data: {'lastSyncTimestamp': lastSyncIso},
      );
      final serverTimestamp = DateTime.tryParse(
            (pullResponse.data['serverTimestamp'] as String?) ??
                DateTime.now().toIso8601String(),
          ) ??
          DateTime.now();
      await _applyPullChanges(
        transactions: (pullResponse.data['transactions'] as List?) ?? const [],
        categories: (pullResponse.data['categories'] as List?) ?? const [],
        budgets: (pullResponse.data['budgets'] as List?) ?? const [],
      );
      await db.setSetting('last_sync_timestamp', serverTimestamp.toIso8601String());
      state = state.copyWith(isSyncing: false, lastSync: serverTimestamp);
    } catch (e) {
      state = state.copyWith(isSyncing: false, lastError: e.toString());
    } finally {
      await _updatePendingCount();
      _isProcessing = false;
    }
  }

  Future<void> _applyPullChanges({
    required List transactions,
    required List categories,
    required List budgets,
  }) async {
    final db = _ref.read(databaseProvider);
    await db.transaction(() async {
      for (final record in categories.whereType<Map>()) {
        await _upsertCategory(db, record);
      }
      for (final record in budgets.whereType<Map>()) {
        await _upsertBudget(db, record);
      }
      for (final record in transactions.whereType<Map>()) {
        await _upsertTransaction(db, record);
      }
    });
  }

  bool _isRemoteNewer(DateTime localUpdatedAt, DateTime remoteUpdatedAt) {
    return shouldApplyRemoteLww(localUpdatedAt, remoteUpdatedAt);
  }

  Future<void> _upsertCategory(AppDatabase db, Map record) async {
    final id = record['id'] as String?;
    final updatedAt = DateTime.tryParse(record['updatedAt']?.toString() ?? '');
    if (id == null || updatedAt == null) {
      return;
    }
    final local = await (db.select(db.categories)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (local != null && !_isRemoteNewer(local.updatedAt, updatedAt)) {
      return;
    }
    await db.into(db.categories).insertOnConflictUpdate(CategoryData(
          id: id,
          name: (record['name'] as String?) ?? local?.name ?? '',
          colourHex: (record['colourHex'] as String?) ?? local?.colourHex ?? '#9E9E9E',
          iconCodePoint:
              (record['iconCodePoint'] as int?) ?? local?.iconCodePoint ?? 0xe148,
          isDefault: (record['isDefault'] as bool?) ?? local?.isDefault ?? false,
          isHidden: (record['isHidden'] as bool?) ?? local?.isHidden ?? false,
          sortOrder: (record['sortOrder'] as int?) ?? local?.sortOrder ?? 0,
          parentId: record['parentId'] as String? ?? local?.parentId,
          syncStatus: 'synced',
          createdAt: DateTime.tryParse(record['createdAt']?.toString() ?? '') ??
              local?.createdAt ??
              updatedAt,
          updatedAt: updatedAt,
        ));
  }

  Future<void> _upsertBudget(AppDatabase db, Map record) async {
    final id = record['id'] as String?;
    final updatedAt = DateTime.tryParse(record['updatedAt']?.toString() ?? '');
    if (id == null || updatedAt == null) {
      return;
    }
    final local = await (db.select(db.budgets)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (local != null && !_isRemoteNewer(local.updatedAt, updatedAt)) {
      return;
    }
    await db.into(db.budgets).insertOnConflictUpdate(BudgetData(
          id: id,
          name: record['name'] as String? ?? local?.name,
          scopeType: (record['scopeType'] as String?) ?? local?.scopeType ?? 'all',
          categoryIds: record['categoryIds'] as String? ?? local?.categoryIds,
          currency: (record['currency'] as String?) ?? local?.currency ?? 'AUD',
          amountBase: (record['amountBase'] as num?)?.toDouble() ??
              local?.amountBase ??
              0,
          periodType:
              (record['periodType'] as String?) ?? local?.periodType ?? 'monthly',
          isRecurring:
              (record['isRecurring'] as bool?) ?? local?.isRecurring ?? true,
          startDate: DateTime.tryParse(record['startDate']?.toString() ?? '') ??
              local?.startDate ??
              updatedAt,
          endDate: DateTime.tryParse(record['endDate']?.toString() ?? '') ??
              local?.endDate,
          isActive: (record['isActive'] as bool?) ?? local?.isActive ?? true,
          notified75: (record['notified75'] as bool?) ?? local?.notified75 ?? false,
          notified90: (record['notified90'] as bool?) ?? local?.notified90 ?? false,
          notified100:
              (record['notified100'] as bool?) ?? local?.notified100 ?? false,
          syncStatus: 'synced',
          createdAt: DateTime.tryParse(record['createdAt']?.toString() ?? '') ??
              local?.createdAt ??
              updatedAt,
          updatedAt: updatedAt,
        ));
  }

  Future<void> _upsertTransaction(AppDatabase db, Map record) async {
    final id = record['id'] as String?;
    final updatedAt = DateTime.tryParse(record['updatedAt']?.toString() ?? '');
    if (id == null || updatedAt == null) {
      return;
    }
    final local = await (db.select(db.transactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (local != null && !_isRemoteNewer(local.updatedAt, updatedAt)) {
      return;
    }
    await db.into(db.transactions).insertOnConflictUpdate(TransactionData(
          id: id,
          transactionType:
              (record['transactionType'] as String?) ?? local?.transactionType ?? 'expense',
          amountBase:
              (record['amountBase'] as num?)?.toDouble() ?? local?.amountBase ?? 0,
          originalAmount: (record['originalAmount'] as num?)?.toDouble() ??
              local?.originalAmount ??
              0,
          originalCurrency:
              (record['originalCurrency'] as String?) ?? local?.originalCurrency ?? 'AUD',
          exchangeRate:
              (record['exchangeRate'] as num?)?.toDouble() ?? local?.exchangeRate ?? 1,
          rateDate: DateTime.tryParse(record['rateDate']?.toString() ?? '') ??
              local?.rateDate ??
              updatedAt,
          rateEstimated:
              (record['rateEstimated'] as bool?) ?? local?.rateEstimated ?? false,
          rateSource: (record['rateSource'] as String?) ??
              local?.rateSource ??
              'frankfurter',
          exchangeEventId:
              record['exchangeEventId'] as String? ?? local?.exchangeEventId,
          categoryId: record['categoryId'] as String? ?? local?.categoryId,
          note: record['note'] as String? ?? local?.note,
          sourceLabel: record['sourceLabel'] as String? ?? local?.sourceLabel,
          transactionDate:
              DateTime.tryParse(record['transactionDate']?.toString() ?? '') ??
                  local?.transactionDate ??
                  updatedAt,
          isRecurring:
              (record['isRecurring'] as bool?) ?? local?.isRecurring ?? false,
          recurrenceType:
              record['recurrenceType'] as String? ?? local?.recurrenceType,
          syncStatus: 'synced',
          deletedAt:
              DateTime.tryParse(record['deletedAt']?.toString() ?? '') ?? local?.deletedAt,
          createdAt: DateTime.tryParse(record['createdAt']?.toString() ?? '') ??
              local?.createdAt ??
              updatedAt,
          updatedAt: updatedAt,
          isAggregate:
              (record['isAggregate'] as bool?) ?? local?.isAggregate ?? false,
        ));
  }

  Future<void> pushAllLocalRecords() async {
    final db = _ref.read(databaseProvider);
    
    // Add all existing categories
    final categories = await db.select(db.categories).get();
    for (final c in categories) {
      await db.into(db.syncQueue).insert(SyncQueueCompanion(
        recordType: const drift.Value('category'),
        recordId: drift.Value(c.id),
        operation: const drift.Value('insert'),
        payload: drift.Value(jsonEncode({
          'name': c.name,
          'colourHex': c.colourHex,
          'iconCodePoint': c.iconCodePoint,
          'isDefault': c.isDefault,
          'isHidden': c.isHidden,
          'sortOrder': c.sortOrder,
          'parentId': c.parentId,
        })),
      ));
    }

    // Add all existing budgets
    final budgets = await db.select(db.budgets).get();
    for (final b in budgets) {
      await db.into(db.syncQueue).insert(SyncQueueCompanion(
        recordType: const drift.Value('budget'),
        recordId: drift.Value(b.id),
        operation: const drift.Value('insert'),
        payload: drift.Value(jsonEncode({
          'name': b.name,
          'scopeType': b.scopeType,
          'categoryIds': b.categoryIds,
          'currency': b.currency,
          'amountBase': b.amountBase,
          'periodType': b.periodType,
          'isRecurring': b.isRecurring,
          'startDate': b.startDate.toIso8601String(),
          'endDate': b.endDate?.toIso8601String(),
          'isActive': b.isActive,
        })),
      ));
    }

    // Add all existing transactions
    final transactions = await db.select(db.transactions).get();
    for (final t in transactions) {
      await db.into(db.syncQueue).insert(SyncQueueCompanion(
        recordType: const drift.Value('transaction'),
        recordId: drift.Value(t.id),
        operation: const drift.Value('insert'),
        payload: drift.Value(jsonEncode({
          'transactionType': t.transactionType,
          'amountBase': t.amountBase,
          'originalAmount': t.originalAmount,
          'originalCurrency': t.originalCurrency,
          'exchangeRate': t.exchangeRate,
          'rateDate': t.rateDate.toIso8601String(),
          'rateEstimated': t.rateEstimated,
          'rateSource': t.rateSource,
          'exchangeEventId': t.exchangeEventId,
          'categoryId': t.categoryId,
          'note': t.note,
          'sourceLabel': t.sourceLabel,
          'transactionDate': t.transactionDate.toIso8601String(),
          'isRecurring': t.isRecurring,
          'recurrenceType': t.recurrenceType,
        })),
      ));
    }

    await processQueue();
  }
}
