import 'package:flutter/material.dart';

import '../screen_scaffold.dart';

/// Timer + start/end bell + session log. See docs/dhyana-plan.md.
class DhyanaScreen extends StatelessWidget {
  const DhyanaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Dhyana',
      body: Center(child: Text('Meditation timer and session log go here.')),
    );
  }
}
