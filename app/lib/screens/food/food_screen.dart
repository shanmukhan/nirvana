import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities.dart';
import '../../domain/meal_templates.dart';
import '../../providers/repository_providers.dart';
import '../screen_scaffold.dart';

final foodRefreshProvider = StateProvider<int>((ref) => 0);

final mealEntriesTodayProvider = FutureProvider.autoDispose<List<MealEntry>>((ref) {
  ref.watch(foodRefreshProvider);
  return ref.watch(mealRepositoryProvider).forDay(DateTime.now());
});

/// Meal logging against the templates in health-plan-source.md §9-§13, with
/// a protein estimate per entry tracked against the ~80-100g/day planning
/// range from §15. Quick-pick templates cover the common options from the
/// plan; "Add custom" covers anything else with a free-text description and
/// manual protein estimate.
class FoodScreen extends ConsumerWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(mealEntriesTodayProvider);

    return ScreenScaffold(
      title: 'Food',
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load food log: $e')),
        data: (entries) {
          final totalProtein = entries.fold<double>(
            0,
            (sum, e) => sum + (e.proteinEstimateG ?? 0),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProteinProgressCard(totalProtein: totalProtein),
              const SizedBox(height: 16),
              for (final mealType in MealType.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _MealSection(
                    mealType: mealType,
                    entries: entries.where((e) => e.mealType == mealType).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProteinProgressCard extends StatelessWidget {
  final double totalProtein;

  const _ProteinProgressCard({required this.totalProtein});

  @override
  Widget build(BuildContext context) {
    final progress = (totalProtein / dailyProteinTargetMaxG).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Protein today', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${totalProtein.toStringAsFixed(0)} g of '
              '${dailyProteinTargetMinG.toStringAsFixed(0)}-'
              '${dailyProteinTargetMaxG.toStringAsFixed(0)} g target',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealSection extends ConsumerWidget {
  final MealType mealType;
  final List<MealEntry> entries;

  const _MealSection({required this.mealType, required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = mealTemplates[mealType] ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mealType.label, style: Theme.of(context).textTheme.titleMedium),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final entry in entries) _MealEntryTile(entry: entry),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final template in templates)
                  ActionChip(
                    label: Text(template.label),
                    onPressed: () => _logTemplate(ref, template),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Custom'),
                  onPressed: () => _logCustom(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logTemplate(WidgetRef ref, MealTemplate template) async {
    await ref
        .read(mealRepositoryProvider)
        .log(
          mealType: mealType,
          description: template.description,
          proteinEstimateG: template.proteinEstimateG,
        );
    ref.read(foodRefreshProvider.notifier).state++;
  }

  Future<void> _logCustom(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<_CustomMealDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _CustomMealSheet(),
    );
    if (result == null || result.description.trim().isEmpty) return;

    await ref
        .read(mealRepositoryProvider)
        .log(
          mealType: mealType,
          description: result.description.trim(),
          proteinEstimateG: result.proteinEstimateG,
        );
    ref.read(foodRefreshProvider.notifier).state++;
  }
}

class _MealEntryTile extends ConsumerWidget {
  final MealEntry entry;

  const _MealEntryTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(entry.description),
      subtitle: Text(
        '${DateFormat.jm().format(entry.loggedAt)}'
        '${entry.proteinEstimateG != null ? '  ·  ~${entry.proteinEstimateG!.toStringAsFixed(0)} g protein' : ''}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: 'Remove',
        onPressed: () async {
          await ref.read(mealRepositoryProvider).delete(entry.id);
          ref.read(foodRefreshProvider.notifier).state++;
        },
      ),
    );
  }
}

class _CustomMealDraft {
  String description = '';
  double? proteinEstimateG;
}

class _CustomMealSheet extends StatefulWidget {
  const _CustomMealSheet();

  @override
  State<_CustomMealSheet> createState() => _CustomMealSheetState();
}

class _CustomMealSheetState extends State<_CustomMealSheet> {
  final _draft = _CustomMealDraft();
  final _descriptionController = TextEditingController();
  final _proteinController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    _proteinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Text('Log a meal', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'What did you eat?'),
            onChanged: (v) => _draft.description = v,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _proteinController,
            decoration: const InputDecoration(
              labelText: 'Protein estimate (g, optional)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => _draft.proteinEstimateG = double.tryParse(v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_draft),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
