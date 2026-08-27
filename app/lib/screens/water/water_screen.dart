import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../providers/water_providers.dart';
import '../screen_scaffold.dart';

/// Quick-log buttons, progress ring, reminders with snooze/skip.
/// See health-plan-source.md §3.
class WaterScreen extends ConsumerWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(waterTodayTotalProvider);
    final goalMl = defaultHydrationConfig.dailyGoalMl;

    return ScreenScaffold(
      title: 'Water',
      body: totalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load water log: $e')),
        data: (totalMl) => _WaterBody(totalMl: totalMl, goalMl: goalMl),
      ),
    );
  }
}

class _WaterBody extends ConsumerWidget {
  final int totalMl;
  final int goalMl;

  const _WaterBody({required this.totalMl, required this.goalMl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = goalMl == 0 ? 0.0 : (totalMl / goalMl).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 180,
                width: 180,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$totalMl ml', style: Theme.of(context).textTheme.headlineMedium),
                  Text('of $goalMl ml goal', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text('Quick log', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final amount in defaultHydrationConfig.quickLogAmountsMl)
              FilledButton.tonal(
                onPressed: () async {
                  await ref.read(waterRepositoryProvider).log(amount);
                  ref.read(waterRefreshProvider.notifier).state++;
                },
                child: Text('+$amount ml'),
              ),
          ],
        ),
      ],
    );
  }
}
