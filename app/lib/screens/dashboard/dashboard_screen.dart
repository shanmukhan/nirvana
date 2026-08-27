import 'package:flutter/material.dart';

import '../screen_scaffold.dart';

/// Today/Dashboard — live cards for Weight, Water, Movement, Desk health,
/// Exercise, Nutrition, Knee, Dhyana. See health-plan-source.md §18.
/// Wired up to real data in Phase 1 (PROJECT_PLAN.md §7).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Dashboard',
      body: Center(child: Text('Today\'s summary cards go here.')),
    );
  }
}
