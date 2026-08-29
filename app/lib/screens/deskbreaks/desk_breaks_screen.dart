import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/desk_break_log_repository.dart';
import '../../providers/desk_break_providers.dart';
import '../../services/reminder_prefs.dart';
import '../../services/reminder_scheduler.dart';
import '../screen_scaffold.dart';

/// Eye, movement, knee-mobility, and neck-exercise break reminders on
/// configurable intervals (health-plan-source.md §4). Reminder on/off,
/// interval and active-window settings live here rather than in Settings
/// — see requirements/2026-08-29-ux-and-notification-improvements.md §5.
class DeskBreaksScreen extends StatelessWidget {
  const DeskBreaksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Desk Breaks',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _AdherenceCard(),
          SizedBox(height: 16),
          _DeskBreaksReminderCard(),
        ],
      ),
    );
  }
}

class _AdherenceCard extends ConsumerWidget {
  const _AdherenceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(deskBreakAdherenceProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last 7 days', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'How often each break notification was answered — a missed '
              'notification is counted as "not done" a few minutes after it fires.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load adherence: $e'),
              data: (summary) => Column(
                children: [
                  for (final type in DeskBreakType.values) _AdherenceRow(type: type, counts: summary[type]!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdherenceRow extends StatelessWidget {
  final DeskBreakType type;
  final Map<DeskBreakLogStatus, int> counts;

  const _AdherenceRow({required this.type, required this.counts});

  @override
  Widget build(BuildContext context) {
    final done = counts[DeskBreakLogStatus.done] ?? 0;
    final skipped = counts[DeskBreakLogStatus.skipped] ?? 0;
    final missed = counts[DeskBreakLogStatus.autoMissed] ?? 0;
    final total = done + skipped + missed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(type.label)),
          Text(
            total == 0 ? 'No data yet' : '$done done · ${skipped + missed} missed',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _formatMinutes(int minutesSinceMidnight) {
  final time = TimeOfDay(hour: minutesSinceMidnight ~/ 60, minute: minutesSinceMidnight % 60);
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}

Future<int?> _pickTime(BuildContext context, int currentMinutes) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: currentMinutes ~/ 60, minute: currentMinutes % 60),
  );
  return picked == null ? null : picked.hour * 60 + picked.minute;
}

class _TimeRangeRow extends StatelessWidget {
  final String fromLabel;
  final String toLabel;
  final VoidCallback onTapFrom;
  final VoidCallback onTapTo;

  const _TimeRangeRow({
    required this.fromLabel,
    required this.toLabel,
    required this.onTapFrom,
    required this.onTapTo,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(onPressed: onTapFrom, child: Text(fromLabel)),
        OutlinedButton(onPressed: onTapTo, child: Text(toLabel)),
      ],
    );
  }
}

class _DeskBreaksReminderCard extends StatefulWidget {
  const _DeskBreaksReminderCard();

  @override
  State<_DeskBreaksReminderCard> createState() => _DeskBreaksReminderCardState();
}

class _DeskBreaksReminderCardState extends State<_DeskBreaksReminderCard> {
  int _fromMinutes = ReminderPrefs.defaultDeskFromMinutes;
  int _toMinutes = ReminderPrefs.defaultDeskToMinutes;
  final Map<DeskBreakType, bool> _enabled = {};
  final Map<DeskBreakType, int> _intervals = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final from = await ReminderPrefs.deskFromMinutes();
    final to = await ReminderPrefs.deskToMinutes();
    for (final type in DeskBreakType.values) {
      _enabled[type] = await ReminderPrefs.deskBreakEnabled(type);
      _intervals[type] = await ReminderPrefs.deskBreakIntervalMinutes(type);
    }
    if (!mounted) return;
    setState(() {
      _fromMinutes = from;
      _toMinutes = to;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reminders', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Eye, movement, knee mobility, and neck-exercise reminders during '
              'your active hours.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _TimeRangeRow(
              fromLabel: 'Active from ${_formatMinutes(_fromMinutes)}',
              toLabel: 'to ${_formatMinutes(_toMinutes)}',
              onTapFrom: () async {
                final picked = await _pickTime(context, _fromMinutes);
                if (picked == null) return;
                setState(() => _fromMinutes = picked);
                await ReminderPrefs.setDeskFromMinutes(picked);
                await ReminderScheduler.instance.rescheduleAllDeskBreaks();
              },
              onTapTo: () async {
                final picked = await _pickTime(context, _toMinutes);
                if (picked == null) return;
                setState(() => _toMinutes = picked);
                await ReminderPrefs.setDeskToMinutes(picked);
                await ReminderScheduler.instance.rescheduleAllDeskBreaks();
              },
            ),
            const Divider(height: 24),
            for (final type in DeskBreakType.values) _deskBreakRow(type),
          ],
        ),
      ),
    );
  }

  Widget _deskBreakRow(DeskBreakType type) {
    final enabled = _enabled[type] ?? true;
    final interval = _intervals[type] ?? type.defaultIntervalMinutes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(type.label)),
              Switch(
                value: enabled,
                onChanged: (v) async {
                  setState(() => _enabled[type] = v);
                  await ReminderPrefs.setDeskBreakEnabled(type, v);
                  await ReminderScheduler.instance.rescheduleDeskBreak(type);
                },
              ),
            ],
          ),
          if (enabled) ...[
            Text('Every $interval minutes', style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: interval.toDouble(),
              min: 15,
              max: 180,
              divisions: 11,
              label: '$interval min',
              onChanged: (v) => setState(() => _intervals[type] = v.round()),
              onChangeEnd: (v) async {
                await ReminderPrefs.setDeskBreakIntervalMinutes(type, v.round());
                await ReminderScheduler.instance.rescheduleDeskBreak(type);
              },
            ),
          ],
        ],
      ),
    );
  }
}
