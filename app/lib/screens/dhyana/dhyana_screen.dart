import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import '../../domain/routine_config.dart' as config;
import '../../providers/dhyana_providers.dart';
import '../../providers/repository_providers.dart';
import '../screen_scaffold.dart';

const Map<config.DhyanaPracticeType, String> _practiceLabels = {
  config.DhyanaPracticeType.breathAwareness: 'Breath awareness',
  config.DhyanaPracticeType.bodyScan: 'Body scan',
  config.DhyanaPracticeType.mantra: 'Mantra / counting',
};

DhyanaPractice _toEntityPractice(config.DhyanaPracticeType t) => switch (t) {
  config.DhyanaPracticeType.breathAwareness => DhyanaPractice.breathAwareness,
  config.DhyanaPracticeType.bodyScan => DhyanaPractice.bodyScan,
  config.DhyanaPracticeType.mantra => DhyanaPractice.mantra,
};

/// Timer + start/end bell + session log. See docs/dhyana-plan.md.
/// No streak-shaming copy anywhere in this screen — a missed day is just
/// a missed day.
class DhyanaScreen extends ConsumerStatefulWidget {
  const DhyanaScreen({super.key});

  @override
  ConsumerState<DhyanaScreen> createState() => _DhyanaScreenState();
}

class _DhyanaScreenState extends ConsumerState<DhyanaScreen> {
  static const config.DhyanaConfig _defaultConfig = config.DhyanaConfig();

  config.DhyanaPracticeType _practice = _defaultConfig.primarySession.defaultPractice;
  int _plannedMinutes = _defaultConfig.primarySession.durationMinutes;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _running = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    SystemSound.play(SystemSoundType.click); // gentle start bell stand-in
    setState(() {
      _running = true;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed.inMinutes >= _plannedMinutes) {
        _finish();
      }
    });
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    SystemSound.play(SystemSoundType.click); // gentle close bell stand-in
    final actualMinutes = (_elapsed.inSeconds / 60).ceil().clamp(0, 1 << 30);
    setState(() => _running = false);
    // No forced minimum duration — even a short session counts as completed.
    await ref
        .read(dhyanaRepositoryProvider)
        .logSession(
          plannedDurationMin: _plannedMinutes,
          actualDurationMin: actualMinutes == 0 ? 1 : actualMinutes,
          practiceType: _toEntityPractice(_practice),
        );
    ref.read(dhyanaRefreshProvider.notifier).state++;
    setState(() => _elapsed = Duration.zero);
  }

  void _stopWithoutLogging() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _elapsed = Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsToday = ref.watch(dhyanaSessionsTodayProvider);
    final streak = ref.watch(dhyanaStreakProvider);
    final remaining = Duration(minutes: _plannedMinutes) - _elapsed;

    return ScreenScaffold(
      title: 'Dhyana',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Text(
              _running
                  ? _formatDuration(remaining.isNegative ? Duration.zero : remaining)
                  : '$_plannedMinutes:00',
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ),
          const SizedBox(height: 24),
          if (!_running) ...[
            DropdownButtonFormField<config.DhyanaPracticeType>(
              initialValue: _practice,
              decoration: const InputDecoration(labelText: 'Practice'),
              items: [
                for (final entry in _practiceLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _practice = value!),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _plannedMinutes.toDouble(),
              min: 2,
              max: 30,
              divisions: 28,
              label: '$_plannedMinutes min',
              onChanged: (value) => setState(() => _plannedMinutes = value.round()),
            ),
            Center(child: Text('$_plannedMinutes minutes')),
            const SizedBox(height: 24),
            Center(
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.self_improvement),
                label: const Text('Start session'),
              ),
            ),
          ] else ...[
            Center(
              child: Wrap(
                spacing: 12,
                children: [
                  FilledButton(onPressed: _finish, child: const Text('End now')),
                  OutlinedButton(
                    onPressed: _stopWithoutLogging,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          sessionsToday.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (sessions) => Text(
              'Sessions completed today: ${sessions.length}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 8),
          streak.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (days) => Text(
              days == 0 ? 'No current streak — that\'s okay, start today.' : 'Streak: $days days',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
