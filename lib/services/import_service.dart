import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/models/category.dart';
import '../data/models/expense.dart';
import '../providers/expense_provider.dart';

class ImportService {
  /// Picks an Excel file and imports expenses from the "Raw Data" sheet.
  /// Expected columns: Date | Category | Amount | Note
  /// Amount: positive = income, negative = expense
  static Future<ImportResult> importFromExcel(
    ExpenseProvider provider, {
    bool merge = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult(success: false, imported: 0, message: 'No file selected');
    }

    final file = result.files.single;
    final bytes = file.bytes ?? <int>[];

    if (bytes.isEmpty) {
      return ImportResult(
        success: false,
        imported: 0,
        message: 'Could not read file contents',
      );
    }

    try {
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel['Raw Data'] ?? excel[excel.tables.keys.first];

      if (sheet == null || sheet.maxRows < 2) {
        return ImportResult(
          success: false,
          imported: 0,
          message: 'No data found in file. Expected "Raw Data" sheet with headers: Date, Category, Amount, Note',
        );
      }

      final expenses = <Expense>[];
      final dateFormat = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');

      for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        final row = sheet.row(rowIndex);
        if (row.isEmpty) continue;

        final dateCell = row.isNotEmpty ? row[0]?.value : null;
        final categoryCell = row.length > 1 ? row[1]?.value : null;
        final amountCell = row.length > 2 ? row[2]?.value : null;
        final noteCell = row.length > 3 ? row[3]?.value : null;

        DateTime? date;
        if (dateCell != null) {
          if (dateCell is DateCellValue) {
            date = DateTime(dateCell.year, dateCell.month, dateCell.day);
          } else if (dateCell is DateTimeCellValue) {
            date = DateTime(
              dateCell.year,
              dateCell.month,
              dateCell.day,
            );
          } else if (dateCell is TextCellValue) {
            final str = _cellValueToString(dateCell);
            final match = dateFormat.firstMatch(str);
            if (match != null) {
              date = DateTime(
                int.parse(match.group(1)!),
                int.parse(match.group(2)!),
                int.parse(match.group(3)!),
              );
            }
          }
        }

        double? amount;
        if (amountCell != null) {
          if (amountCell is DoubleCellValue) {
            amount = amountCell.value;
          } else if (amountCell is IntCellValue) {
            amount = amountCell.value.toDouble();
          } else if (amountCell is TextCellValue) {
            amount = double.tryParse(_cellValueToString(amountCell).replaceAll(',', ''));
          }
        }

        final category = _parseCategory(categoryCell);
        final noteStr = noteCell is TextCellValue ? _cellValueToString(noteCell) : null;
        final note = noteStr != null && noteStr.isNotEmpty ? noteStr : null;

        if (date != null && amount != null && amount != 0) {
          final isIncome = amount > 0;
          expenses.add(Expense(
            id: const Uuid().v4(),
            amount: amount.abs(),
            date: date,
            categoryIndex: category.index,
            note: note,
            isIncome: isIncome,
          ));
        }
      }

      if (expenses.isEmpty) {
        return ImportResult(
          success: false,
          imported: 0,
          message: 'No valid expense rows found. Check Date and Amount columns.',
        );
      }

      if (!merge) {
        provider.clearAll();
      }
      for (final e in expenses) {
        provider.addExpense(e);
      }

      return ImportResult(
        success: true,
        imported: expenses.length,
        message: 'Imported ${expenses.length} transactions',
      );
    } catch (e) {
      return ImportResult(
        success: false,
        imported: 0,
        message: 'Import failed: $e',
      );
    }
  }

  static String _cellValueToString(TextCellValue cell) {
    final span = cell.value;
    return span.text ?? span.toString();
  }

  static Category _parseCategory(dynamic cell) {
    if (cell == null) return Category.other;
    final str = cell is TextCellValue
        ? _cellValueToString(cell).toLowerCase()
        : cell.toString().toLowerCase();
    for (final c in Category.values) {
      if (c.label.toLowerCase() == str) return c;
    }
    return Category.other;
  }
}

class ImportResult {
  final bool success;
  final int imported;
  final String message;

  ImportResult({
    required this.success,
    required this.imported,
    required this.message,
  });
}
