import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../data/repositories/dhyana_repository.dart';
import '../data/repositories/exercise_repository.dart';
import '../data/repositories/meal_repository.dart';
import '../data/repositories/pain_repository.dart';
import '../data/repositories/routine_config_repository.dart';
import '../data/repositories/user_profile_repository.dart';
import '../data/repositories/water_repository.dart';
import '../data/repositories/weight_repository.dart';
import '../domain/entities.dart';

/// The open sqflite [Database]. main.dart overrides this with the real
/// instance before the widget tree is built, so every other provider can
/// depend on it synchronously.
final databaseProvider = Provider<Database>((ref) {
  throw UnimplementedError('databaseProvider must be overridden in main()');
});

final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) => WeightRepository(ref.watch(databaseProvider)),
);

final waterRepositoryProvider = Provider<WaterRepository>(
  (ref) => WaterRepository(ref.watch(databaseProvider)),
);

final dhyanaRepositoryProvider = Provider<DhyanaRepository>(
  (ref) => DhyanaRepository(ref.watch(databaseProvider)),
);

final painRepositoryProvider = Provider<PainRepository>(
  (ref) => PainRepository(ref.watch(databaseProvider)),
);

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);

final mealRepositoryProvider = Provider<MealRepository>(
  (ref) => MealRepository(ref.watch(databaseProvider)),
);

final routineConfigRepositoryProvider = Provider<RoutineConfigRepository>(
  (ref) => RoutineConfigRepository(ref.watch(databaseProvider)),
);

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepository(ref.watch(databaseProvider)),
);

/// Bootstraps the default UserProfile/RoutineConfig and exercise library
/// on first launch. Screens that need the profile should watch this.
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  await ref.watch(exerciseRepositoryProvider).seedDefinitionsIfEmpty();
  return ref.watch(userProfileRepositoryProvider).bootstrapIfMissing();
});
