import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/calendar_days.dart';

final calendarRevisionProvider = StateProvider<int>((ref) => 0);
final currentDayProvider = StateProvider<DateTime>((ref) {
  ref.watch(calendarRevisionProvider);
  return startOfDay(DateTime.now());
});

/// Calendar changes and foreground resumes invalidate date-dependent reads.
class CalendarRollover extends ConsumerStatefulWidget {
  final Widget child;
  const CalendarRollover({super.key, required this.child});
  @override
  ConsumerState<CalendarRollover> createState() => _CalendarRolloverState();
}

class _CalendarRolloverState extends ConsumerState<CalendarRollover> with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    _timer = Timer(calendarDayOffset(now, 1).difference(now), _refresh);
  }

  void _refresh() {
    if (!mounted) return;
    ref.read(calendarRevisionProvider.notifier).state++;
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
