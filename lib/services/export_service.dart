import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../data/models/category.dart';
import '../data/models/expense.dart';
import '../providers/expense_provider.dart';
import 'export_helper_stub.dart'
    if (dart.library.io) 'export_helper_native.dart'
    if (dart.library.html) 'export_helper_web.dart' as helper;

class ExportService {
  static Future<void> shareExport(ExpenseProvider provider) async {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Raw Data');

    _buildRawDataSheet(excel['Raw Data'], provider.expenses);
    _buildMatrixSheet(excel, provider);

    final fileBytes = excel.encode();
    if (fileBytes == null) throw Exception('Failed to encode Excel file');

    final fileName =
        'DailySpend_${DateFormat('yMd').format(DateTime.now()).replaceAll('/', '-')}.xlsx';

    await helper.saveAndShareExcel(fileBytes, fileName);
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
    const filter = FilterType.monthly;
    final spreadsheetData = provider.getSpreadsheetData(filter);
    final periodKeys = provider.getPeriodKeys(filter);
    final periodLabels = provider.getPeriodLabels(filter);

    if (periodKeys.isEmpty) return;

    final headerRow = <CellValue>[TextCellValue('Category')];
    for (final label in periodLabels) {
      headerRow.add(TextCellValue(label));
    }
    excel.insertRowIterables('Matrix', headerRow, 0);

    final sheet = excel['Matrix'];
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
