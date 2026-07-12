import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/currency_helper.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/sign_in_banner.dart';
import '../../export/providers/export_provider.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/sheets_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../import/screens/import_preview_screen.dart';
import '../../sync/providers/sync_provider.dart';
import 'package:intl/intl.dart';
import 'package:currency_picker/currency_picker.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final viewCurrency = ref.watch(viewCurrencyProvider);
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.isAuthenticated;
    final syncState = ref.watch(syncProvider);
    final sheetsState = ref.watch(sheetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Account'),
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(isLoggedIn ? 'Signed In' : 'Sign In'),
            subtitle: Text(isLoggedIn
                ? 'Sync is active'
                : 'Sign in to sync data across devices'),
            trailing: isLoggedIn
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: isLoggedIn ? null : () => _showSignInSheet(context),
          ),
          if (isLoggedIn)
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync Status'),
              subtitle: Text(syncState.isSyncing 
                  ? 'Syncing...' 
                  : 'Pending: ${syncState.pendingCount} | Last: ${syncState.lastSync != null ? DateFormat('MMM d, HH:mm').format(syncState.lastSync!) : 'Never'}'),
              trailing: syncState.isSyncing 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : IconButton(icon: const Icon(Icons.sync), onPressed: () => ref.read(syncProvider.notifier).processQueue()),
            ),
          if (isLoggedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: () => ref.read(authStateProvider.notifier).signOut(),
            ),
          if (isLoggedIn)
            ListTile(
              leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
              title: Text('Delete Account', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              subtitle: const Text('Permanently delete your account and data'),
              onTap: () => _showDeleteAccountDialog(context, ref),
            ),
          const Divider(),
          _buildSectionHeader(context, 'Preferences'),
          ListTile(
            leading: const Icon(Icons.monetization_on),
            title: const Text('Base Currency'),
            subtitle: Text(_currencyDisplayName(baseCurrency)),
            trailing: Text(
              baseCurrency,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _showBaseCurrencyPicker(context, ref, baseCurrency),
          ),
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('View Currency'),
            subtitle: Text(_currencyDisplayName(viewCurrency)),
            trailing: Text(
              viewCurrency,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _showViewCurrencyPicker(context, ref, viewCurrency),
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Calculate Together'),
            subtitle: const Text('Combine multiple currencies in totals'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showCombineCurrenciesBottomSheet(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Theme'),
            trailing: Text(
              _themeLabel(themeMode),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _showThemePicker(context, ref, themeMode),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Data & Automation'),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/categories'),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Manage Recurring'),
            subtitle: const Text('Pause or delete recurring templates'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/recurring'),
          ),
          ListTile(
            leading: Icon(
              Icons.table_chart,
              color: isLoggedIn ? null : Theme.of(context).disabledColor,
            ),
            title: Text(
              'Google Sheets Sync',
              style: isLoggedIn
                  ? null
                  : TextStyle(color: Theme.of(context).disabledColor),
            ),
            subtitle: Text(
              !isLoggedIn
                  ? 'Sign in required'
                  : sheetsState.isConnected
                      ? 'Connected'
                      : 'Requires Google Account',
            ),
            trailing: sheetsState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : sheetsState.isConnected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.chevron_right),
            onTap: () async {
              if (!isLoggedIn) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please sign in to use Google Sheets sync'),
                  ),
                );
                return;
              }
              
              if (sheetsState.isConnected) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Disconnect Sheets?'),
                    content: const Text('Your spreadsheet will remain in Google Drive, but new transactions will no longer be synced.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  await ref.read(sheetsProvider.notifier).disconnect();
                }
              } else {
                // Connect flow
                final success = await ref.read(sheetsProvider.notifier).connect();
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Google Sheets connected!')),
                  );
                } else if (context.mounted && sheetsState.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(sheetsState.error!),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          if (isLoggedIn &&
              authState.authProvider == 'apple' &&
              !sheetsState.isConnected)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Google Sheets needs Google permissions'),
                  subtitle: Text(
                    'Apple sign-in is fine for app usage. Connect Google only when enabling Sheets sync.',
                  ),
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.table_view),
            title: const Text('Export to Excel'),
            subtitle: const Text('Choose date range and export .xlsx'),
            onTap: () => _showExportDateRangePicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Import from Excel'),
            subtitle: const Text('Import transactions from .xlsx file'),
            onTap: () => _pickAndImportExcel(context),
          ),
          const Divider(),
          _buildSectionHeader(context, 'About'),
          const ListTile(
            title: Text('Version'),
            trailing: Text('1.0.0 (v3.0)'),
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  void _showSignInSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AuthBottomSheet(),
    );
  }

  Future<void> _showExportDateRangePicker(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: DateTime(now.year, 1, 1),
      end: now,
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: initialRange,
      helpText: 'Select export date range',
      saveText: 'Export',
    );

    if (picked == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating Excel export...')),
    );

    final result = await ref.read(exportProvider).exportToExcel(
      from: picked.start,
      to: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Exported successfully'),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Export failed'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String _currencyDisplayName(String code) {
    return CurrencyCode.fromCode(code)?.name ?? code;
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  Future<void> _showViewCurrencyPicker(BuildContext context, WidgetRef ref, String selected) async {
    showCurrencyPicker(
      context: context,
      showFlag: true,
      showCurrencyName: true,
      showCurrencyCode: true,
      favorite: ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'THB'],
      onSelect: (Currency currency) {
        if (currency.code != selected) {
          ref.read(viewCurrencyProvider.notifier).set(currency.code);
        }
      },
    );
  }

  Future<void> _showBaseCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    String selected,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text('Base currency', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: CurrencyCode.values.map((c) {
                    final isSelected = c.code == selected;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          c.symbol,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(c.name),
                      subtitle: Text(c.code),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(ctx).pop(c.code),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null && picked != selected) {
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 24),
              Expanded(child: Text('Re-converting transactions...')),
            ],
          ),
        ),
      );

      try {
        await ref.read(baseCurrencyProvider.notifier).set(picked);
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Close dialog
        }
      }
    }
  }

  Future<void> _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) async {
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text('Theme', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...ThemeMode.values.map((mode) {
                final isSelected = mode == current;
                return ListTile(
                  leading: Icon(_themeIcon(mode)),
                  title: Text(_themeLabel(mode)),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(mode),
                );
              }),
            ],
          ),
        );
      },
    );

    if (picked != null && picked != current) {
      await ref.read(themeModeProvider.notifier).set(picked);
    }
  }

  IconData _themeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  Future<void> _pickAndImportExcel(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      if (!context.mounted) return;
      
      Navigator.push(
        context,
        ImportPreviewScreen.route(result.files.single.path!),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick file: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _showDeleteAccountDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'Are you sure you want to permanently delete your account? '
            'This action cannot be undone and all your data will be wiped.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 24),
              Text('Deleting account...'),
            ],
          ),
        ),
      );

      try {
        await ref.read(authStateProvider.notifier).deleteAccount();
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop(); // Close dialog
        }
      }
    }
  }

  Future<void> _showCombineCurrenciesBottomSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Consumer(
          builder: (ctx, ref, child) {
            final theme = Theme.of(ctx);
            final baseCurrency = ref.watch(baseCurrencyProvider);
            final enabledCurrencies = ref.watch(enabledCurrenciesProvider);
            final countsAsync = ref.watch(transactionCountByCurrencyProvider);

            return countsAsync.when(
              data: (counts) {
                final currencies = counts.keys.toSet().toList()..sort();
                if (!currencies.contains(baseCurrency)) {
                  currencies.insert(0, baseCurrency);
                }

                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            Text('Calculate Together', style: theme.textTheme.titleMedium),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: Text(
                          'Choose which currencies are combined and calculated in dashboard and report totals.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: currencies.map((currency) {
                            final isBase = currency == baseCurrency;
                            final isChecked = enabledCurrencies.contains(currency) || isBase;
                            
                            return CheckboxListTile(
                              title: Text(currency),
                              subtitle: Text(isBase ? 'Base Currency (Always Included)' : 'Include in calculations'),
                              value: isChecked,
                              onChanged: isBase
                                  ? null
                                  : (checked) {
                                      ref
                                          .read(enabledCurrenciesProvider.notifier)
                                          .toggleCurrency(currency, checked == true);
                                    },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SizedBox(
                height: 100,
                child: Center(child: Text('Error loading currencies: $err')),
              ),
            );
          },
        );
      },
    );
  }
}
