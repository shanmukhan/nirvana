import 'package:flutter/material.dart';

import '../screen_scaffold.dart';

/// Per-exercise timer/rep/pain-rating flow. See health-plan-source.md §6, §20.
class ExerciseScreen extends StatelessWidget {
  const ExerciseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Exercise',
      body: Center(child: Text('Strength/walk sessions go here.')),
    );
  }
}
