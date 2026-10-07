import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities.dart';
import 'repository_providers.dart';

final dhyanaRefreshProvider = StateProvider<int>((ref) => 0);

final dhyanaSessionsTodayProvider = FutureProvider.autoDispose<List<DhyanaSession>>((
  ref,
) async {
  ref.watch(dhyanaRefreshProvider);
  return ref.watch(dhyanaRepositoryProvider).forDay(DateTime.now());
});

/// Date currently selected in the sessions log, defaulting to today.
final dhyanaSelectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final dhyanaSessionsForSelectedDateProvider =
    FutureProvider.autoDispose<List<DhyanaSession>>((ref) async {
      ref.watch(dhyanaRefreshProvider);
      final date = ref.watch(dhyanaSelectedDateProvider);
      return ref.watch(dhyanaRepositoryProvider).forDay(date);
    });

/// Total minutes sat over the last 7 days (today inclusive) — a trend
/// number to sit next to the streak, since streak alone hides "shorter but
/// more consistent" weeks.
final dhyanaWeekMinutesProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(dhyanaRefreshProvider);
  final sessions = await ref.watch(dhyanaRepositoryProvider).recent(limit: 200);
  final cutoff = DateTime.now().subtract(const Duration(days: 7));
  return sessions
      .where((s) => s.date.isAfter(cutoff))
      .fold<int>(0, (sum, s) => sum + s.actualDurationMin);
});

final dhyanaStreakProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(dhyanaRefreshProvider);
  return ref.watch(dhyanaRepositoryProvider).currentStreakDays();
});
