import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/progress_providers.dart';
import '../screen_scaffold.dart';

/// Today's activity, weight trend, pain trend, and 7-day adherence — see
/// health-plan-source.md §16/§17 and PROJECT_PLAN.md §1: judge progress
/// from trends, not single days, and never present a missed day as a
/// failure.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenScaffold(
      title: 'Progress / History',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todaysActivityProvider);
          ref.invalidate(weightTrendProvider);
          ref.invalidate(painTrendProvider);
          ref.invalidate(adherenceProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _TodayProgressCard(),
            SizedBox(height: 16),
            _TrendSummaryRow(),
            SizedBox(height: 16),
            _AdherenceCard(),
          ],
        ),
      ),
    );
  }
}

/// A one-sentence, non-alarming rendering of a failed provider — swaps the
/// old bare "—" for something the user (and whoever they report it to) can
/// actually act on, instead of a silent empty card.
class _ErrorLine extends StatelessWidget {
  final Object error;

  const _ErrorLine(this.error);

  @override
  Widget build(BuildContext context) {
    return Text(
      "Couldn't load this — pull down to retry. ($error)",
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
    );
  }
}

class _TodayProgressCard extends ConsumerWidget {
  const _TodayProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(todaysActivityProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's progress", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMM d').format(DateTime.now()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            activityAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorLine(e),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Nothing logged yet today — it\'ll show up here as you go.'),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      _TodayActivityTile(entry: entries[i], showDivider: i != entries.length - 1),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayActivityTile extends StatelessWidget {
  final TodayActivityEntry entry;
  final bool showDivider;

  const _TodayActivityTile({required this.entry, required this.showDivider});

  IconData get _icon => switch (entry.kind) {
    TodayActivityKind.water => Icons.water_drop_outlined,
    TodayActivityKind.meal => Icons.restaurant_outlined,
    TodayActivityKind.exercise => Icons.fitness_center_outlined,
    TodayActivityKind.dhyana => Icons.self_improvement_outlined,
    TodayActivityKind.weight => Icons.monitor_weight_outlined,
    TodayActivityKind.knee => Icons.accessibility_new_outlined,
    TodayActivityKind.deskBreak => Icons.chair_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  DateFormat('h:mm a').format(entry.time),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(width: 8),
              Icon(_icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: Theme.of(context).textTheme.bodyMedium),
                    if (entry.subtitle != null)
                      Text(entry.subtitle!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

/// Weight and knee-pain trends as compact tappable stat cards, side by
/// side — tap either to open the full trend with its complete chart and
/// entry list.
class _TrendSummaryRow extends StatelessWidget {
  const _TrendSummaryRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Expanded(child: _WeightTrendSummaryCard()),
        SizedBox(width: 12),
        Expanded(child: _PainTrendSummaryCard()),
      ],
    );
  }
}

class _WeightTrendSummaryCard extends ConsumerWidget {
  const _WeightTrendSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(weightTrendProvider);
    return _TrendSummaryCard(
      title: 'Weight',
      icon: Icons.monitor_weight_outlined,
      color: Theme.of(context).colorScheme.primary,
      onTap: () => context.push('/progress/weight'),
      entriesAsync: entriesAsync,
      pointOf: (e) => TrendPoint(e.takenAt, e.weightKg),
      valueLabel: (e) => '${e.weightKg.toStringAsFixed(1)} kg',
    );
  }
}

class _PainTrendSummaryCard extends ConsumerWidget {
  const _PainTrendSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(painTrendProvider);
    return _TrendSummaryCard(
      title: 'Knee pain',
      icon: Icons.accessibility_new_outlined,
      color: Theme.of(context).colorScheme.tertiary,
      onTap: () => context.push('/progress/knee'),
      entriesAsync: entriesAsync,
      pointOf: (e) => TrendPoint(e.recordedAt, e.painBefore0to10.toDouble()),
      valueLabel: (e) => '${e.painBefore0to10}/10',
    );
  }
}

