import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities.dart';
import '../../domain/routine_config.dart' as config;
import '../../providers/dhyana_providers.dart';
import '../../providers/repository_providers.dart';
import '../screen_scaffold.dart';

const Map<config.DhyanaPracticeType, String> _practiceLabels = {
  config.DhyanaPracticeType.breathAwareness: 'Breath awareness',
  config.DhyanaPracticeType.bodyScan: 'Body scan',
  config.DhyanaPracticeType.mantra: 'Mantra / counting',
};

const Map<DhyanaPractice, String> _entityPracticeLabels = {
  DhyanaPractice.breathAwareness: 'Breath awareness',
  DhyanaPractice.bodyScan: 'Body scan',
  DhyanaPractice.mantra: 'Mantra / counting',
};

DhyanaPractice _toEntityPractice(config.DhyanaPracticeType t) => switch (t) {
  config.DhyanaPracticeType.breathAwareness => DhyanaPractice.breathAwareness,
  config.DhyanaPracticeType.bodyScan => DhyanaPractice.bodyScan,
  config.DhyanaPracticeType.mantra => DhyanaPractice.mantra,
};

/// Timer + start/end bell + session log. See docs/dhyana-plan.md.
/// No streak-shaming copy anywhere in this screen — a missed day is just
/// a missed day.
class DhyanaScreen extends ConsumerStatefulWidget {
  const DhyanaScreen({super.key});

  @override
  ConsumerState<DhyanaScreen> createState() => _DhyanaScreenState();
}

class _DhyanaScreenState extends ConsumerState<DhyanaScreen> {
  static const config.DhyanaConfig _defaultConfig = config.DhyanaConfig();

  static bool get _isWeekend =>
      DateTime.now().weekday == DateTime.saturday || DateTime.now().weekday == DateTime.sunday;

  // Weekends default to the longer weekend session length — see
  // docs/dhyana-plan.md "Weekend" — since there's no workday time pressure.
  static int get _defaultPlannedMinutes => _isWeekend
      ? _defaultConfig.weekendSession.durationMinutes
      : _defaultConfig.primarySession.durationMinutes;

