import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/data/repositories/backup_repository.dart';
import 'package:nirvana/data/repositories/desk_break_log_repository.dart';
import 'package:nirvana/data/repositories/dhyana_repository.dart';
import 'package:nirvana/data/repositories/exercise_repository.dart';
import 'package:nirvana/data/repositories/meal_repository.dart';
import 'package:nirvana/data/repositories/pain_repository.dart';
import 'package:nirvana/data/repositories/water_repository.dart';
import 'package:nirvana/data/repositories/weight_repository.dart';
import 'package:nirvana/domain/calendar_days.dart';
import 'package:nirvana/domain/entities.dart';
import 'package:nirvana/domain/routine_config.dart';
import 'package:nirvana/providers/progress_providers.dart';
import 'package:nirvana/providers/repository_providers.dart';
import 'package:nirvana/providers/water_providers.dart';
import 'package:nirvana/screens/exercise/exercise_screen.dart';
import 'package:nirvana/screens/food/food_screen.dart';
import 'package:nirvana/services/reminder_prefs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_database.dart';

void main() {
  late Database db;
  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  test('day history includes old entries outside the ten latest records', () async {
    final old = calendarDayOffset(DateTime.now(), -20);
    final weight = WeightRepository(db);
    final pain = PainRepository(db);
    await weight.add(weightKg: 72, takenAt: old);
    await pain.log(painBefore0to10: 2, recordedAt: old);
    for (var i = 0; i < 12; i++) {
      await weight.add(weightKg: 70, takenAt: DateTime.now());
      await pain.log(painBefore0to10: 1);
    }
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final history = await container.read(dayActivityProvider(old).future);
    expect(history.where((entry) => entry.kind == TodayActivityKind.weight).length, 1);
    expect(history.where((entry) => entry.kind == TodayActivityKind.knee).length, 1);
  });

  test('90 day trends use calendar boundaries and include every entry', () async {
    final today = DateTime(2026, 10, 7);
    final repo = WeightRepository(db);
    await repo.add(weightKg: 90, takenAt: calendarDayOffset(today, -90));
    await repo.add(weightKg: 80, takenAt: calendarDayOffset(today, -89));
    for (var i = 0; i < 100; i++) {
      await repo.add(weightKg: 70, takenAt: today.add(Duration(minutes: i)));
    }
    await repo.add(weightKg: 60, takenAt: calendarDayOffset(today, 1));
    final entries = await repo.lastDays(90, now: today);
    expect(entries.length, 101);
    expect(entries.first.weightKg, 80);
  });

  test('weekly totals fill missing days and exclude out-of-range data', () async {
    final today = DateTime(2026, 10, 7);
    final water = WaterRepository(db);
    await water.log(100, loggedAt: calendarDayOffset(today, -7));
    await water.log(200, loggedAt: calendarDayOffset(today, -6));
    await water.log(250, loggedAt: today);
    await water.log(150, loggedAt: today.add(const Duration(hours: 23)));
    await water.log(1000, loggedAt: calendarDayOffset(today, 1));
    final totals = await water.dailyTotalsForLastDays(7, now: today);
    expect(totals.map((entry) => entry.value), [200, 0, 0, 0, 0, 0, 400]);
    expect(await water.totalMlForDay(today), 400);
    expect(calendarDayOffset(DateTime(2024, 3, 1), -1), DateTime(2024, 2, 29));
  });

  test('adherence refreshes immediately after meal and exercise logging', () async {
    await ExerciseRepository(db).seedDefinitionsIfEmpty();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        hydrationConfigProvider.overrideWith((ref) async => const HydrationConfig()),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(adherenceProvider, (_, _) {});
    addTearDown(subscription.close);
    expect((await container.read(adherenceProvider.future)).last.done[AdherenceHabit.meals], false);
    await MealRepository(db).log(mealType: MealType.lunch, description: 'Lunch');
    container.read(foodRefreshProvider.notifier).state++;
    expect((await container.read(adherenceProvider.future)).last.done[AdherenceHabit.meals], true);
    await ExerciseRepository(
      db,
    ).logSession(exerciseDefinitionId: 'quad-set', completedSets: 1, completedReps: 10);
    container.read(exerciseRefreshProvider.notifier).state++;
    expect(
      (await container.read(adherenceProvider.future)).last.done[AdherenceHabit.exercise],
      true,
    );
  });

  test('restore invalidates cached totals and hydration settings', () async {
    await WaterRepository(db).log(250);
    final json = await BackupRepository(db).exportToJson();
    await WaterRepository(db).log(100);
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final subscription = container.listen(waterTodayTotalProvider, (_, _) {});
    addTearDown(subscription.close);
    expect(await container.read(waterTodayTotalProvider.future), 350);
    await BackupRepository(db).importFromJson(json);
    container.read(databaseRevisionProvider.notifier).state++;
    expect(await container.read(waterTodayTotalProvider.future), 250);
  });

  test('meditation totals do not truncate many short sessions', () async {
    final repo = DhyanaRepository(db);
    for (var i = 0; i < 205; i++) {
      await repo.logSession(
        plannedDurationMin: 2,
        actualDurationMin: 1,
        practiceType: DhyanaPractice.breathAwareness,
      );
    }
    expect(await repo.totalMinutesForLastDays(7), 205);
  });

  test('desk-break summary counts statuses and excludes future records', () async {
    final repo = DeskBreakLogRepository(db);
    await repo.recordResponse(
      type: DeskBreakType.eye,
      slotHour: 8,
      slotMinute: 30,
      status: DeskBreakLogStatus.done,
    );
    await repo.recordResponse(
      type: DeskBreakType.eye,
      slotHour: 9,
      slotMinute: 0,
      status: DeskBreakLogStatus.skipped,
    );
    await repo.recordResponse(
      type: DeskBreakType.eye,
      slotHour: 10,
      slotMinute: 0,
      status: DeskBreakLogStatus.done,
      logDate: calendarDayOffset(DateTime.now(), 1),
    );
    final summary = await repo.adherenceSummary(7);
    expect(summary[DeskBreakType.eye]![DeskBreakLogStatus.done], 1);
    expect(summary[DeskBreakType.eye]![DeskBreakLogStatus.skipped], 1);
    expect(summary[DeskBreakType.neck]!.values.every((count) => count == 0), true);
  });
}
