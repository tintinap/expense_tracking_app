import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:uuid/uuid.dart';

import 'package:drift/drift.dart' as drift;

import '../../../core/database/database.dart';


Future<void> clearAndMockData(AppDatabase db) async {
  if (!kDebugMode) {
    throw StateError('Mock data seeding is available in debug mode only.');
  }
  const uuid = Uuid();
  final random = Random();

  // Clear existing data
  await db.delete(db.transactions).go();
  await db.delete(db.budgets).go();

  // Set reference dates
  final now = DateTime.now();
  final twoMonthsAgo = DateTime(now.year, now.month - 2, 1); // e.g., March 1st

  // 1. Create Multiple Budgets
  final budgetMonthlyAll = BudgetsCompanion.insert(
    id: uuid.v4(),
    name: const drift.Value('Overall Monthly'),
    scopeType: 'all',
    currency: 'AUD',
    amountBase: 3000.0,
    periodType: 'monthly',
    isRecurring: const drift.Value(true),
    startDate: twoMonthsAgo,
  );

  final budgetWeeklyFood = BudgetsCompanion.insert(
    id: uuid.v4(),
    name: const drift.Value('Weekly Food & Coffee'),
    scopeType: 'include',
    categoryIds: const drift.Value('default-cat-0,default-cat-1'),
    currency: 'AUD',
    amountBase: 250.0,
    periodType: 'weekly',
    isRecurring: const drift.Value(true),
    startDate: twoMonthsAgo,
  );

  final budgetFortnightlyUsd = BudgetsCompanion.insert(
    id: uuid.v4(),
    name: const drift.Value('Fortnightly Travel (USD)'),
    scopeType: 'exclude',
    categoryIds: const drift.Value('default-cat-8'), // exclude subscriptions
    currency: 'USD',
    amountBase: 500.0,
    periodType: 'fortnightly',
    isRecurring: const drift.Value(true),
    startDate: twoMonthsAgo,
  );

  await db.batch((batch) {
    batch.insertAll(db.budgets, [budgetMonthlyAll, budgetWeeklyFood, budgetFortnightlyUsd]);
  });

  // 2. Generate random transactions spread across the last 2 months
  final numDays = now.difference(twoMonthsAgo).inDays;
  final transactionsToInsert = <TransactionsCompanion>[];

  const categoryCount = 11; // default-cat-0 to default-cat-10

  for (int i = 0; i < 120; i++) {
    // Random date within the last 2 months
    final randomDays = random.nextInt(numDays + 1);
    final randomDate = twoMonthsAgo.add(Duration(days: randomDays));
    
    // Randomize category
    final catIndex = random.nextInt(categoryCount);
    final categoryId = 'default-cat-$catIndex';

    // Transaction type distribution: 80% expense, 10% income, 10% exchange
    final randType = random.nextDouble();

    if (randType < 0.8) {
      // EXPENSE
      final isUsd = random.nextDouble() > 0.8;
      final currency = isUsd ? 'USD' : 'AUD';
      final exchangeRate = isUsd ? 1.5 : 1.0;
      final originalAmount = 5.0 + random.nextDouble() * 200.0;
      final amountBase = originalAmount * exchangeRate;

      transactionsToInsert.add(TransactionsCompanion.insert(
        id: uuid.v4(),
        amountBase: amountBase,
        originalAmount: originalAmount,
        originalCurrency: currency,
        exchangeRate: exchangeRate,
        rateDate: randomDate,
        transactionDate: randomDate,
        transactionType: 'expense',
        categoryId: drift.Value(categoryId),
        note: drift.Value('Mock expense #$i'),
      ));
    } else if (randType < 0.9) {
      // INCOME
      final originalAmount = 500.0 + random.nextDouble() * 2000.0;
      
      transactionsToInsert.add(TransactionsCompanion.insert(
        id: uuid.v4(),
        amountBase: originalAmount, // Assume AUD for simplicity
        originalAmount: originalAmount,
        originalCurrency: 'AUD',
        exchangeRate: 1.0,
        rateDate: randomDate,
        transactionDate: randomDate,
        transactionType: 'currency_income',
        categoryId: drift.Value(categoryId),
        note: drift.Value('Mock income #$i'),
      ));
    } else {
      // EXCHANGE (AUD to USD)
      final exchangeEventId = uuid.v4();
      final audAmount = 100.0 + random.nextDouble() * 500.0; // OUT
      const exchangeRate = 1.5; // dummy AUD/USD rate implies 1 USD = 1.5 AUD
      final usdAmount = audAmount / exchangeRate; // IN

      // OUT transaction
      transactionsToInsert.add(TransactionsCompanion.insert(
        id: uuid.v4(),
        amountBase: audAmount,
        originalAmount: audAmount,
        originalCurrency: 'AUD',
        exchangeRate: 1.0,
        rateDate: randomDate,
        transactionDate: randomDate,
        transactionType: 'currency_exchange_out',
        exchangeEventId: drift.Value(exchangeEventId),
        note: drift.Value('Mock Exchange OUT #$i'),
      ));

      // IN transaction
      transactionsToInsert.add(TransactionsCompanion.insert(
        id: uuid.v4(),
        amountBase: audAmount, // Base is AUD equivalent
        originalAmount: usdAmount,
        originalCurrency: 'USD',
        exchangeRate: exchangeRate,
        rateDate: randomDate,
        transactionDate: randomDate,
        transactionType: 'currency_exchange_in',
        exchangeEventId: drift.Value(exchangeEventId),
        note: drift.Value('Mock Exchange IN #$i'),
      ));
    }
  }

  // Insert all transactions in a batch
  await db.batch((batch) {
    batch.insertAll(db.transactions, transactionsToInsert);
  });
}
