import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import '../../providers/repository_providers.dart';
import '../screen_scaffold.dart';
import 'guided_exercise_screen.dart';

final exerciseRefreshProvider = StateProvider<int>((ref) => 0);

final exerciseDefinitionsProvider = FutureProvider.autoDispose<List<ExerciseDefinition>>((
  ref,
) {
  return ref.watch(exerciseRepositoryProvider).allDefinitions();
});

final exerciseSessionsTodayProvider = FutureProvider.autoDispose<List<ExerciseSession>>((
  ref,
) {
  ref.watch(exerciseRefreshProvider);
  return ref.watch(exerciseRepositoryProvider).forDay(DateTime.now());
});

/// Logging (manual, or guided with a per-rep/rest timer — see
/// guided_exercise_screen.dart) for the 6 strength/knee-support exercises,
/// with sets/reps and a pain rating per health-plan-source.md §6, §20. A
/// "too painful" entry shows the same non-diagnostic stop-and-consider-
/// assessment guidance as the Knee screen (§8, §22) — never "push through
/// it".
class ExerciseScreen extends ConsumerWidget {
  const ExerciseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definitionsAsync = ref.watch(exerciseDefinitionsProvider);
    final sessionsAsync = ref.watch(exerciseSessionsTodayProvider);

    return ScreenScaffold(
      title: 'Exercise',
      body: definitionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load exercises: $e')),
        data: (definitions) {
          final sessionsToday = sessionsAsync.asData?.value ?? const <ExerciseSession>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final definition in definitions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExerciseCard(
                    definition: definition,
                    sessionsToday: sessionsToday
                        .where((s) => s.exerciseDefinitionId == definition.id)
                        .toList(),
                    onLog: () => _showLogSheet(context, ref, definition),
                    onStartGuided: () => _startGuided(context, ref, definition),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Pushes the guided timer flow (per-rep hold countdown or between-set
  /// rest countdown — see guided_exercise_screen.dart), then opens the
  /// same log sheet pre-filled with whatever sets/reps it actually
  /// completed, so the user can adjust and add a pain rating before saving.
  Future<void> _startGuided(
    BuildContext context,
    WidgetRef ref,
    ExerciseDefinition definition,
  ) async {
    final completed = await Navigator.of(context).push<GuidedExerciseResult>(
      MaterialPageRoute(builder: (context) => GuidedExerciseScreen(definition: definition)),
    );
    if (completed == null || !context.mounted) return;
    await _showLogSheet(
      context,
      ref,
      definition,
      initialSets: completed.completedSets,
      initialReps: completed.completedReps,
    );
  }

  Future<void> _showLogSheet(
    BuildContext context,
    WidgetRef ref,
    ExerciseDefinition definition, {
    int? initialSets,
    int? initialReps,
  }) async {
    final result = await showModalBottomSheet<_ExerciseLogDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ExerciseLogSheet(
        definition: definition,
        initialSets: initialSets,
        initialReps: initialReps,
      ),
    );
    if (result == null) return;

    await ref
        .read(exerciseRepositoryProvider)
        .logSession(
          exerciseDefinitionId: definition.id,
          completedSets: result.sets,
          completedReps: result.reps,
          painRating0to10: result.painRating,
          feedback: result.feedback,
        );
    ref.read(exerciseRefreshProvider.notifier).state++;

    if (result.feedback == ExerciseFeedback.tooPainful && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Noted — ease off next time'),
          content: const Text(
            'Try fewer reps or a smaller range of motion next session. This '
            'app can\'t diagnose or treat knee OA — if an exercise stays too '
            'painful across a few sessions, consider having it assessed by a '
            'clinician rather than pushing through it.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it')),
          ],
        ),
      );
    }
  }
}

class _ExerciseCard extends StatelessWidget {
  final ExerciseDefinition definition;
  final List<ExerciseSession> sessionsToday;
  final VoidCallback onLog;
  final VoidCallback onStartGuided;

  const _ExerciseCard({
    required this.definition,
    required this.sessionsToday,
    required this.onLog,
    required this.onStartGuided,
  });

  @override
  Widget build(BuildContext context) {
    final loggedToday = sessionsToday.isNotEmpty;
    return Card(
      child: InkWell(
        onTap: onLog,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(definition.name, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (loggedToday)
                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                  else
                    const Icon(Icons.radio_button_unchecked),
                ],
              ),
              const SizedBox(height: 8),
              Text(definition.instructions, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(
                '${definition.defaultSets} sets × ${definition.defaultReps} reps'
                '${definition.holdSeconds != null ? '  ·  hold ${definition.holdSeconds}s' : ''}'
                '${loggedToday ? '  ·  logged ${sessionsToday.length}x today' : ''}',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onStartGuided,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('Start guided'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseLogDraft {
  int sets;
  int reps;
  int painRating = 0;
  ExerciseFeedback feedback = ExerciseFeedback.fine;

  _ExerciseLogDraft({required this.sets, required this.reps});
}

class _ExerciseLogSheet extends StatefulWidget {
  final ExerciseDefinition definition;
  final int? initialSets;
  final int? initialReps;

  const _ExerciseLogSheet({required this.definition, this.initialSets, this.initialReps});

  @override
  State<_ExerciseLogSheet> createState() => _ExerciseLogSheetState();
}

class _ExerciseLogSheetState extends State<_ExerciseLogSheet> {
  late final _draft = _ExerciseLogDraft(
    sets: widget.initialSets ?? widget.definition.defaultSets,
    reps: widget.initialReps ?? widget.definition.defaultReps,
  );

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
          Text(widget.definition.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _Stepper(
            label: 'Sets',
            value: _draft.sets,
            onChanged: (v) => setState(() => _draft.sets = v),
          ),
          const SizedBox(height: 8),
          _Stepper(
            label: 'Reps',
            value: _draft.reps,
            onChanged: (v) => setState(() => _draft.reps = v),
          ),
          const SizedBox(height: 16),
          Text('Pain during: ${_draft.painRating}/10'),
          Slider(
            value: _draft.painRating.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) => setState(() => _draft.painRating = v.round()),
          ),
          const SizedBox(height: 8),
          SegmentedButton<ExerciseFeedback>(
            segments: const [
              ButtonSegment(
                value: ExerciseFeedback.fine,
                label: Text('Felt fine'),
                icon: Icon(Icons.sentiment_satisfied_outlined),
              ),
              ButtonSegment(
                value: ExerciseFeedback.tooPainful,
                label: Text('Too painful'),
                icon: Icon(Icons.sentiment_dissatisfied_outlined),
              ),
            ],
            selected: {_draft.feedback},
            onSelectionChanged: (selection) =>
                setState(() => _draft.feedback = selection.first),
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

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _Stepper({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}
