import 'package:hive_flutter/hive_flutter.dart';

import '../models/expense.dart';

class HiveService {
  static const String _expensesBoxName = 'expenses';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ExpenseAdapter());
    await Hive.openBox<Expense>(_expensesBoxName);
  }

  static Box<Expense> get expensesBox => Hive.box<Expense>(_expensesBoxName);
}
