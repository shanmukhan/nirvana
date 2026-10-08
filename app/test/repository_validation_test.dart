import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/data/repositories/meal_repository.dart';
import 'package:nirvana/data/repositories/pain_repository.dart';
import 'package:nirvana/data/repositories/routine_config_repository.dart';
import 'package:nirvana/data/repositories/water_repository.dart';
import 'package:nirvana/data/repositories/weight_repository.dart';
import 'package:nirvana/domain/entities.dart';
import 'package:nirvana/domain/routine_config.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_database.dart';

void main() {
  late Database db;
  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  test('invalid numbers never reach health logs', () async {
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      await expectLater(WeightRepository(db).add(weightKg: value), throwsArgumentError);
    }
    await expectLater(WaterRepository(db).log(0), throwsArgumentError);
    await expectLater(WaterRepository(db).log(-100), throwsArgumentError);
    for (final value in [-1.0, double.nan, double.infinity]) {
      await expectLater(
        MealRepository(
          db,
        ).log(mealType: MealType.lunch, description: 'Lunch', proteinEstimateG: value),
        throwsArgumentError,
      );
    }
    await expectLater(
      MealRepository(db).log(mealType: MealType.lunch, description: ' '),
      throwsArgumentError,
    );
    await expectLater(PainRepository(db).log(painBefore0to10: 11), throwsRangeError);
    for (final table in ['weight_entry', 'water_entry', 'meal_entry', 'pain_entry']) {
      expect(await db.query(table), isEmpty);
    }
    await MealRepository(
      db,
    ).log(mealType: MealType.lunch, description: ' Lunch ', proteinEstimateG: 0);
    expect((await MealRepository(db).forDay(DateTime.now())).single.description, 'Lunch');
  });

  test('invalid hydration configuration cannot be persisted', () async {
    await db.insert('routine_config', {'id': 'routine', 'config_json': '{}'});
    final repository = RoutineConfigRepository(db);
    await expectLater(
      repository.setHydrationConfig('routine', const HydrationConfig(dailyGoalMl: 0)),
      throwsFormatException,
    );
    expect((await repository.hydrationConfig('routine')).dailyGoalMl, 2250);
    await db.update('routine_config', {'config_json': '{"hydration":{"dailyGoalMl":0}}'});
    expect((await repository.hydrationConfig('routine')).dailyGoalMl, 2250);
    for (final map in [
      {'dailyGoalMl': '2500'},
      {'dailyGoalMl': 5000},
      {'quickLogAmountsMl': []},
      {
        'quickLogAmountsMl': [-1],
      },
      {
        'quickLogAmountsMl': ['250'],
      },
    ]) {
      expect(() => HydrationConfig.fromMap(map), throwsFormatException);
    }
  });
}
