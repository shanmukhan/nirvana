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

final dhyanaStreakProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(dhyanaRefreshProvider);
  return ref.watch(dhyanaRepositoryProvider).currentStreakDays();
});
