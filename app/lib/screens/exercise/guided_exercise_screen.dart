import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities.dart';

/// Sets/reps actually completed by the time the guided session ends
/// (naturally, or via "Finish now"). Handed back to ExerciseScreen to
/// pre-fill the pain-rating/feedback log sheet.
class GuidedExerciseResult {
  final int completedSets;
  final int completedReps;

  const GuidedExerciseResult({required this.completedSets, required this.completedReps});
}

enum _Phase { unit, holding, resting, done }

const _restSeconds = 30;

/// A timed walkthrough of one exercise: for hold-based exercises (e.g.
/// Quad Set) a per-rep countdown the user starts when ready; for
/// rep-based exercises a simple rep tally. Either way, a rest countdown
/// runs between sets. See health-plan-source.md §6 for the exercise
/// definitions this walks through.
class GuidedExerciseScreen extends StatefulWidget {
  final ExerciseDefinition definition;

  const GuidedExerciseScreen({super.key, required this.definition});

  @override
  State<GuidedExerciseScreen> createState() => _GuidedExerciseScreenState();
}

class _GuidedExerciseScreenState extends State<GuidedExerciseScreen> {
  late int _currentSet = 1;
  late int _repsDoneInSet = 0;
  _Phase _phase = _Phase.unit;
  int _remainingSeconds = 0;
  Timer? _timer;

  bool get _isHold => widget.definition.holdSeconds != null;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startHold() {
    setState(() {
      _phase = _Phase.holding;
      _remainingSeconds = widget.definition.holdSeconds!;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        _timer?.cancel();
        HapticFeedback.mediumImpact();
        _completeUnit();
      }
    });
  }

  void _completeUnit() {
    final reps = _repsDoneInSet + 1;
    if (reps >= widget.definition.defaultReps) {
      if (_currentSet >= widget.definition.defaultSets) {
        setState(() {
          _repsDoneInSet = reps;
          _phase = _Phase.done;
        });
      } else {
        _startRest(nextSet: _currentSet + 1);
      }
    } else {
      setState(() {
        _repsDoneInSet = reps;
        _phase = _Phase.unit;
      });
    }
  }

  void _startRest({required int nextSet}) {
    setState(() {
      _phase = _Phase.resting;
      _remainingSeconds = _restSeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        _skipRest(nextSet: nextSet);
      }
    });
  }

  void _skipRest({required int nextSet}) {
    _timer?.cancel();
    setState(() {
      _currentSet = nextSet;
      _repsDoneInSet = 0;
      _phase = _Phase.unit;
    });
  }

  void _finishNow() {
    _timer?.cancel();
    final completedSets = _repsDoneInSet > 0 ? _currentSet : _currentSet - 1;
    Navigator.of(context).pop(
      GuidedExerciseResult(
        completedSets: completedSets.clamp(0, widget.definition.defaultSets),
        completedReps: widget.definition.defaultReps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.definition.name),
        actions: [
          if (_phase != _Phase.done)
            TextButton(
              onPressed: _finishNow,
              child: const Text('Finish now', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _phase == _Phase.done ? _buildDone(context) : _buildInProgress(context),
        ),
      ),
    );
  }

  Widget _buildInProgress(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _phase == _Phase.resting
              ? 'Up next: set ${_currentSet + 1} of ${widget.definition.defaultSets}'
              : 'Set $_currentSet of ${widget.definition.defaultSets}',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (_phase != _Phase.resting)
          Text(
            'Rep ${_repsDoneInSet + 1} of ${widget.definition.defaultReps}',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 32),
        Expanded(child: Center(child: _buildCenter(context))),
        const SizedBox(height: 16),
        Text(
          widget.definition.instructions,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCenter(BuildContext context) {
    switch (_phase) {
      case _Phase.resting:
        return _CountdownRing(
          seconds: _remainingSeconds,
          total: _restSeconds,
          label: 'Rest',
          color: Theme.of(context).colorScheme.secondary,
          trailing: OutlinedButton(
            onPressed: () => _skipRest(nextSet: _currentSet + 1),
            child: const Text('Skip rest'),
          ),
        );
      case _Phase.holding:
        return _CountdownRing(
          seconds: _remainingSeconds,
          total: widget.definition.holdSeconds!,
          label: 'Hold',
          color: Theme.of(context).colorScheme.primary,
        );
      case _Phase.unit:
        return _isHold
            ? FilledButton(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(32),
                ),
                onPressed: _startHold,
                child: Text(
                  'Start hold\n(${widget.definition.holdSeconds}s)',
                  textAlign: TextAlign.center,
                ),
              )
            : FilledButton(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(40),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  _completeUnit();
                },
                child: const Text('+1 rep', textAlign: TextAlign.center),
              );
      case _Phase.done:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDone(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text('Session complete', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '${widget.definition.defaultSets} sets × ${widget.definition.defaultReps} reps',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            GuidedExerciseResult(
              completedSets: widget.definition.defaultSets,
              completedReps: widget.definition.defaultReps,
            ),
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _CountdownRing extends StatelessWidget {
  final int seconds;
  final int total;
  final String label;
  final Color color;
  final Widget? trailing;

  const _CountdownRing({
    required this.seconds,
    required this.total,
    required this.label,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (seconds / total).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 180,
          width: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 180,
                width: 180,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$seconds', style: Theme.of(context).textTheme.displaySmall),
                  Text(label, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(height: 16), trailing!],
      ],
    );
  }
}
