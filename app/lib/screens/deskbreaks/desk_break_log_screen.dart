import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/desk_break_log_repository.dart';
import '../../providers/desk_break_providers.dart';
import '../../providers/repository_providers.dart';
import '../../services/reminder_prefs.dart';
import '../screen_scaffold.dart';

/// Opened by tapping a desk-break notification (requirements §4): a
/// yes/no prompt for whether the break was actually taken, so adherence
/// can be tracked. See DeskBreakLogRepository for the lazy auto-miss
/// sweep that covers unanswered notifications.
class DeskBreakLogScreen extends ConsumerWidget {
  final DeskBreakType type;
  final int hour;
  final int minute;

  const DeskBreakLogScreen({
    super.key,
    required this.type,
    required this.hour,
    required this.minute,
  });

  Future<void> _respond(BuildContext context, WidgetRef ref, DeskBreakLogStatus status) async {
    await ref
        .read(deskBreakLogRepositoryProvider)
        .recordResponse(type: type, slotHour: hour, slotMinute: minute, status: status);
    ref.read(deskBreakLogRefreshProvider.notifier).state++;
    if (context.mounted) context.go('/desk-breaks');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenScaffold(
      title: type.label,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.self_improvement_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text('Did you do this break?', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                type.label,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _respond(context, ref, DeskBreakLogStatus.skipped),
                    child: const Text('No'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () => _respond(context, ref, DeskBreakLogStatus.done),
                    child: const Text('Yes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
