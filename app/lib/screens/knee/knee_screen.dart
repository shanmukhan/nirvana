import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities.dart';
import '../../providers/repository_providers.dart';
import '../screen_scaffold.dart';

final kneeRefreshProvider = StateProvider<int>((ref) => 0);

final recentPainEntriesProvider = FutureProvider.autoDispose<List<PainEntry>>((
  ref,
) async {
  ref.watch(kneeRefreshProvider);
  return ref.watch(painRepositoryProvider).recent(limit: 14);
});

/// Pain/swelling/stiffness log. Red-flag symptoms route to a "consider
/// professional assessment" message, never "push through it".
/// See health-plan-source.md §8, §22.
class KneeScreen extends ConsumerWidget {
  const KneeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(recentPainEntriesProvider);
    return ScreenScaffold(
      title: 'Knee',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Log knee check-in',
          onPressed: () => _showLogSheet(context, ref),
        ),
      ],
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load knee log: $e')),
        data: (entries) => entries.isEmpty
            ? const Center(child: Text('No entries yet. Tap + to log a check-in.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final entry in entries) _PainTile(entry: entry),
                ],
              ),
      ),
    );
  }

  Future<void> _showLogSheet(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<_PainDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _PainEntrySheet(),
    );
    if (result == null) return;

    await ref
        .read(painRepositoryProvider)
        .log(
          painBefore0to10: result.pain,
          swelling: result.swelling,
          stiffness0to10: result.stiffness,
          sharpPain: result.sharpPain,
          locking: result.locking,
          givingWay: result.givingWay,
        );
    ref.read(kneeRefreshProvider.notifier).state++;

    final needsAssessment =
        result.sharpPain || result.locking || result.givingWay || result.swelling;
    if (needsAssessment && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Consider professional assessment'),
          content: const Text(
            'What you logged — sharp pain, locking, giving-way, or significant '
            'swelling — is worth having assessed by a clinician. This app cannot '
            'diagnose or treat knee OA; please don\'t push through it.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it')),
          ],
        ),
      );
    }
  }
}

class _PainTile extends StatelessWidget {
  final PainEntry entry;

  const _PainTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        entry.needsProfessionalAssessmentFlag ? Icons.warning_amber_outlined : Icons.check_circle_outline,
        color: entry.needsProfessionalAssessmentFlag ? Colors.orange : null,
      ),
      title: Text('Pain ${entry.painBefore0to10}/10  ·  Stiffness ${entry.stiffness0to10}/10'),
      subtitle: Text(
        '${DateFormat.yMMMd().add_jm().format(entry.recordedAt)}'
        '${entry.swelling ? '  ·  Swelling' : ''}',
      ),
    );
  }
}

class _PainDraft {
  int pain = 0;
  int stiffness = 0;
  bool swelling = false;
  bool sharpPain = false;
  bool locking = false;
  bool givingWay = false;
}

class _PainEntrySheet extends StatefulWidget {
  const _PainEntrySheet();

  @override
  State<_PainEntrySheet> createState() => _PainEntrySheetState();
}

class _PainEntrySheetState extends State<_PainEntrySheet> {
  final _draft = _PainDraft();

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
          Text('Knee check-in', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('Pain: ${_draft.pain}/10'),
          Slider(
            value: _draft.pain.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) => setState(() => _draft.pain = v.round()),
          ),
          Text('Stiffness: ${_draft.stiffness}/10'),
          Slider(
            value: _draft.stiffness.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) => setState(() => _draft.stiffness = v.round()),
          ),
          SwitchListTile(
            title: const Text('Swelling'),
            value: _draft.swelling,
            onChanged: (v) => setState(() => _draft.swelling = v),
          ),
          SwitchListTile(
            title: const Text('Sharp pain'),
            value: _draft.sharpPain,
            onChanged: (v) => setState(() => _draft.sharpPain = v),
          ),
          SwitchListTile(
            title: const Text('Locking'),
            value: _draft.locking,
            onChanged: (v) => setState(() => _draft.locking = v),
          ),
          SwitchListTile(
            title: const Text('Giving-way'),
            value: _draft.givingWay,
            onChanged: (v) => setState(() => _draft.givingWay = v),
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
