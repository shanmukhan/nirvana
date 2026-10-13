import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities.dart';
import '../../domain/routine_config.dart' as config;
import '../../domain/session_clock.dart';
import '../../providers/dhyana_providers.dart';
import '../../providers/calendar_providers.dart';
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
  final SessionClock? clock;
  const DhyanaScreen({super.key, this.clock});

  @override
  ConsumerState<DhyanaScreen> createState() => _DhyanaScreenState();
}

class _DhyanaScreenState extends ConsumerState<DhyanaScreen> with WidgetsBindingObserver {
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
  late final SessionClock _clock = widget.clock ?? SessionClock();
  Duration get _elapsed => _clock.elapsed;
  bool get _running => _clock.active;
  bool _finishing = false;
  bool _checkedIn = false;
  _CloseCheckIn? _pendingCheckIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _clock.running) _tick();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _start() {
    if (_finishing || _running) return;
    SystemSound.play(SystemSoundType.click);
    setState(() => _clock.start());
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || !_clock.running || _finishing) return;
    if (_elapsed >= Duration(minutes: _plannedMinutes)) {
      _finish();
    } else {
      setState(() {});
    }
  }

  void _togglePause() {
    if (_finishing) return;
    setState(() {
      if (_clock.running) {
        _clock.pause();
        _ticker?.cancel();
      } else {
        _clock.resume();
        _startTicker();
      }
    });
  }

  Future<void> _finish() async {
    if (_finishing || !_running) return;
    _ticker?.cancel();
    setState(() {
      _finishing = true;
      _clock.pause();
    });
    SystemSound.play(SystemSoundType.click);
    final actualMinutes = (_elapsed.inSeconds / 60).ceil().clamp(1, _plannedMinutes);
    final repository = ref.read(dhyanaRepositoryProvider);
    final refresh = ref.read(dhyanaRefreshProvider.notifier);
    try {
      if (!_checkedIn) {
        _pendingCheckIn = await _showCloseCheckIn(context);
        _checkedIn = true;
      }
      await repository.logSession(
        plannedDurationMin: _plannedMinutes,
        actualDurationMin: actualMinutes,
        practiceType: _toEntityPractice(_practice),
        moodBefore1to5: _moodBefore,
        moodAfter1to5: _pendingCheckIn?.moodAfter,
        notes: _pendingCheckIn?.notes,
      );
      if (refresh.mounted) refresh.state++;
      _clock.reset();
      _checkedIn = false;
      _pendingCheckIn = null;
      _moodBefore = null;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the session. It is paused; tap End now to retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
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
      _clock.reset();
      _checkedIn = false;
      _pendingCheckIn = null;
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
            _MoodPicker(value: _moodBefore, onChanged: (v) => setState(() => _moodBefore = v)),
            const SizedBox(height: 24),
            Center(
              child: FilledButton.icon(
                onPressed: _finishing ? null : _start,
                icon: const Icon(Icons.self_improvement),
                label: const Text('Start session'),
              ),
            ),
          ] else ...[
            Center(
              child: Wrap(
                spacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: _finishing ? null : _togglePause,
                    child: Text(_clock.running ? 'Pause' : 'Resume'),
                  ),
                  FilledButton(
                    onPressed: _finishing ? null : _finish,
                    child: Text(_finishing ? 'Saving…' : 'End now'),
                  ),
                  OutlinedButton(
                    onPressed: _finishing ? null : _stopWithoutLogging,
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
            data: (minutes) =>
                Text('Last 7 days: $minutes min sat', style: Theme.of(context).textTheme.bodySmall),
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
          Text('How do you feel now? (optional)', style: Theme.of(context).textTheme.bodySmall),
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Skip')),
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
      if (!context.mounted) return;
      ref.read(dhyanaSelectedDateProvider.notifier).state = picked == ref.read(currentDayProvider)
          ? null
          : picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(dhyanaEffectiveDateProvider);
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
