import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recurring_provider.dart';

class RecurringTemplatesScreen extends ConsumerWidget {
  const RecurringTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(recurringTemplatesProvider);
    final actions = ref.watch(recurringTemplateActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Recurring')),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load recurring templates: $err')),
        data: (templates) {
          if (templates.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No recurring templates found.\nCreate one from the transaction form.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: templates.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final template = templates[index];
              final cadence = template.recurrenceType ?? 'paused';
              final amount = template.originalAmount.toStringAsFixed(2);
              return ListTile(
                title: Text(template.note?.isNotEmpty == true ? template.note! : 'Recurring template'),
                subtitle: Text('${template.originalCurrency} $amount · $cadence'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: cadence == 'paused'
                          ? null
                          : () async {
                              await actions.pauseTemplate(template);
                            },
                      child: const Text('Pause'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await actions.deleteTemplate(template.id);
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
