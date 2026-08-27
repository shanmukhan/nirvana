import 'package:flutter/material.dart';

import '../screen_scaffold.dart';

/// Weight entry, 7-day average, and trend. See health-plan-source.md §16.
class WeightScreen extends StatelessWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Weight',
      body: Center(child: Text('Weight entries and trend go here.')),
    );
  }
}
