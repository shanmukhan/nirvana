import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
    onNotificationResponse: phoneUsageNotificationResponseHandler,
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
