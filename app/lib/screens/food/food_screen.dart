import 'package:flutter/material.dart';

import '../screen_scaffold.dart';

/// Meal logging against the templates in health-plan-source.md §9-§15,
/// with a protein estimate.
class FoodScreen extends StatelessWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Food',
      body: Center(child: Text('Meal log and protein estimate go here.')),
    );
  }
}
