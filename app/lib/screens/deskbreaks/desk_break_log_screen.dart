import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/calendar_days.dart';

import '../../data/repositories/desk_break_log_repository.dart';
import '../../providers/desk_break_providers.dart';
import '../../providers/repository_providers.dart';
import '../../services/reminder_prefs.dart';
import '../screen_scaffold.dart';

/// Opened by tapping a desk-break notification (requirements §4): a
/// yes/no prompt for whether the break was actually taken, so adherence
/// can be tracked. See DeskBreakLogRepository for the lazy auto-miss
/// sweep that covers unanswered notifications.
class DeskBreakLogScreen extends ConsumerStatefulWidget {
  final DeskBreakType type;
  final int hour;
  final int minute;
  final DateTime? logDate;

  const DeskBreakLogScreen({
    super.key,
    required this.type,
    required this.hour,
    required this.minute,
    this.logDate,
  });

  @override
  ConsumerState<DeskBreakLogScreen> createState() => _DeskBreakLogScreenState();
}

class _DeskBreakLogScreenState extends ConsumerState<DeskBreakLogScreen> {
  DateTime? _day;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final day = widget.logDate == null ? null : startOfDay(widget.logDate!);
    _day = day != null && day.year >= 2020 && !day.isAfter(startOfDay(DateTime.now())) ? day : null;
  }

  Future<void> _pickDate() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _day ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (day != null && mounted) setState(() => _day = day);
  }

  Future<void> _respond(DeskBreakLogStatus status) async {
    if (_saving || _day == null) return;
    final repo = ref.read(deskBreakLogRepositoryProvider);
    final refresh = ref.read(deskBreakLogRefreshProvider.notifier);
    setState(() => _saving = true);
    try {
      await repo.recordResponse(
        type: widget.type,
        slotHour: widget.hour,
        slotMinute: widget.minute,
        status: status,
        logDate: _day!,
      );
      if (refresh.mounted) refresh.state++;
      if (!mounted) return;
      context.go('/desk-breaks');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this break. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: widget.type.label,
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.self_improvement_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('Did you do this break?', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  widget.type.label,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _day == null
                      ? 'Which date was this break?'
                      : '${DateFormat.yMMMd().format(_day!)} at ${TimeOfDay(hour: widget.hour, minute: widget.minute).format(context)}',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _day = startOfDay(DateTime.now())),
                      child: const Text('Today'),
                    ),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _day = calendarDayOffset(DateTime.now(), -1)),
                      child: const Text('Yesterday'),
                    ),
                    TextButton(
                      onPressed: _saving ? null : _pickDate,
                      child: const Text('Choose date'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _saving || _day == null
                          ? null
                          : () => _respond(DeskBreakLogStatus.skipped),
                      child: const Text('No'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: _saving || _day == null
                          ? null
                          : () => _respond(DeskBreakLogStatus.done),
                      child: const Text('Yes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
