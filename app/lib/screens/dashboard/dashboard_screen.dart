import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/meal_templates.dart';
import '../../providers/dhyana_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/water_providers.dart';
import '../exercise/exercise_screen.dart' show exerciseDefinitionsProvider, exerciseSessionsTodayProvider;
import '../food/food_screen.dart' show mealEntriesTodayProvider;
import '../screen_scaffold.dart';
import '../weight/weight_screen.dart' show sevenDayAverageProvider, recentWeightEntriesProvider;

/// Today/Dashboard — live cards for Weight, Water, Knee, Dhyana, Exercise,
/// Nutrition today. Movement/Desk-health cards land as those screens go
/// live in the rest of Phase 2/3. See health-plan-source.md §18.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenScaffold(
      title: 'Dashboard',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _WeightCard(onTap: () => context.go('/weight')),
          const SizedBox(height: 12),
          _WaterCard(onTap: () => context.go('/water')),
          const SizedBox(height: 12),
          _KneeCard(onTap: () => context.go('/knee')),
          const SizedBox(height: 12),
          _DhyanaCard(onTap: () => context.go('/dhyana')),
          const SizedBox(height: 12),
          _ExerciseCard(onTap: () => context.go('/exercise')),
          const SizedBox(height: 12),
          _NutritionCard(onTap: () => context.go('/food')),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightCard extends ConsumerWidget {
  final VoidCallback onTap;

  const _WeightCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avg = ref.watch(sevenDayAverageProvider);
    final entries = ref.watch(recentWeightEntriesProvider);
    return _DashboardCard(
      title: 'Weight',
      icon: Icons.monitor_weight_outlined,
      onTap: onTap,
      child: avg.when(
        loading: () => const Text('Loading…'),
        error: (e, _) => const Text('—'),
        data: (avgKg) {
          final current = entries.asData?.value.firstOrNull;
          return Text(
            current == null
                ? 'No entries yet — tap to log your weight.'
                : 'Current: ${current.weightKg.toStringAsFixed(1)} kg'
                      '${avgKg != null ? '  ·  7-day avg: ${avgKg.toStringAsFixed(1)} kg' : ''}',
          );
        },
      ),
    );
  }
}

class _WaterCard extends ConsumerWidget {
  final VoidCallback onTap;

  const _WaterCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(waterTodayTotalProvider);
    final hydrationConfig = ref.watch(hydrationConfigProvider);
    return _DashboardCard(
      title: 'Water',
      icon: Icons.water_drop_outlined,
      onTap: onTap,
      child: total.when(
        loading: () => const Text('Loading…'),
        error: (e, _) => const Text('—'),
        data: (ml) => Text('$ml ml of ${hydrationConfig.asData?.value.dailyGoalMl ?? 2250} ml goal'),
      ),
    );
  }
}

class _KneeCard extends ConsumerWidget {
  final VoidCallback onTap;

  const _KneeCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(_latestPainProvider);
    return _DashboardCard(
      title: 'Knee',
      icon: Icons.accessibility_new_outlined,
      onTap: onTap,
      child: latestAsync.when(
        loading: () => const Text('Loading…'),
        error: (e, _) => const Text('—'),
        data: (entry) => Text(
          entry == null
              ? 'No entries yet — tap to log how your knee feels.'
              : 'Pain: ${entry.painBefore0to10}/10'
                    '  ·  Swelling: ${entry.swelling ? 'yes' : 'no'}'
                    '  ·  Stiffness: ${entry.stiffness0to10}/10',
        ),
      ),
    );
  }
}

final _latestPainProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(painRepositoryProvider).latest();
});

class _DhyanaCard extends ConsumerWidget {
  final VoidCallback onTap;

  const _DhyanaCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsToday = ref.watch(dhyanaSessionsTodayProvider);
    final streak = ref.watch(dhyanaStreakProvider);
    return _DashboardCard(
      title: 'Dhyana',
      icon: Icons.self_improvement_outlined,
      onTap: onTap,
      child: sessionsToday.when(
        loading: () => const Text('Loading…'),
        error: (e, _) => const Text('—'),
        data: (sessions) {
          final streakText = streak.asData?.value;
          return Text(
            'Sessions today: ${sessions.length}'
            '${streakText != null && streakText > 0 ? '  ·  Streak: $streakText days' : ''}',
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  final VoidCallback onTap;

  const _ExerciseCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definitionsAsync = ref.watch(exerciseDefinitionsProvider);
    final sessionsAsync = ref.watch(exerciseSessionsTodayProvider);
    return _DashboardCard(
      title: 'Exercise',
      icon: Icons.fitness_center_outlined,
      onTap: onTap,
      child: definitionsAsync.when(
        loading: () => const Text('Loading…'),
        error: (e, _) => const Text('—'),
        data: (definitions) {
          final sessionsToday = sessionsAsync.asData?.value ?? const [];
          final done = sessionsToday.map((s) => s.exerciseDefinitionId).toSet().length;
          return Text('$done of ${definitions.length} exercises logged today');
        },
      ),
    );
  }
}

class _NutritionCard extends ConsumerWidget {
  final VoidCallback onTap;

  const _NutritionCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(mealEntriesTodayProvider);
    return _DashboardCard(
      title: 'Nutrition',
      icon: Icons.restaurant_outlined,
      onTap: onTap,
      child: entriesAsync.when(
        loading: () => const Text('Loading…'),
        error: (e, _) => const Text('—'),
        data: (entries) {
          final protein = entries.fold<double>(0, (sum, e) => sum + (e.proteinEstimateG ?? 0));
          return Text(
            '${entries.length} meals logged  ·  '
            '~${protein.toStringAsFixed(0)} g protein '
            '(target ${dailyProteinTargetMinG.toStringAsFixed(0)}-'
            '${dailyProteinTargetMaxG.toStringAsFixed(0)} g)',
          );
        },
      ),
    );
  }
}
