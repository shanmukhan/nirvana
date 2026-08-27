import 'package:flutter/material.dart';

import '../screen_scaffold.dart';

/// Pain/swelling/stiffness log. Red-flag symptoms route to a "consider
/// professional assessment" message, never "push through it".
/// See health-plan-source.md §8, §22.
class KneeScreen extends StatelessWidget {
  const KneeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'Knee',
      body: Center(child: Text('Pain/swelling/stiffness log goes here.')),
    );
  }
}
