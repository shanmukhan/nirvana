import 'package:flutter/material.dart';

import '../screen_scaffold.dart';

/// Weight trend, pain trend, adherence over the 4-month roadmap.
/// See health-plan-source.md §17.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Progress / History',
      body: Center(child: Text('Trend charts and history go here.')),
    );
  }
}
