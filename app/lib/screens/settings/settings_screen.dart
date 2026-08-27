import 'package:flutter/material.dart';

import '../screen_scaffold.dart';

/// RoutineConfig editor — this is where "configurable, not hard-coded"
/// is enforced. See PROJECT_PLAN.md §3 and lib/domain/routine_config.dart.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Settings',
      body: Center(child: Text('RoutineConfig editor goes here.')),
    );
  }
}
