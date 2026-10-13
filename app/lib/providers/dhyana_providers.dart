import 'calendar_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities.dart';
import 'repository_providers.dart';

final dhyanaRefreshProvider = StateProvider<int>((ref) => 0);

final dhyanaSessionsTodayProvider = FutureProvider.autoDispose<List<DhyanaSession>>((ref) async {
  ref.watch(dhyanaRefreshProvider);
  return ref.watch(dhyanaRepositoryProvider).forDay(ref.watch(currentDayProvider));
});

/// Date currently selected in the sessions log, defaulting to today.
final dhyanaSelectedDateProvider = StateProvider<DateTime?>((ref) => null);
final dhyanaEffectiveDateProvider = Provider<DateTime>(
  (ref) => ref.watch(dhyanaSelectedDateProvider) ?? ref.watch(currentDayProvider),
);

final dhyanaSessionsForSelectedDateProvider = FutureProvider.autoDispose<List<DhyanaSession>>((
  ref,
) async {
  ref.watch(dhyanaRefreshProvider);
  final date = ref.watch(dhyanaEffectiveDateProvider);
  return ref.watch(dhyanaRepositoryProvider).forDay(date);
});

/// Total minutes sat over the last 7 days (today inclusive) — a trend
/// number to sit next to the streak, since streak alone hides "shorter but
/// more consistent" weeks.
final dhyanaWeekMinutesProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(dhyanaRefreshProvider);
  return ref
      .watch(dhyanaRepositoryProvider)
      .totalMinutesForLastDays(7, now: ref.watch(currentDayProvider));
});

final dhyanaStreakProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(dhyanaRefreshProvider);
  ref.watch(currentDayProvider);
  return ref.watch(dhyanaRepositoryProvider).currentStreakDays();
});
