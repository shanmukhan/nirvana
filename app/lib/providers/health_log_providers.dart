import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities.dart';
import 'calendar_providers.dart';
import 'repository_providers.dart';

final weightRefreshProvider = StateProvider<int>((ref) => 0);

final recentWeightEntriesProvider = FutureProvider.autoDispose<List<WeightEntry>>((ref) async {
  ref.watch(weightRefreshProvider);
  return ref.watch(weightRepositoryProvider).recent(limit: 14);
});

final sevenDayAverageProvider = FutureProvider.autoDispose<double?>((ref) async {
  ref.watch(weightRefreshProvider);
  ref.watch(currentDayProvider);
  return ref.watch(weightRepositoryProvider).sevenDayAverageKg();
});

final kneeRefreshProvider = StateProvider<int>((ref) => 0);

final recentPainEntriesProvider = FutureProvider.autoDispose<List<PainEntry>>((ref) async {
  ref.watch(kneeRefreshProvider);
  return ref.watch(painRepositoryProvider).recent(limit: 14);
});

final exerciseRefreshProvider = StateProvider<int>((ref) => 0);

final exerciseDefinitionsProvider = FutureProvider.autoDispose<List<ExerciseDefinition>>((
  ref,
) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  await ref.watch(userProfileProvider.future);
  return repository.allDefinitions();
});

final exerciseSessionsTodayProvider = FutureProvider.autoDispose<List<ExerciseSession>>((ref) {
  ref.watch(exerciseRefreshProvider);
  return ref.watch(exerciseRepositoryProvider).forDay(ref.watch(currentDayProvider));
});

final foodRefreshProvider = StateProvider<int>((ref) => 0);

final mealEntriesTodayProvider = FutureProvider.autoDispose<List<MealEntry>>((ref) {
  ref.watch(foodRefreshProvider);
  return ref.watch(mealRepositoryProvider).forDay(ref.watch(currentDayProvider));
});
