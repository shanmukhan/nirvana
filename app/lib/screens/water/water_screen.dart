import 'package:flutter/material.dart';

import '../screen_scaffold.dart';

/// Quick-log buttons, progress ring, reminders with snooze/skip.
/// See health-plan-source.md §3.
class WaterScreen extends StatelessWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Water',
      body: Center(child: Text('Hydration log and progress ring go here.')),
    );
  }
}
