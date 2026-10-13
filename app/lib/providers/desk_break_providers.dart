import 'dart:async';

import 'calendar_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/desk_break_log_repository.dart';
import '../services/reminder_prefs.dart';
import '../services/desk_break_schedule_history.dart';
import 'repository_providers.dart';

/// Bump after recording a response on the desk-break-log screen to
/// invalidate [deskBreakAdherenceProvider].
final deskBreakLogRefreshProvider = StateProvider<int>((ref) => 0);

final deskBreakScheduleRevisionProvider = StreamProvider<int>((ref) {
  final stream = StreamController<int>();
  void changed() => stream.add(DeskBreakScheduleHistory.revision.value);
  DeskBreakScheduleHistory.revision.addListener(changed);
  ref.onDispose(() {
    DeskBreakScheduleHistory.revision.removeListener(changed);
    unawaited(stream.close());
  });
  return stream.stream;
});

/// Reconciles historical scheduled occurrences with unknown delivery, then
/// returns the last seven days. Watched at app startup and by Desk Breaks.
final deskBreakAdherenceProvider =
    FutureProvider.autoDispose<Map<DeskBreakType, Map<DeskBreakLogStatus, int>>>((ref) async {
      ref.watch(deskBreakLogRefreshProvider);
      ref.watch(currentDayProvider);
      ref.watch(deskBreakScheduleRevisionProvider);
      final repo = ref.watch(deskBreakLogRepositoryProvider);
      await repo.sweepScheduledOccurrences(await DeskBreakScheduleHistory.load());
      return repo.adherenceSummary(7);
    });
