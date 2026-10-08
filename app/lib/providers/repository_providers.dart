import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../data/repositories/backup_repository.dart';
import '../data/repositories/desk_break_log_repository.dart';
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

/// Increment after a whole-database restore to refresh every dependent query.
final databaseRevisionProvider = StateProvider<int>((ref) => 0);

Database _currentDatabase(Ref ref) {
  ref.watch(databaseRevisionProvider);
  return ref.watch(databaseProvider);
}

final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) => WeightRepository(_currentDatabase(ref)),
);

final waterRepositoryProvider = Provider<WaterRepository>(
  (ref) => WaterRepository(_currentDatabase(ref)),
);

final dhyanaRepositoryProvider = Provider<DhyanaRepository>(
  (ref) => DhyanaRepository(_currentDatabase(ref)),
);

final painRepositoryProvider = Provider<PainRepository>(
  (ref) => PainRepository(_currentDatabase(ref)),
);

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(_currentDatabase(ref)),
);

final mealRepositoryProvider = Provider<MealRepository>(
  (ref) => MealRepository(_currentDatabase(ref)),
);

final routineConfigRepositoryProvider = Provider<RoutineConfigRepository>(
  (ref) => RoutineConfigRepository(_currentDatabase(ref)),
);

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepository(_currentDatabase(ref)),
);

final deskBreakLogRepositoryProvider = Provider<DeskBreakLogRepository>(
  (ref) => DeskBreakLogRepository(_currentDatabase(ref)),
);

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(_currentDatabase(ref)),
);

/// Bootstraps the default UserProfile/RoutineConfig and exercise library
/// on first launch. Screens that need the profile should watch this.
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  await ref.watch(exerciseRepositoryProvider).seedDefinitionsIfEmpty();
  return ref.watch(userProfileRepositoryProvider).bootstrapIfMissing();
});
