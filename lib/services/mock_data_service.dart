import 'dart:math';

import 'package:uuid/uuid.dart';

import '../data/models/category.dart';
import '../data/models/expense.dart';
import '../providers/expense_provider.dart';

/// Generates a full year of realistic mock expense/income data.
class MockDataService {
  static const _uuid = Uuid();
  static final _rng = Random(42); // seeded for reproducibility

  /// Generates mock data from Jan 1 of [year] up to today in AUD.
  /// Populates the provider directly. Returns the number of entries added.
  static Future<int> generateYearOfData(ExpenseProvider provider,
      {int? year}) async {
    final now = DateTime.now();
    year ??= now.year;
    await provider.clearAll();

    final expenses = <Expense>[];
    int count = 0;

    final maxMonth = year == now.year ? now.month : 12;

    for (var month = 1; month <= maxMonth; month++) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      // Don't generate future days for the current month
      final maxDay =
          (year == now.year && month == now.month) ? now.day : daysInMonth;

      // ── Recurring monthly expenses ──
      // Rent: 1st of every month
      _add(expenses,
          amount: 760,
          date: DateTime(year, month, 1),
          category: Category.rent,
          note: 'Rent',
          currency: 'AUD');
      count++;

      // Gym: 1st of every month
      _add(expenses,
          amount: 40 + _rng.nextDouble() * 10,
          date: DateTime(year, month, 1),
          category: Category.health,
          note: 'Gym membership',
          currency: 'AUD');
      count++;

      // Phone bill: 15th of every month
      if (maxDay >= 15) {
        _add(expenses,
            amount: 30 + _rng.nextDouble() * 15,
            date: DateTime(year, month, 15),
            category: Category.bills,
            note: 'Phone bill',
            currency: 'AUD');
        count++;
      }

      // Internet: 20th of every month
      if (maxDay >= 20) {
        _add(expenses,
            amount: 55 + _rng.nextDouble() * 10,
            date: DateTime(year, month, 20),
            category: Category.bills,
            note: 'Internet',
            currency: 'AUD');
        count++;
      }

      // ── Income (fortnightly) ──
      // Part-time pay: 7th and 21st
      for (final payDay in [7, 21]) {
        if (payDay <= maxDay) {
          _add(expenses,
              amount: 450 + _rng.nextDouble() * 200,
              date: DateTime(year, month, payDay),
              category: Category.income,
              note: 'Part-time pay',
              currency: 'AUD',
              isIncome: true);
          count++;
        }
      }

      // Money from parents (every 2nd month)
      if (month % 2 == 0) {
        _add(expenses,
            amount: 200 + _rng.nextDouble() * 100,
            date: DateTime(year, month, 5),
            category: Category.income,
            note: 'Money from parents',
            currency: 'AUD',
            isIncome: true);
        count++;
      }

      // Uber Eats earnings (3-5 times a month)
      final uberDays = _rng.nextInt(3) + 3;
      for (var i = 0; i < uberDays; i++) {
        final day = _rng.nextInt(maxDay) + 1;
        _add(expenses,
            amount: 35 + _rng.nextDouble() * 45,
            date: DateTime(year, month, day),
            category: Category.income,
            note: 'Uber Eats earning',
            currency: 'AUD',
            isIncome: true);
        count++;
      }

      // ── Daily food expenses ──
      for (var day = 1; day <= maxDay; day++) {
        // Breakfast/lunch/dinner – 1-3 food purchases per day
        final meals = _rng.nextInt(3) + 1;
        for (var m = 0; m < meals; m++) {
          final foodItems = [
            'Coffee',
            'Lunch',
            'Dinner',
            'Groceries',
            'Snacks',
            'Bubble tea',
            'Bakery',
            'Pad Thai',
            'Sushi',
            'Kebab',
            'Supermarket',
            'Fruit shop',
            'Noodles',
            'Burger',
          ];
          _add(expenses,
              amount: 5 + _rng.nextDouble() * 25,
              date: DateTime(year, month, day),
              category: Category.food,
              note: foodItems[_rng.nextInt(foodItems.length)],
              currency: 'AUD');
          count++;
        }
      }

      // ── Transport ──
      // 8-15 transport expenses per month
      final transportCount = _rng.nextInt(8) + 8;
      for (var i = 0; i < transportCount; i++) {
        final day = _rng.nextInt(maxDay) + 1;
        final transportItems = [
          'Bus',
          'Train',
          'Opal card top-up',
          'Uber ride',
          'E-bike charge',
          'Petrol',
          'Parking',
        ];
        _add(expenses,
            amount: 3 + _rng.nextDouble() * 20,
            date: DateTime(year, month, day),
            category: Category.transport,
            note: transportItems[_rng.nextInt(transportItems.length)],
            currency: 'AUD');
        count++;
      }

      // ── Entertainment (2-5 per month) ──
      final entertainmentCount = _rng.nextInt(4) + 2;
      for (var i = 0; i < entertainmentCount; i++) {
        final day = _rng.nextInt(maxDay) + 1;
        final items = [
          'Movie tickets',
          'Netflix',
          'Spotify',
          'Concert',
          'Escape room',
          'Zoo',
          'Bowling',
          'Karaoke',
          'Board game cafe',
          'Museum',
          'Art gallery',
        ];
        _add(expenses,
            amount: 10 + _rng.nextDouble() * 50,
            date: DateTime(year, month, day),
            category: Category.entertainment,
            note: items[_rng.nextInt(items.length)],
            currency: 'AUD');
        count++;
      }

      // ── Shopping (1-4 per month) ──
      final shoppingCount = _rng.nextInt(4) + 1;
      for (var i = 0; i < shoppingCount; i++) {
        final day = _rng.nextInt(maxDay) + 1;
        final items = [
          'Uniqlo',
          'Amazon',
          'Daiso',
          'IKEA',
          'Kmart',
          'Cotton On',
          'JB Hi-Fi',
          'Books',
          'Shoes',
        ];
        _add(expenses,
            amount: 15 + _rng.nextDouble() * 85,
            date: DateTime(year, month, day),
            category: Category.shopping,
            note: items[_rng.nextInt(items.length)],
            currency: 'AUD');
        count++;
      }

      // ── Health (0-2 per month, besides gym) ──
      final healthCount = _rng.nextInt(3);
      for (var i = 0; i < healthCount; i++) {
        final day = _rng.nextInt(maxDay) + 1;
        final items = [
          'Pharmacy',
          'Doctor visit',
          'Vitamins',
          'Dental',
          'Physiotherapy',
          'Eye check',
        ];
        _add(expenses,
            amount: 20 + _rng.nextDouble() * 80,
            date: DateTime(year, month, day),
            category: Category.health,
            note: items[_rng.nextInt(items.length)],
            currency: 'AUD');
        count++;
      }

      // ── Miscellaneous (1-3 per month) ──
      final miscCount = _rng.nextInt(3) + 1;
      for (var i = 0; i < miscCount; i++) {
        final day = _rng.nextInt(maxDay) + 1;
        final items = [
          'Laundry',
          'Haircut',
          'Printing',
          'Gift',
          'Donation',
          'Stationery',
          'Postage',
          'App subscription',
        ];
        _add(expenses,
            amount: 5 + _rng.nextDouble() * 40,
            date: DateTime(year, month, day),
            category: Category.other,
            note: items[_rng.nextInt(items.length)],
            currency: 'AUD');
        count++;
      }

      // ── Occasional THB expenses (trips to Thailand, 2 months) ──
      if (month == 4 || month == 12) {
        // Thailand trip – ~10 days of expenses
        for (var day = 10; day <= 20 && day <= maxDay; day++) {
          final thbItems = [
            'Street food',
            'Taxi',
            'Temple entry',
            '7-Eleven',
            'Massage',
            'Market shopping',
            'Night market',
            'MRT ticket',
            'Pad Kra Pao',
            'Thai tea',
          ];
          _add(expenses,
              amount: 100 + _rng.nextDouble() * 500,
              date: DateTime(year, month, day),
              category: Category.food,
              note: '🇹🇭 ${thbItems[_rng.nextInt(thbItems.length)]}',
              currency: 'THB');
          count++;
        }
      }
    }

