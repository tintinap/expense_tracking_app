import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/currency_helper.dart';
import '../../providers/expense_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/export_service.dart';
import '../../services/import_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Theme',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Consumer<SettingsProvider>(
            builder: (context, settings, _) => Column(
              children: [
                RadioListTile<ThemeModeOption>(
                  title: const Text('System'),
                  value: ThemeModeOption.system,
                  groupValue: settings.themeMode,
                  onChanged: (v) =>
                      settings.setThemeMode(v ?? ThemeModeOption.system),
                ),
                RadioListTile<ThemeModeOption>(
                  title: const Text('Light'),
                  value: ThemeModeOption.light,
                  groupValue: settings.themeMode,
                  onChanged: (v) =>
                      settings.setThemeMode(v ?? ThemeModeOption.light),
                ),
                RadioListTile<ThemeModeOption>(
                  title: const Text('Dark'),
                  value: ThemeModeOption.dark,
                  groupValue: settings.themeMode,
                  onChanged: (v) =>
                      settings.setThemeMode(v ?? ThemeModeOption.dark),
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Currency',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Consumer<SettingsProvider>(
            builder: (context, settings, _) => Column(
              children: CurrencyCode.values
                  .map((c) => RadioListTile<CurrencyCode>(
                        title: Text('${c.symbol} ${c.name} (${c.code})'),
                        value: c,
                        groupValue: settings.currency,
                        onChanged: (v) => settings.setCurrency(v ?? c),
                      ))
                  .toList(),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Data',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Import from Excel'),
            subtitle: const Text(
              'Load data from .xlsx (Raw Data sheet: Date, Category, Amount, Note)',
            ),
            onTap: () => _importExcel(context),
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Export to Excel'),
            subtitle: const Text(
              'Export raw data and spreadsheet matrix as .xlsx',
            ),
            onTap: () => _exportAndShare(context),
          ),
        ],
      ),
    );
  }

  Future<void> _importExcel(BuildContext context) async {
    final provider = context.read<ExpenseProvider>();
    final merge = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import from Excel'),
        content: const Text(
          'Replace existing data or merge with current data?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Merge'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (merge == null || !context.mounted) return;

    final result = await ImportService.importFromExcel(
      provider,
      merge: merge,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAndShare(BuildContext context) async {
    try {
      final provider = context.read<ExpenseProvider>();
      await ExportService.shareExport(provider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export ready to share')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}
