import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/currency_helper.dart';
import '../providers/settings_provider.dart';
import '../data/models/category.dart';
import '../data/models/expense.dart';
import '../providers/expense_provider.dart';

class ExpenseFormScreen extends StatefulWidget {
  final Expense? expense;
  final VoidCallback? onSave;

  const ExpenseFormScreen({
    super.key,
    this.expense,
    this.onSave,
  });

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late Category _category;
  late DateTime _date;
  late bool _isIncome;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      final e = widget.expense!;
      _amountController = TextEditingController(text: e.amount.toString());
      _noteController = TextEditingController(text: e.note ?? '');
      _category = e.category;
      _date = e.date;
      _isIncome = e.isIncome;
    } else {
      _amountController = TextEditingController();
      _noteController = TextEditingController();
      _category = Category.food;
      _date = DateTime.now();
      _isIncome = false;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Income'),
              subtitle: Text(_isIncome ? 'Money received' : 'Expense'),
              value: _isIncome,
              onChanged: (v) => setState(() => _isIncome = v),
            ),
            const SizedBox(height: 16),
            Consumer<SettingsProvider>(
              builder: (context, settings, _) => TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  border: const OutlineInputBorder(),
                  prefixText: '${settings.currency.symbol} ',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Category>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: Category.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(c.icon, size: 20, color: c.color),
                            const SizedBox(width: 8),
                            Text(c.label),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? Category.other),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Date'),
              subtitle: Text(
                '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Add a note...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_isEditing ? 'Update' : 'Add Transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final provider = context.read<ExpenseProvider>();
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    if (_isEditing && widget.expense != null) {
      final updated = widget.expense!.copyWith(
        amount: amount,
        date: _date,
        categoryIndex: _category.index,
        note: note,
        isIncome: _isIncome,
      );
      provider.updateExpense(widget.expense!, updated);
    } else {
      final expense = Expense(
        id: const Uuid().v4(),
        amount: amount,
        date: _date,
        categoryIndex: _category.index,
        note: note,
        isIncome: _isIncome,
      );
      provider.addExpense(expense);
    }

    widget.onSave?.call();
    if (mounted) Navigator.of(context).pop();
  }
}
