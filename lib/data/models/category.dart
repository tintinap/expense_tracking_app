import 'package:flutter/material.dart';

enum Category {
  food,
  transport,
  rent,
  shopping,
  bills,
  entertainment,
  health,
  income,
  other,
}

extension CategoryExtension on Category {
  String get label {
    switch (this) {
      case Category.food:
        return 'Food';
      case Category.transport:
        return 'Transport';
      case Category.rent:
        return 'Rent';
      case Category.shopping:
        return 'Shopping';
      case Category.bills:
        return 'Bills';
      case Category.entertainment:
        return 'Entertainment';
      case Category.health:
        return 'Health';
      case Category.income:
        return 'Income';
      case Category.other:
        return 'Other';
    }
  }

  int get index {
    switch (this) {
      case Category.food:
        return 0;
      case Category.transport:
        return 1;
      case Category.rent:
        return 2;
      case Category.shopping:
        return 3;
      case Category.bills:
        return 4;
      case Category.entertainment:
        return 5;
      case Category.health:
        return 6;
      case Category.income:
        return 7;
      case Category.other:
        return 8;
    }
  }

  static Category fromIndex(int index) {
    return Category.values.firstWhere(
      (c) => c.index == index,
      orElse: () => Category.other,
    );
  }

  IconData get icon {
    switch (this) {
      case Category.food:
        return Icons.restaurant;
      case Category.transport:
        return Icons.directions_car;
      case Category.rent:
        return Icons.home;
      case Category.shopping:
        return Icons.shopping_bag;
      case Category.bills:
        return Icons.receipt_long;
      case Category.entertainment:
        return Icons.movie;
      case Category.health:
        return Icons.favorite;
      case Category.income:
        return Icons.attach_money;
      case Category.other:
        return Icons.category;
    }
  }

  Color get color {
    switch (this) {
      case Category.food:
        return Colors.orange;
      case Category.transport:
        return Colors.blue;
      case Category.rent:
        return Colors.purple;
      case Category.shopping:
        return Colors.pink;
      case Category.bills:
        return Colors.red;
      case Category.entertainment:
        return Colors.amber;
      case Category.health:
        return Colors.green;
      case Category.income:
        return Colors.teal;
      case Category.other:
        return Colors.grey;
    }
  }
}
