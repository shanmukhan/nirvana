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

const HydrationConfig defaultHydrationConfig = HydrationConfig();