  config.DhyanaPracticeType _practice = _defaultConfig.primarySession.defaultPractice;
  int _plannedMinutes = _defaultPlannedMinutes;
  int? _moodBefore;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _running = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    SystemSound.play(SystemSoundType.click); // gentle start bell stand-in
    setState(() {
      _running = true;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed.inMinutes >= _plannedMinutes) {
        _finish();
      }
    });
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    SystemSound.play(SystemSoundType.click); // gentle close bell stand-in
    final actualMinutes = (_elapsed.inSeconds / 60).ceil().clamp(0, 1 << 30);
    setState(() => _running = false);

    // Optional, skippable check-in — mood/notes are never required to
    // close out a session (docs/dhyana-plan.md: no forced friction).
    final checkIn = mounted ? await _showCloseCheckIn(context) : null;

    // No forced minimum duration — even a short session counts as completed.
    await ref
        .read(dhyanaRepositoryProvider)
        .logSession(
          plannedDurationMin: _plannedMinutes,
          actualDurationMin: actualMinutes == 0 ? 1 : actualMinutes,
          practiceType: _toEntityPractice(_practice),
          moodBefore1to5: _moodBefore,
          moodAfter1to5: checkIn?.moodAfter,
          notes: checkIn?.notes,
        );
    ref.read(dhyanaRefreshProvider.notifier).state++;
    setState(() {
      _elapsed = Duration.zero;
      _moodBefore = null;
    });
  }

  Future<_CloseCheckIn?> _showCloseCheckIn(BuildContext context) {
    return showDialog<_CloseCheckIn>(
      context: context,
      builder: (context) => const _CloseCheckInDialog(),
    );
  }

  void _stopWithoutLogging() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _elapsed = Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(dhyanaStreakProvider);
    final weekMinutes = ref.watch(dhyanaWeekMinutesProvider);
    final remaining = Duration(minutes: _plannedMinutes) - _elapsed;

    return ScreenScaffold(
      title: 'Dhyana',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Text(
              _running
                  ? _formatDuration(remaining.isNegative ? Duration.zero : remaining)
                  : '$_plannedMinutes:00',
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ),
          const SizedBox(height: 24),
          if (!_running) ...[
            DropdownButtonFormField<config.DhyanaPracticeType>(
              initialValue: _practice,
              decoration: const InputDecoration(labelText: 'Practice'),
              items: [
                for (final entry in _practiceLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _practice = value!),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _plannedMinutes.toDouble(),
              min: 2,
              max: 30,
              divisions: 28,
              label: '$_plannedMinutes min',
              onChanged: (value) => setState(() => _plannedMinutes = value.round()),
            ),
            Center(child: Text('$_plannedMinutes minutes')),
            const SizedBox(height: 24),
            Text('How are you feeling? (optional)', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            _MoodPicker(
              value: _moodBefore,
              onChanged: (v) => setState(() => _moodBefore = v),
            ),
            const SizedBox(height: 24),
            Center(
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.self_improvement),
                label: const Text('Start session'),
              ),
            ),
          ] else ...[
            Center(
              child: Wrap(
                spacing: 12,
                children: [
                  FilledButton(onPressed: _finish, child: const Text('End now')),
                  OutlinedButton(
                    onPressed: _stopWithoutLogging,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const _SessionsLogSection(),
          const SizedBox(height: 8),
          streak.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (days) => Text(
              days == 0 ? 'No current streak — that\'s okay, start today.' : 'Streak: $days days',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          weekMinutes.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (minutes) => Text(
              'Last 7 days: $minutes min sat',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// A row of five tappable numbered circles for an optional 1-5 mood
/// rating. [value] of null means "not rated" — never forced.
class _MoodPicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _MoodPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var rating = 1; rating <= 5; rating++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              customBorder: const CircleBorder(),
              // Tapping the already-selected rating clears it.
              onTap: () => onChanged(value == rating ? null : rating),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: value == rating
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                child: Text(
                  '$rating',
                  style: TextStyle(
                    color: value == rating ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Optional mood-after + notes captured when a session ends.
class _CloseCheckIn {
  final int? moodAfter;
  final String? notes;

  const _CloseCheckIn({this.moodAfter, this.notes});
}

/// Shown once a session ends. Entirely skippable — either button closes
/// out the session; "Skip" logs it with no mood-after/notes.
class _CloseCheckInDialog extends StatefulWidget {
  const _CloseCheckInDialog();

  @override
  State<_CloseCheckInDialog> createState() => _CloseCheckInDialogState();
}

class _CloseCheckInDialogState extends State<_CloseCheckInDialog> {
  int? _moodAfter;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Session complete'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How do you feel now? (optional)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _MoodPicker(value: _moodAfter, onChanged: (v) => setState(() => _moodAfter = v)),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _CloseCheckIn(
              moodAfter: _moodAfter,
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Date picker + list of sessions (practice, time, duration) logged on the
/// selected date. Defaults to today via [dhyanaSelectedDateProvider].
class _SessionsLogSection extends ConsumerWidget {
  const _SessionsLogSection();

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(dhyanaSelectedDateProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(dhyanaSelectedDateProvider);
    final sessionsAsync = ref.watch(dhyanaSessionsForSelectedDateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _isToday(selectedDate) ? 'Sessions today' : 'Sessions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => _pickDate(context, ref, selectedDate),
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(DateFormat('EEE, MMM d').format(selectedDate)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        sessionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const SizedBox.shrink(),
          data: (sessions) {
            if (sessions.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _isToday(selectedDate)
                      ? 'No sessions logged today yet.'
                      : 'No sessions logged on this day.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }
            return Column(
              children: [
                for (final session in sessions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.self_improvement_outlined),
                    title: Text(_entityPracticeLabels[session.practiceType] ?? 'Session'),
                    subtitle: Text(
                      [
                        DateFormat('h:mm a').format(session.date),
                        if (session.moodBefore1to5 != null || session.moodAfter1to5 != null)
                          'mood ${session.moodBefore1to5 ?? '–'} → ${session.moodAfter1to5 ?? '–'}',
                        if (session.notes != null && session.notes!.isNotEmpty) session.notes!,
                      ].join(' · '),
                    ),
                    trailing: Text(
                      '${session.actualDurationMin} min',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
