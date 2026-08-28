import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities.dart';
import '../screens/knee/knee_screen.dart' show kneeRefreshProvider;
import '../screens/weight/weight_screen.dart' show weightRefreshProvider;
import 'dhyana_providers.dart';
import 'repository_providers.dart';
import 'water_providers.dart';

/// Weight entries over the last 90 days, oldest first — for the Progress
/// screen's trend chart. See health-plan-source.md §16/§17.
final weightTrendProvider = FutureProvider.autoDispose<List<WeightEntry>>((ref) async {
  ref.watch(weightRefreshProvider);
  final entries = await ref.watch(weightRepositoryProvider).recent(limit: 90);
  return entries.reversed.toList();
});

/// "Pain before" ratings over the last 90 days, oldest first.
final painTrendProvider = FutureProvider.autoDispose<List<PainEntry>>((ref) async {
  ref.watch(kneeRefreshProvider);
  final entries = await ref.watch(painRepositoryProvider).recent(limit: 90);
  return entries.reversed.toList();
});

const int adherenceDays = 7;

enum AdherenceHabit { water, dhyana, exercise, meals }

extension AdherenceHabitLabel on AdherenceHabit {
  String get label => switch (this) {
    AdherenceHabit.water => 'Water',
    AdherenceHabit.dhyana => 'Dhyana',
    AdherenceHabit.exercise => 'Exercise',
    AdherenceHabit.meals => 'Meals',
  };
}

/// One day's yes/no per habit, for the adherence grid. Non-shaming by
/// construction — a "no" day is just an unfilled dot, no red/warning
/// styling anywhere in the UI that renders this (see PROJECT_PLAN.md §1).
class DayAdherence {
  final DateTime day;
  final Map<AdherenceHabit, bool> done;

  const DayAdherence({required this.day, required this.done});
}

/// Last [adherenceDays] days (oldest first) of habit completion, across
/// water (goal met), dhyana (session logged), exercise (session logged),
/// and meals (at least one logged).
final adherenceProvider = FutureProvider.autoDispose<List<DayAdherence>>((ref) async {
  ref.watch(waterRefreshProvider);
  ref.watch(dhyanaRefreshProvider);

  final waterRepo = ref.watch(waterRepositoryProvider);
  final dhyanaRepo = ref.watch(dhyanaRepositoryProvider);
  final exerciseRepo = ref.watch(exerciseRepositoryProvider);
  final mealRepo = ref.watch(mealRepositoryProvider);

  final waterTotals = await waterRepo.dailyTotalsForLastDays(adherenceDays);
  final goal = (await ref.watch(hydrationConfigProvider.future)).dailyGoalMl;

  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final days = [
    for (var i = adherenceDays - 1; i >= 0; i--) todayStart.subtract(Duration(days: i)),
  ];

  final result = <DayAdherence>[];
  for (var i = 0; i < days.length; i++) {
    final day = days[i];
    final dhyanaDone = (await dhyanaRepo.forDay(day)).isNotEmpty;
    final exerciseDone = (await exerciseRepo.forDay(day)).isNotEmpty;
    final mealsDone = (await mealRepo.forDay(day)).isNotEmpty;
    result.add(
      DayAdherence(
        day: day,
        done: {
          AdherenceHabit.water: waterTotals[i].value >= goal,
          AdherenceHabit.dhyana: dhyanaDone,
          AdherenceHabit.exercise: exerciseDone,
          AdherenceHabit.meals: mealsDone,
        },
      ),
    );
  }
  return result;
});
