import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'app_shell/router.dart';
import 'data/db/app_database.dart';
import 'domain/navigation_input.dart';
import 'domain/startup_tasks.dart';
import 'providers/repository_providers.dart';
import 'providers/desk_break_providers.dart';
import 'providers/calendar_providers.dart';
import 'services/notification_service.dart';
import 'services/phone_usage_prefs.dart';
import 'services/phone_usage_service.dart';
import 'services/reminder_scheduler.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NirvanaStartup());
}

Future<List<String>> _initializeServices() => runStartupTasks({
  'Notifications': () => NotificationService.instance.init(
    onNotificationResponse: _onNotificationResponse,
    onBackgroundNotificationResponse: phoneUsageNotificationResponseHandler,
  ),
  'Phone usage warnings': () async {
    if (!kIsWeb && Platform.isAndroid && await PhoneUsagePrefs.isEnabled()) {
      await PhoneUsageService.registerBackgroundCheck();
    }
  },
  'Reminder scheduling': () => ReminderScheduler.instance.rescheduleAll(),
  'Notification launch': () async {
    final launchDetails = await NotificationService.instance.appLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _handleNotificationPayload(launchDetails!.notificationResponse?.payload);
    }
  },
});

class NirvanaStartup extends StatefulWidget {
  final Future<Database> Function()? openDatabase;
  final Future<List<String>> Function()? initializeServices;
  const NirvanaStartup({super.key, this.openDatabase, this.initializeServices});

  @override
  State<NirvanaStartup> createState() => _NirvanaStartupState();
}

class _NirvanaStartupState extends State<NirvanaStartup> with WidgetsBindingObserver {
  Database? _database;
  bool _failed = false;
  bool _servicesBusy = false;
  List<String> _warnings = const [];
  (String, bool?, bool)? _schedulingState;
  bool _reconciling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    setState(() => _failed = false);
    try {
      final db = await (widget.openDatabase ?? AppDatabase.instance)();
      if (!mounted) return;
      setState(() => _database = db);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_startServices());
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _startServices() async {
    if (_servicesBusy) return;
    setState(() => _servicesBusy = true);
    List<String> warnings;
    try {
      warnings = await (widget.initializeServices ?? _initializeServices)();
    } catch (_) {
      warnings = ['Reminder services'];
    }
    if (!mounted) return;
    setState(() {
      _warnings = warnings;
      _servicesBusy = false;
    });
    unawaited(_reconcileServices());
  }

  Future<void> _reconcileServices() async {
    if (_servicesBusy || _reconciling || _database == null || widget.initializeServices != null) {
      return;
    }
    _reconciling = true;
    try {
      final notifications = NotificationService.instance;
      await notifications.refreshTimezone();
      final state = (
        notifications.timezoneIdentifier,
        await notifications.notificationsEnabled(),
        await notifications.canScheduleExactAlarms(),
      );
      final previous = _schedulingState;
      _schedulingState = state;
      if (previous != null && previous != state) await ReminderScheduler.instance.rescheduleAll();
    } catch (_) {
      if (mounted) setState(() => _warnings = ['Reminder permission or timezone checks']);
    } finally {
      _reconciling = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_reconcileServices());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_database != null) {
      return ProviderScope(
        overrides: [databaseProvider.overrideWithValue(_database!)],
        child: CalendarRollover(
          child: NirvanaApp(
            serviceWarnings: _warnings,
            onRetryServices: _servicesBusy ? null : _startServices,
          ),
        ),
      );
    }
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _failed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could not open your local data. Your records have not been deleted.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _open, child: const Text('Retry')),
                    ],
                  )
                : const CircularProgressIndicator(semanticsLabel: 'Opening your local data'),
          ),
        ),
      ),
    );
  }
}

/// Routes a tapped reminder notification (desk break or water) to its
/// log screen — see requirements §4/§6. Phone-usage's "Snooze" action is
/// handled separately since it never opens the UI.
void _onNotificationResponse(NotificationResponse response) {
  phoneUsageNotificationResponseHandler(response);
  _handleNotificationPayload(response.payload);
}

void _handleNotificationPayload(String? payload) {
  final route = notificationRoute(payload);
  if (route != null) appRouter.go(route);
}

class NirvanaApp extends ConsumerWidget {
  final List<String> serviceWarnings;
  final VoidCallback? onRetryServices;
  const NirvanaApp({super.key, this.serviceWarnings = const [], this.onRetryServices});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(userProfileProvider);
    ref.watch(deskBreakAdherenceProvider);

    return MaterialApp.router(
      title: 'Nirvana',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      builder: (context, child) => Column(
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: ReminderScheduler.instance.lastError,
            builder: (context, error, _) => error == null
                ? const SizedBox.shrink()
                : MaterialBanner(
                    content: Text(error),
                    actions: [
                      TextButton(
                        onPressed: ReminderScheduler.instance.rescheduleAll,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
          ),
          if (serviceWarnings.isNotEmpty)
            MaterialBanner(
              content: Text(
                '${serviceWarnings.join(', ')} unavailable. You can still log your health data.',
              ),
              actions: [TextButton(onPressed: onRetryServices, child: const Text('Retry'))],
            ),
          Expanded(
            child: bootstrap.when(
              data: (_) => child!,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Material(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not prepare your local data.'),
                      TextButton(
                        onPressed: () => ref.invalidate(userProfileProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
