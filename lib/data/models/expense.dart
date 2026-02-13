import 'package:hive/hive.dart';

import 'category.dart';

part 'expense.g.dart';

@HiveType(typeId: 0)
class Expense extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final int categoryIndex;

  @HiveField(4)
  final String? note;

  @HiveField(5)
  final bool isIncome;

  Expense({
    required this.id,
    required this.amount,
    required this.date,
    required this.categoryIndex,
    this.note,
    this.isIncome = false,
  });

  Category get category => CategoryExtension.fromIndex(categoryIndex);

  Expense copyWith({
    String? id,
    double? amount,
    DateTime? date,
    int? categoryIndex,
    String? note,
    bool? isIncome,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryIndex: categoryIndex ?? this.categoryIndex,
      note: note ?? this.note,
      isIncome: isIncome ?? this.isIncome,
    );
  }
}
