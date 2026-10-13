import 'package:flutter/material.dart';

import '../../services/battery_optimization_service.dart';
import '../../services/notification_service.dart';
import '../../services/reminder_scheduler.dart';

class NotificationDiagnosticsCard extends StatefulWidget {
  const NotificationDiagnosticsCard({super.key});
  @override
  State<NotificationDiagnosticsCard> createState() => _NotificationDiagnosticsCardState();
}

class _NotificationDiagnosticsCardState extends State<NotificationDiagnosticsCard>
    with WidgetsBindingObserver {
  bool _busy = false;
  String _status = 'Checking reminder permissions…';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh({bool request = false, bool test = false, bool reconcile = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final service = NotificationService.instance;
      if (request) await service.requestPermission();
      await service.refreshTimezone();
      if (request || reconcile) await ReminderScheduler.instance.rescheduleAll();
      if (test) {
        await service.showNow(
          id: 9999,
          title: 'Nirvana test reminder',
          body: 'If you can see and hear this, notifications are available.',
          channel: NotificationChannel.genericMedium,
        );
      }
      final enabled = await service.notificationsEnabled();
      final exact = await service.canScheduleExactAlarms();
      final pending = await service.pendingRequests();
      final blocked = await service.blockedChannels();
      if (mounted) {
        setState(
          () => _status =
              'Notifications: ${enabled == null
                  ? 'unknown'
                  : enabled
                  ? 'allowed'
                  : 'blocked'}. '
              '${pending.length} pending reminders. Timezone: ${service.timezoneIdentifier}. '
              '${exact ? 'Exact scheduling available.' : 'Delivery times may be delayed.'}'
              '${blocked.isEmpty ? '' : ' Blocked categories: ${blocked.join(', ')}.'}'
              '${ReminderScheduler.instance.lastError.value == null ? '' : ' Scheduling needs retry.'}',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Could not check reminders. Retry or open system settings.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reminder status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Allow notifications to receive local reminders. You can log data even if you decline.',
          ),
          const SizedBox(height: 8),
          Text(_status),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _refresh(request: true),
                child: const Text('Allow notifications'),
              ),
              TextButton(
                onPressed: _busy ? null : () => _refresh(test: true),
                child: const Text('Test reminder'),
              ),
              TextButton(
                onPressed: _busy ? null : () => _refresh(reconcile: true),
                child: const Text('Retry scheduling'),
              ),
              TextButton(
                onPressed: _busy ? null : BatteryOptimizationService.openSystemAppSettings,
                child: const Text('System settings'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
