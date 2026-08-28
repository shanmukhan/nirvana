import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screen_scaffold.dart';

/// Eye, movement, knee-mobility, and neck-exercise break reminders on
/// configurable intervals. See health-plan-source.md §4. Reminder
/// scheduling itself is configured in Settings — see
/// lib/services/reminder_scheduler.dart.
class DeskBreaksScreen extends StatelessWidget {
  const DeskBreaksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Desk Breaks',
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Eye/movement/knee/neck break timers go here.'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Configure reminder times'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
