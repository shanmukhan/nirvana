import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/routine_config.dart';
import 'repository_providers.dart';

/// Today's total water intake in ml. Bump [refreshTrigger] after a quick
/// log to make this re-fetch.
final waterTodayTotalProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(waterRefreshProvider);
  return ref.watch(waterRepositoryProvider).totalMlForDay(DateTime.now());
});

/// Simple invalidation counter: incrementing it invalidates
/// [waterTodayTotalProvider] so the UI reflects a fresh quick-log.
final waterRefreshProvider = StateProvider<int>((ref) => 0);

/// Bump after saving a hydration-goal edit in Settings to invalidate
/// [hydrationConfigProvider].
final hydrationConfigRefreshProvider = StateProvider<int>((ref) => 0);

/// The live, user-editable HydrationConfig — daily goal + quick-log
/// amounts — persisted via RoutineConfigRepository (see
/// app/lib/screens/settings/settings_screen.dart's "Hydration goal"
/// card). Falls back to HydrationConfig's in-code defaults (2250ml) until
/// the user changes it. Every screen that needs the hydration goal reads
/// this instead of a hardcoded constant.
final hydrationConfigProvider = FutureProvider.autoDispose<HydrationConfig>((ref) async {
  ref.watch(hydrationConfigRefreshProvider);
  final profile = await ref.watch(userProfileProvider.future);
  return ref.watch(routineConfigRepositoryProvider).hydrationConfig(profile.routineConfigId);
});

const int hydrationChartDays = 7;

/// Per-day totals for the last [hydrationChartDays] days (oldest first),
/// for the weekly consistency chart on the Water screen.
final weeklyWaterTotalsProvider = FutureProvider.autoDispose<List<MapEntry<DateTime, int>>>((
  ref,
) {
  ref.watch(waterRefreshProvider);
  return ref.watch(waterRepositoryProvider).dailyTotalsForLastDays(hydrationChartDays);
});

/// Current consistency streak: consecutive days (ending today, or ending
/// yesterday if today isn't over the goal *yet*) that hit the daily
/// hydration goal. Deliberately doesn't penalize an in-progress today —
/// non-shaming, per PROJECT_PLAN.md §1.
final waterStreakProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(waterRefreshProvider);
  final totals = await ref.watch(waterRepositoryProvider).dailyTotalsForLastDays(30);
  final goal = (await ref.watch(hydrationConfigProvider.future)).dailyGoalMl;
  final byDayDesc = totals.reversed.toList();

  var streak = 0;
  var start = 0;
  // Today not having hit goal yet doesn't break a streak that's still
  // "in progress" — just don't count today itself until it clears the bar.
  if (byDayDesc.isNotEmpty && byDayDesc.first.value < goal) {
    start = 1;
  }
  for (var i = start; i < byDayDesc.length; i++) {
    if (byDayDesc[i].value >= goal) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
});
