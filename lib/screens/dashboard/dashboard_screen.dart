import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/category_pie_chart.dart';
import '../../widgets/expense_list.dart';
import '../../widgets/filter_tabs.dart';
import '../expense_form_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  FilterType _filter = FilterType.monthly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DailySpend'),
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          final expenses = provider.filteredExpenses(_filter);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilterTabs(
                  selectedFilter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CategoryPieChart(
                          expenses: expenses,
                          filter: _filter,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Transactions',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: ExpenseList(
                          expenses: expenses,
                          filter: _filter,
                          onEdit: (e) => _showExpenseForm(context, expense: e),
                          onDelete: (e) => _confirmDelete(context, provider, e),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showExpenseForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showExpenseForm(BuildContext context, {Expense? expense}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenseFormScreen(
          expense: expense,
          onSave: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ExpenseProvider provider, Expense e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text(
          'Are you sure you want to delete this transaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              provider.deleteExpense(e);
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
