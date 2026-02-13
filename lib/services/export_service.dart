import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../data/models/category.dart';
import '../data/models/expense.dart';
import '../providers/expense_provider.dart';

class ExportService {
  static Future<String?> exportToExcel(ExpenseProvider provider) async {
    try {
      final excel = Excel.createExcel();
      excel.rename('Sheet1', 'Raw Data');

      _buildRawDataSheet(excel['Raw Data']!, provider.expenses);
      _buildMatrixSheet(excel, provider);

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'DailySpend_${DateFormat('yMd').format(DateTime.now()).replaceAll('/', '-')}.xlsx';
      final path = '${dir.path}/$fileName';

      final fileBytes = excel.encode();
      if (fileBytes == null) return null;

      final file = File(path);
      await file.writeAsBytes(fileBytes);

      return path;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> shareExport(ExpenseProvider provider) async {
    final path = await exportToExcel(provider);
    if (path != null) {
      await Share.shareXFiles([XFile(path)]);
    }
  }

  static void _buildRawDataSheet(Sheet sheet, List<Expense> expenses) {
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('Currency'),
      TextCellValue('Note'),
    ]);

    for (final e in expenses) {
      sheet.appendRow([
        DateCellValue(
          year: e.date.year,
          month: e.date.month,
          day: e.date.day,
        ),
        TextCellValue(e.category.label),
        DoubleCellValue(e.isIncome ? e.amount : -e.amount),
        TextCellValue(e.currencyCode),
        TextCellValue(e.note ?? ''),
      ]);
    }
  }

  static void _buildMatrixSheet(Excel excel, ExpenseProvider provider) {
    final filter = FilterType.monthly;
    final spreadsheetData = provider.getSpreadsheetData(filter);
    final periodKeys = provider.getPeriodKeys(filter);
    final periodLabels = provider.getPeriodLabels(filter);

    if (periodKeys.isEmpty) return;

    final headerRow = <CellValue>[TextCellValue('Category')];
    for (final label in periodLabels) {
      headerRow.add(TextCellValue(label));
    }
    excel.insertRowIterables('Matrix', headerRow, 0);

    final sheet = excel['Matrix']!;
    for (final category in Category.values) {
      final row = <CellValue>[TextCellValue(category.label)];
      for (var i = 0; i < periodKeys.length; i++) {
        final key = periodKeys[i];
        final value = spreadsheetData[category]?[key] ?? 0.0;
        row.add(DoubleCellValue(value));
      }
      sheet.appendRow(row);
    }

    final totalRow = <CellValue>[TextCellValue('Total')];
    for (final key in periodKeys) {
      double sum = 0;
      for (final category in Category.values) {
        sum += spreadsheetData[category]?[key] ?? 0;
      }
      totalRow.add(DoubleCellValue(sum));
    }
    sheet.appendRow(totalRow);
  }
}
