export '../../providers/health_log_providers.dart'
    show weightRefreshProvider, recentWeightEntriesProvider, sevenDayAverageProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/repository_providers.dart';
import '../../providers/health_log_providers.dart';
import '../screen_scaffold.dart';
import '../save_button.dart';

/// Weight entry, 7-day average, and trend. See health-plan-source.md §16:
/// judge progress from the weekly average, never a single day's reading.
class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(recentWeightEntriesProvider);
    final averageAsync = ref.watch(sevenDayAverageProvider);

    return ScreenScaffold(
      title: 'Weight',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Log weight',
          onPressed: () => _showAddWeightSheet(context, ref),
        ),
      ],
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load weight log: $e')),
        data: (entries) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('7-day average', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    averageAsync.when(
                      loading: () => const Text('…'),
                      error: (e, _) => Text('—'),
                      data: (avg) => Text(
                        avg == null ? 'No entries yet' : '${avg.toStringAsFixed(1)} kg',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    if (entries.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Most recent: ${entries.first.weightKg.toStringAsFixed(1)} kg',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('No weigh-ins yet. Tap + to log one.')),
              )
            else
              for (final entry in entries)
                ListTile(
                  leading: const Icon(Icons.monitor_weight_outlined),
                  title: Text('${entry.weightKg.toStringAsFixed(1)} kg'),
                  subtitle: Text(DateFormat.yMMMd().add_jm().format(entry.takenAt)),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddWeightSheet(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(weightRepositoryProvider);
    final refresh = ref.read(weightRefreshProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WeightEntrySheet(
        onSave: (kg) async {
          await repo.add(weightKg: kg);
          if (refresh.mounted) refresh.state++;
        },
      ),
    );
  }
}

class _WeightEntrySheet extends StatefulWidget {
  final Future<void> Function(double) onSave;
  const _WeightEntrySheet({required this.onSave});
  @override
  State<_WeightEntrySheet> createState() => _WeightEntrySheetState();
}

class _WeightEntrySheetState extends State<_WeightEntrySheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log weight', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
              validator: (text) {
                final value = double.tryParse(text?.trim() ?? '');
                return value == null || !value.isFinite || value <= 0
                    ? 'Enter a weight greater than zero.'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            SaveButton(
              onSave: () async {
                if (!_formKey.currentState!.validate()) return false;
                await widget.onSave(double.parse(_controller.text.trim()));
                return true;
              },
              onSaved: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
