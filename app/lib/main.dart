import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_shell/router.dart';
import 'data/db/app_database.dart';
import 'providers/repository_providers.dart';
import 'services/notification_service.dart';
import 'services/phone_usage_prefs.dart';
import 'services/phone_usage_service.dart';
import 'services/reminder_scheduler.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.instance();
  await NotificationService.instance.init(
    onNotificationResponse: _onNotificationResponse,
    onBackgroundNotificationResponse: phoneUsageNotificationResponseHandler,
  );
  // Continuous-phone-usage warning is Android-only (needs the system-wide
  // "Usage access" permission, which has no iOS equivalent) — see
  // lib/services/phone_usage_service.dart.
  if (!kIsWeb && Platform.isAndroid && await PhoneUsagePrefs.isEnabled()) {
    await PhoneUsageService.registerBackgroundCheck();
  }
  await NotificationService.instance.requestPermission();
  await ReminderScheduler.instance.rescheduleAll();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const NirvanaApp(),
    ),
  );
  // Cold start via a notification tap (app wasn't running): the plugin
  // still records the tap, but onDidReceiveNotificationResponse only
  // fires for a warm/foregrounded app — so check for it explicitly once
  // the router exists.
  final launchDetails = await NotificationService.instance.appLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp == true) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handleNotificationPayload(launchDetails!.notificationResponse?.payload),
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
  if (payload == null) return;
  if (payload == 'water') {
    appRouter.go('/water-log');
    return;
  }
  if (payload.startsWith('deskbreak:')) {
    final parts = payload.split(':');
    if (parts.length != 4) return;
    appRouter.go('/desk-break-log/${parts[1]}/${parts[2]}/${parts[3]}');
  }
}

class NirvanaApp extends ConsumerWidget {
  const NirvanaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bootstraps the default UserProfile/RoutineConfig and exercise
    // library on first launch; screens read live data independently of
    // this completing, so we don't gate the UI on it.
    ref.watch(userProfileProvider);

    return MaterialApp.router(
      title: 'Nirvana',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