/// Generic small stat card: latest value + a tiny sparkline, tappable
/// through to a detail page. [T] is the entry type (WeightEntry/PainEntry).
class _TrendSummaryCard<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final AsyncValue<List<T>> entriesAsync;
  final TrendPoint Function(T) pointOf;
  final String Function(T) valueLabel;

  const _TrendSummaryCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.entriesAsync,
    required this.pointOf,
    required this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              entriesAsync.when(
                loading: () => const SizedBox(
                  height: 48,
                  child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                ),
                error: (e, _) => _ErrorLine(e),
                data: (entries) {
                  if (entries.isEmpty) {
                    return const Text('No entries yet.');
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        valueLabel(entries.last),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      if (entries.length >= 2)
                        SizedBox(
                          height: 32,
                          child: CustomPaint(
                            painter: _TrendChartPainter(
                              points: [for (final e in entries) pointOf(e)],
                              color: color,
                              minY: null,
                              maxY: null,
                              filled: false,
                            ),
                            size: Size.infinite,
                          ),
                        )
                      else
                        const Text('Log a few more to see a trend.'),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdherenceCard extends ConsumerWidget {
  const _AdherenceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adherenceAsync = ref.watch(adherenceProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This week', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'A filled dot means that habit happened that day. An empty '
              'dot is just a day — not a failure.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            adherenceAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorLine(e),
              data: (days) => _AdherenceGrid(days: days),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdherenceGrid extends StatelessWidget {
  final List<DayAdherence> days;

  const _AdherenceGrid({required this.days});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth()},
      children: [
        TableRow(
          children: [
            const SizedBox(),
            for (final day in days)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Center(
                  child: Text(
                    DateFormat.E().format(day.day).substring(0, 1),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
          ],
        ),
        for (final habit in AdherenceHabit.values)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(habit.label, style: Theme.of(context).textTheme.bodySmall),
              ),
              for (final day in days)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Center(
                    child: Icon(
                      Icons.circle,
                      size: 14,
                      color: (day.done[habit] ?? false)
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class TrendPoint {
  final DateTime date;
  final double value;

  const TrendPoint(this.date, this.value);
}

/// Full-page trend detail: the complete chart plus every underlying entry,
/// newest first. Reached by tapping the Weight or Knee pain summary card
/// on the Progress screen.
class _TrendDetailScreen<T> extends ConsumerWidget {
  final String title;
  final String description;
  final Color Function(BuildContext) color;
  final ProviderListenable<AsyncValue<List<T>>> provider;
  final TrendPoint Function(T) pointOf;
  final double? yMin;
  final double? yMax;
  final String Function(T) valueLabel;
  final String Function(T) timeLabel;

  const _TrendDetailScreen({
    required this.title,
    required this.description,
    required this.color,
    required this.provider,
    required this.pointOf,
    required this.valueLabel,
    required this.timeLabel,
    this.yMin,
    this.yMax,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: _ErrorLine(e)),
        data: (entries) {
          final reversed = entries.reversed.toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(description, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              if (entries.length < 2)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Log a few entries to see a trend.')),
                )
              else
                SizedBox(
                  height: 220,
                  child: CustomPaint(
                    painter: _TrendChartPainter(
                      points: [for (final e in entries) pointOf(e)],
                      color: color(context),
                      minY: yMin,
                      maxY: yMax,
                      filled: true,
                    ),
                    size: Size.infinite,
                  ),
                ),
              const SizedBox(height: 24),
              Text('History', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final entry in reversed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(valueLabel(entry)),
                  subtitle: Text(timeLabel(entry)),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Registered at /progress/weight — see [_TrendDetailScreen].
class WeightTrendDetailScreen extends StatelessWidget {
  const WeightTrendDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _TrendDetailScreen(
      title: 'Weight trend',
      description: 'Last 90 days. Judge progress by the trend, not one reading.',
      color: (context) => Theme.of(context).colorScheme.primary,
      provider: weightTrendProvider,
      pointOf: (e) => TrendPoint(e.takenAt, e.weightKg),
      valueLabel: (e) => '${e.weightKg.toStringAsFixed(1)} kg',
      timeLabel: (e) => DateFormat('EEE, MMM d · h:mm a').format(e.takenAt),
    );
  }
}

/// Registered at /progress/knee — see [_TrendDetailScreen].
class KneeTrendDetailScreen extends StatelessWidget {
  const KneeTrendDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _TrendDetailScreen(
      title: 'Knee pain trend',
      description: 'Pain rating (0-10) at each check-in, last 90 days.',
      color: (context) => Theme.of(context).colorScheme.tertiary,
      provider: painTrendProvider,
      pointOf: (e) => TrendPoint(e.recordedAt, e.painBefore0to10.toDouble()),
      yMin: 0,
      yMax: 10,
      valueLabel: (e) => 'Pain: ${e.painBefore0to10}/10',
      timeLabel: (e) => DateFormat('EEE, MMM d · h:mm a').format(e.recordedAt),
    );
  }
}

/// A minimal line chart (no external chart package) for weight/pain
/// trends: a polyline through [points], optionally with the fill/end-dots
/// used by the full detail view (compact sparklines skip both via
/// [filled]).
class _TrendChartPainter extends CustomPainter {
  final List<TrendPoint> points;
  final Color color;
  final double? minY;
  final double? maxY;
  final bool filled;

  _TrendChartPainter({
    required this.points,
    required this.color,
    required this.minY,
    required this.maxY,
    required this.filled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((p) => p.value);
    final resolvedMinY = minY ?? values.reduce((a, b) => a < b ? a : b);
    final resolvedMaxY = maxY ?? values.reduce((a, b) => a > b ? a : b);

    final firstDate = points.first.date.millisecondsSinceEpoch.toDouble();
    final lastDate = points.last.date.millisecondsSinceEpoch.toDouble();
    final dateSpan = (lastDate - firstDate).clamp(1, double.infinity);
    final valueSpan = (resolvedMaxY - resolvedMinY).clamp(0.001, double.infinity);

    Offset toOffset(TrendPoint p) {
      final x = (p.date.millisecondsSinceEpoch - firstDate) / dateSpan * size.width;
      final y = size.height - ((p.value - resolvedMinY) / valueSpan * size.height);
      return Offset(x, y.clamp(0, size.height));
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = filled ? 2.5 : 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    final fillPath = Path();
    for (var i = 0; i < points.length; i++) {
      final offset = toOffset(points[i]);
      if (i == 0) {
        linePath.moveTo(offset.dx, offset.dy);
        fillPath.moveTo(offset.dx, size.height);
        fillPath.lineTo(offset.dx, offset.dy);
      } else {
        linePath.lineTo(offset.dx, offset.dy);
        fillPath.lineTo(offset.dx, offset.dy);
      }
    }

    if (filled) {
      final fillPaint = Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      fillPath.lineTo(toOffset(points.last).dx, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }

    canvas.drawPath(linePath, linePaint);

    if (filled) {
      final dotPaint = Paint()..color = color;
      for (final p in [points.first, points.last]) {
        canvas.drawCircle(toOffset(p), 3.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color || oldDelegate.filled != filled;
}