    // ── One-off large expenses ──
    _addIfPast(expenses, now,
        amount: 1520,
        date: DateTime(year, 1, 5),
        category: Category.rent,
        note: 'Rent Bond + reserving',
        currency: 'AUD');

    _addIfPast(expenses, now,
        amount: 350,
        date: DateTime(year, 2, 10),
        category: Category.transport,
        note: 'E-bike purchase',
        currency: 'AUD');

    _addIfPast(expenses, now,
        amount: 65,
        date: DateTime(year, 3, 1),
        category: Category.bills,
        note: 'Criminal checks for Uber registration',
        currency: 'AUD');

    _addIfPast(expenses, now,
        amount: 320,
        date: DateTime(year, 7, 15),
        category: Category.bills,
        note: 'SSAF Fee',
        currency: 'AUD');

    _addIfPast(expenses, now,
        amount: 200,
        date: DateTime(year, 7, 1),
        category: Category.rent,
        note: 'Yura mudang Bond',
        currency: 'AUD');

    await provider.addExpenses(expenses);
    return count;
  }

  static void _add(
    List<Expense> expenses, {
    required double amount,
    required DateTime date,
    required Category category,
    required String note,
    required String currency,
    bool isIncome = false,
  }) {
    expenses.add(Expense(
      id: _uuid.v4(),
      amount: double.parse(amount.toStringAsFixed(2)),
      date: date,
      categoryIndex: category.index,
      note: note,
      isIncome: isIncome,
      currencyCode: currency,
    ));
  }

  static void _addIfPast(
    List<Expense> expenses,
    DateTime now, {
    required double amount,
    required DateTime date,
    required Category category,
    required String note,
    required String currency,
  }) {
    if (date.isBefore(now) || date.isAtSameMomentAs(now)) {
      _add(expenses,
          amount: amount,
          date: date,
          category: category,
          note: note,
          currency: currency);
    }
  }
}
