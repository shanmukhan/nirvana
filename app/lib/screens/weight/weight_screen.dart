import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities.dart';
import '../../providers/repository_providers.dart';
import '../screen_scaffold.dart';

final weightRefreshProvider = StateProvider<int>((ref) => 0);

final recentWeightEntriesProvider = FutureProvider.autoDispose<List<WeightEntry>>((
  ref,
) async {
  ref.watch(weightRefreshProvider);
  return ref.watch(weightRepositoryProvider).recent(limit: 14);
});

final sevenDayAverageProvider = FutureProvider.autoDispose<double?>((ref) async {
  ref.watch(weightRefreshProvider);
  return ref.watch(weightRepositoryProvider).sevenDayAverageKg();
});

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
    final controller = TextEditingController();
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log weight', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(controller.text);
                if (value != null) Navigator.of(context).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await ref.read(weightRepositoryProvider).add(weightKg: result);
      ref.read(weightRefreshProvider.notifier).state++;
    }
  }
}
