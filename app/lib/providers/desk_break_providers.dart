import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/desk_break_log_repository.dart';
import '../services/reminder_prefs.dart';
import '../services/reminder_scheduler.dart';
import 'repository_providers.dart';

/// Bump after recording a response on the desk-break-log screen to
/// invalidate [deskBreakAdherenceProvider].
final deskBreakLogRefreshProvider = StateProvider<int>((ref) => 0);

/// Runs the lazy auto-miss sweep (see [DeskBreakLogRepository]) and then
/// returns today's adherence summary for the last 7 days. Watched by the
/// Desk Breaks screen.
final deskBreakAdherenceProvider =
    FutureProvider.autoDispose<Map<DeskBreakType, Map<DeskBreakLogStatus, int>>>((ref) async {
      ref.watch(deskBreakLogRefreshProvider);
      final slots = await ReminderScheduler.instance.todaysDeskBreakSlots();
      final repo = ref.watch(deskBreakLogRepositoryProvider);
      await repo.sweepAutoMissed(slots);
      return repo.adherenceSummary(7);
    });
