import 'package:flutter/material.dart';

import '../screen_scaffold.dart';

/// Eye, movement, knee-mobility, and posture break reminders on
/// configurable intervals. See health-plan-source.md §4.
class DeskBreaksScreen extends StatelessWidget {
  const DeskBreaksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Desk Breaks',
      body: Center(child: Text('Eye/movement/knee/posture break timers go here.')),
    );
  }
}
