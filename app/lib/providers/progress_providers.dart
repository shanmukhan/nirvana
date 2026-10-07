import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/desk_break_log_repository.dart' show DeskBreakLogStatus;
import '../domain/entities.dart';
import '../domain/meal_templates.dart' show MealTypeLabel;
import '../screens/exercise/exercise_screen.dart'
    show exerciseDefinitionsProvider, exerciseRefreshProvider;
import '../screens/food/food_screen.dart' show foodRefreshProvider;
import '../screens/knee/knee_screen.dart' show kneeRefreshProvider;
import '../screens/weight/weight_screen.dart' show weightRefreshProvider;
import 'desk_break_providers.dart' show deskBreakLogRefreshProvider;
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

enum TodayActivityKind { water, meal, exercise, dhyana, weight, knee, deskBreak }

/// One logged thing that happened today, for the Progress screen's
/// "Today's progress" timeline.
class TodayActivityEntry {
  final DateTime time;
  final TodayActivityKind kind;
  final String title;
  final String? subtitle;

  const TodayActivityEntry({
    required this.time,
    required this.kind,
    required this.title,
    this.subtitle,
  });
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Everything logged on [day] (water, meals, exercise, dhyana, weight,
/// knee), newest first — see health-plan-source.md §18. Distinct from
/// [adherenceProvider] (yes/no per habit per day): this is the actual
/// chronological log of what happened that day, with times. Used both for
/// "Today's progress" (day: today) and the per-date drilldown reached by
/// tapping a day in the adherence grid.
final dayActivityProvider = FutureProvider.autoDispose
    .family<List<TodayActivityEntry>, DateTime>((ref, day) async {
  ref.watch(waterRefreshProvider);
  ref.watch(foodRefreshProvider);
  ref.watch(exerciseRefreshProvider);
  ref.watch(dhyanaRefreshProvider);
  ref.watch(weightRefreshProvider);
  ref.watch(kneeRefreshProvider);
  ref.watch(deskBreakLogRefreshProvider);

  final water = await ref.watch(waterRepositoryProvider).forDay(day);
  final meals = await ref.watch(mealRepositoryProvider).forDay(day);
  final exerciseSessions = await ref.watch(exerciseRepositoryProvider).forDay(day);
  final exerciseDefinitions = await ref.watch(exerciseDefinitionsProvider.future);
  final dhyanaSessions = await ref.watch(dhyanaRepositoryProvider).forDay(day);
  final weightEntries = (await ref.watch(weightRepositoryProvider).recent(limit: 10))
      .where((e) => _isSameDay(e.takenAt, day));
  final painEntries = (await ref.watch(painRepositoryProvider).recent(limit: 10))
      .where((e) => _isSameDay(e.recordedAt, day));
  final deskBreaks = (await ref.watch(deskBreakLogRepositoryProvider).forDay(day))
      .where((e) => e.status == DeskBreakLogStatus.done);

  final exerciseNames = {for (final d in exerciseDefinitions) d.id: d.name};

  final entries = <TodayActivityEntry>[
    for (final w in water)
      TodayActivityEntry(
        time: w.loggedAt,
        kind: TodayActivityKind.water,
        title: 'Water',
        subtitle: '${w.amountMl} ml',
      ),
    for (final m in meals)
      TodayActivityEntry(
        time: m.loggedAt,
        kind: TodayActivityKind.meal,
        title: m.mealType.label,
        subtitle: m.description,
      ),
    for (final s in exerciseSessions)
      TodayActivityEntry(
        time: s.performedAt,
        kind: TodayActivityKind.exercise,
        title: exerciseNames[s.exerciseDefinitionId] ?? 'Exercise',
        subtitle: '${s.completedSets} × ${s.completedReps}'
            '${s.painRating0to10 != null ? '  ·  pain ${s.painRating0to10}/10' : ''}',
      ),
    for (final d in dhyanaSessions)
      TodayActivityEntry(
        time: d.date,
        kind: TodayActivityKind.dhyana,
        title: 'Dhyana',
        subtitle: '${d.actualDurationMin} min',
      ),
    for (final w in weightEntries)
      TodayActivityEntry(
        time: w.takenAt,
        kind: TodayActivityKind.weight,
        title: 'Weight',
        subtitle: '${w.weightKg.toStringAsFixed(1)} kg',
      ),
    for (final p in painEntries)
      TodayActivityEntry(
        time: p.recordedAt,
        kind: TodayActivityKind.knee,
        title: 'Knee check-in',
        subtitle: 'Pain ${p.painBefore0to10}/10',
      ),
    for (final d in deskBreaks)
      TodayActivityEntry(
        time: d.respondedAt ?? d.firedAt,
        kind: TodayActivityKind.deskBreak,
        title: d.type.label,
        subtitle: 'Done',
      ),
  ];
  entries.sort((a, b) => b.time.compareTo(a.time));
  return entries;
});
