import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/reminder_plan.dart';
import '../services/reminder_prefs.dart';
import '../services/reminder_scheduler.dart';

/// Shows the same capped, quiet-hours-filtered plan that the scheduler uses.
class ReminderCoverage extends StatefulWidget {
  final int fromMinutes;
  final int toMinutes;
  final int intervalMinutes;
  const ReminderCoverage({
    super.key,
    required this.fromMinutes,
    required this.toMinutes,
    required this.intervalMinutes,
  });

  @override
  State<ReminderCoverage> createState() => _ReminderCoverageState();
}

class _ReminderCoverageState extends State<ReminderCoverage> {
  late Future<QuietHoursWindow> _quietHours;

  @override
  void initState() {
    super.initState();
    _quietHours = QuietHoursWindow.load();
    ReminderPrefs.quietHoursRevision.addListener(_reloadQuietHours);
  }

  void _reloadQuietHours() {
    final future = QuietHoursWindow.load();
    setState(() {
      _quietHours = future;
    });
  }

  @override
  void dispose() {
    ReminderPrefs.quietHoursRevision.removeListener(_reloadQuietHours);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<QuietHoursWindow>(
    future: _quietHours,
    builder: (context, snapshot) {
      final quiet = snapshot.data;
      if (quiet == null) return const SizedBox.shrink();
      final plan = planReminderSlots(
        fromMinutes: widget.fromMinutes,
        toMinutes: widget.toMinutes,
        intervalMinutes: widget.intervalMinutes,
        isQuiet: quiet.contains,
      );
      String message;
      if (plan.issue != null) {
        message = '${plan.issue} No reminders are scheduled.';
      } else if (plan.slots.isEmpty) {
        message = 'No reminders are scheduled in this window after quiet hours.';
      } else {
        final (hour, minute) = plan.slots.last;
        final time = DateFormat.jm().format(DateTime(2000, 1, 1, hour, minute));
        message =
            '${plan.slots.length} reminder${plan.slots.length == 1 ? '' : 's'} per day; last at $time.';
        if (plan.truncated) {
          message += ' Increase the interval or shorten active hours to cover the whole window.';
        }
      }
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      );
    },
  );
}
