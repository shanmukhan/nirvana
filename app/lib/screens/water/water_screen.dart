import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    final hydrationConfigAsync = ref.watch(hydrationConfigProvider);

    return ScreenScaffold(
      title: 'Water',
      body: hydrationConfigAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load hydration goal: $e')),
        data: (hydrationConfig) => totalAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load water log: $e')),
          data: (totalMl) => _WaterBody(
            totalMl: totalMl,
            goalMl: hydrationConfig.dailyGoalMl,
            quickLogAmountsMl: hydrationConfig.quickLogAmountsMl,
          ),
        ),
      ),
    );
  }
}

class _WaterBody extends ConsumerWidget {
  final int totalMl;
  final int goalMl;
  final List<int> quickLogAmountsMl;

  const _WaterBody({
    required this.totalMl,
    required this.goalMl,
    required this.quickLogAmountsMl,
  });

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
            for (final amount in quickLogAmountsMl)
              FilledButton.tonal(
                onPressed: () async {
                  await ref.read(waterRepositoryProvider).log(amount);
                  ref.read(waterRefreshProvider.notifier).state++;
                },
                child: Text('+$amount ml'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const _CustomAmountRow(),
        const SizedBox(height: 32),
        const _WeeklyConsistencyCard(),
      ],
    );
  }
}

class _CustomAmountRow extends ConsumerStatefulWidget {
  const _CustomAmountRow();

  @override
  ConsumerState<_CustomAmountRow> createState() => _CustomAmountRowState();
}

class _CustomAmountRowState extends ConsumerState<_CustomAmountRow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _logCustomAmount() async {
    final amount = int.tryParse(_controller.text.trim());
    if (amount == null || amount <= 0) return;
    await ref.read(waterRepositoryProvider).log(amount);
    ref.read(waterRefreshProvider.notifier).state++;
    _controller.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Custom amount (ml)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _logCustomAmount(),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(onPressed: _logCustomAmount, child: const Text('Log')),
      ],
    );
  }
}

/// Non-shaming weekly view: a bar per day (capped visually at the goal,
/// no red/fail styling for a short day — every day just shows how full
/// it got) plus the current consistency streak. See PROJECT_PLAN.md §1
/// ("never guilt the user for a missed day").
class _WeeklyConsistencyCard extends ConsumerWidget {
  const _WeeklyConsistencyCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(weeklyWaterTotalsProvider);
    final streakAsync = ref.watch(waterStreakProvider);
    final hydrationConfigAsync = ref.watch(hydrationConfigProvider);
    final goal = hydrationConfigAsync.asData?.value.dailyGoalMl ?? 2250;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('This week', style: Theme.of(context).textTheme.titleMedium),
                ),
                streakAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (streak) => streak > 0
                      ? Chip(
                          avatar: const Icon(Icons.local_fire_department_outlined, size: 18),
                          label: Text('$streak day${streak == 1 ? '' : 's'}'),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            totalsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Text('—'),
              data: (totals) => SizedBox(
                height: 100,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final entry in totals)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _DayBar(day: entry.key, amountMl: entry.value, goalMl: goal),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final DateTime day;
  final int amountMl;
  final int goalMl;

  const _DayBar({required this.day, required this.amountMl, required this.goalMl});

  @override
  Widget build(BuildContext context) {
    final fraction = goalMl == 0 ? 0.0 : (amountMl / goalMl).clamp(0.0, 1.0);
    final isToday = DateUtils.isSameDay(day, DateTime.now());
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fraction == 0 ? 0.02 : fraction,
              child: Container(
                decoration: BoxDecoration(
                  color: isToday ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(DateFormat.E().format(day).substring(0, 1), style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
