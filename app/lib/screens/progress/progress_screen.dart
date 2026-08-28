import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/progress_providers.dart';
import '../screen_scaffold.dart';

/// Weight trend, pain trend, and 7-day adherence — see
/// health-plan-source.md §16/§17 and PROJECT_PLAN.md §1: judge progress
/// from trends, not single days, and never present a missed day as a
/// failure.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenScaffold(
      title: 'Progress / History',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _WeightTrendCard(),
          SizedBox(height: 16),
          _PainTrendCard(),
          SizedBox(height: 16),
          _AdherenceCard(),
        ],
      ),
    );
  }
}

class _WeightTrendCard extends ConsumerWidget {
  const _WeightTrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(weightTrendProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weight trend', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Last 90 days. Judge progress by the trend, not one reading.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            entriesAsync.when(
              loading: () => const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => const Text('—'),
              data: (entries) {
                if (entries.length < 2) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: Text('Log a few weigh-ins to see a trend.')),
                  );
                }
                final points = [
                  for (final e in entries) TrendPoint(e.takenAt, e.weightKg),
                ];
                return _TrendChart(
                  points: points,
                  color: Theme.of(context).colorScheme.primary,
                  height: 160,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PainTrendCard extends ConsumerWidget {
  const _PainTrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(painTrendProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Knee pain trend', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Pain rating (0-10) at each check-in, last 90 days.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            entriesAsync.when(
              loading: () => const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => const Text('—'),
              data: (entries) {
                if (entries.length < 2) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: Text('Log a few knee check-ins to see a trend.')),
                  );
                }
                final points = [
                  for (final e in entries) TrendPoint(e.recordedAt, e.painBefore0to10.toDouble()),
                ];
                return _TrendChart(
                  points: points,
                  color: Theme.of(context).colorScheme.tertiary,
                  height: 160,
                  yMin: 0,
                  yMax: 10,
                );
              },
            ),
          ],
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
              error: (e, _) => const Text('—'),
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

/// A minimal line chart (no external chart package) for weight/pain
/// trends: a polyline through [points] plus first/last value labels.
class _TrendChart extends StatelessWidget {
  final List<TrendPoint> points;
  final Color color;
  final double height;
  final double? yMin;
  final double? yMax;

  const _TrendChart({
    required this.points,
    required this.color,
    required this.height,
    this.yMin,
    this.yMax,
  });

  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.value);
    final minY = yMin ?? values.reduce((a, b) => a < b ? a : b);
    final maxY = yMax ?? values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _TrendChartPainter(points: points, color: color, minY: minY, maxY: maxY),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat.MMMd().format(points.first.date),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(
              DateFormat.MMMd().format(points.last.date),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<TrendPoint> points;
  final Color color;
  final double minY;
  final double maxY;

  _TrendChartPainter({
    required this.points,
    required this.color,
    required this.minY,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final firstDate = points.first.date.millisecondsSinceEpoch.toDouble();
    final lastDate = points.last.date.millisecondsSinceEpoch.toDouble();
    final dateSpan = (lastDate - firstDate).clamp(1, double.infinity);
    final valueSpan = (maxY - minY).clamp(0.001, double.infinity);

    Offset toOffset(TrendPoint p) {
      final x = (p.date.millisecondsSinceEpoch - firstDate) / dateSpan * size.width;
      final y = size.height - ((p.value - minY) / valueSpan * size.height);
      return Offset(x, y.clamp(0, size.height));
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

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
    fillPath.lineTo(toOffset(points.last).dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = color;
    for (final p in [points.first, points.last]) {
      canvas.drawCircle(toOffset(p), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
