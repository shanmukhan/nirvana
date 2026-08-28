import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';
import 'phone_usage_prefs.dart';

/// Warns when the phone screen has been continuously on for longer than
/// the configured threshold, with a snooze option — see
/// [PhoneUsageConfig] in lib/domain/routine_config.dart. Android-only:
/// there is no whole-device "how long has the screen been on" API on
/// iOS, only per-app usage the app itself can see.
///
/// Detection runs via a periodic WorkManager task (Android's minimum
/// periodic interval is 15 minutes, which happens to match a sensible
/// default threshold) rather than a foreground Timer, so the warning
/// still fires when Nirvana itself isn't open. WorkManager invokes
/// [phoneUsageWorkManagerCallbackDispatcher] in a separate background
/// isolate with no access to the running app's state, so everything it
/// needs (settings, snooze state) is read from SharedPreferences and it
/// talks to the notifications plugin directly.
const String phoneUsageTaskName = 'nirvana.continuousPhoneUsageCheck';

class PhoneUsageService {
  PhoneUsageService._();

  static Future<bool> hasPermission() async {
    return await UsageStats.checkUsagePermission() ?? false;
  }

  /// Opens the system "Usage access" settings screen for the user to
  /// grant PACKAGE_USAGE_STATS — this can't be requested as a normal
  /// runtime permission dialog.
  static Future<void> requestPermission() async {
    await UsageStats.grantUsagePermission();
  }

  static Future<void> registerBackgroundCheck() async {
    await Workmanager().initialize(phoneUsageWorkManagerCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      phoneUsageTaskName,
      phoneUsageTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancelBackgroundCheck() async {
    await Workmanager().cancelByUniqueName(phoneUsageTaskName);
  }

  /// The core check, shared by the background task and any in-app
  /// manual trigger. Returns true if a warning was shown.
  static Future<bool> checkAndMaybeWarn() async {
    if (!await PhoneUsagePrefs.isEnabled()) return false;
    if (!await hasPermission()) return false;

    final snoozedUntil = await PhoneUsagePrefs.snoozedUntil();
    final now = DateTime.now();
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) return false;

    final thresholdMinutes = await PhoneUsagePrefs.thresholdMinutes();
    final continuousMinutes = await _continuousScreenOnMinutes(now, thresholdMinutes);
    if (continuousMinutes == null || continuousMinutes < thresholdMinutes) {
      return false;
    }

    final snoozeMinutes = await PhoneUsagePrefs.snoozeMinutes();
    await NotificationService.instance.showPhoneUsageWarning(
      continuousMinutes: continuousMinutes,
      snoozeMinutes: snoozeMinutes,
    );
    return true;
  }

  /// Returns how many minutes the screen has been continuously on up to
  /// [now], or null if that can't be determined from the events
  /// available (e.g. no screen on/off events at all in the query
  /// window — conservatively treated as "unknown", not "on", so this
  /// never fires on a guess).
  static Future<int?> _continuousScreenOnMinutes(DateTime now, int thresholdMinutes) async {
    // Query a window wider than the threshold so the actual on-transition
    // (not just the threshold boundary) is likely captured.
    final windowMinutes = (thresholdMinutes * 3).clamp(45, 180);
    final start = now.subtract(Duration(minutes: windowMinutes));
    final events = await UsageStats.queryEvents(start, now);

    DateTime? lastOnStart;
    for (final event in events..sort((a, b) => (a.timeStamp ?? '0').compareTo(b.timeStamp ?? '0'))) {
      switch (event.eventTypeValue) {
        case 15: // SCREEN_INTERACTIVE
          lastOnStart = event.timeStampDate;
        case 16: // SCREEN_NON_INTERACTIVE
          lastOnStart = null;
      }
    }

    if (lastOnStart == null) return null;
    return now.difference(lastOnStart).inMinutes;
  }
}

/// Handles the "Snooze" button tap on the phone-usage warning
/// notification. Must be a top-level/static function — the plugin may
/// invoke it in a background isolate when the app isn't running.
@pragma('vm:entry-point')
void phoneUsageNotificationResponseHandler(NotificationResponse response) {
  if (response.actionId != NotificationService.snoozePhoneUsageActionId) return;
  WidgetsFlutterBinding.ensureInitialized();
  PhoneUsagePrefs.snoozeMinutes().then((minutes) {
    PhoneUsagePrefs.snoozeFor(Duration(minutes: minutes));
  });
}

/// WorkManager's background isolate entry point. Re-initializes just
/// enough (notifications plugin) to show the warning, independent of
/// the main app's widget tree/providers.
@pragma('vm:entry-point')
void phoneUsageWorkManagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await NotificationService.instance.init(
      onNotificationResponse: phoneUsageNotificationResponseHandler,
      onBackgroundNotificationResponse: phoneUsageNotificationResponseHandler,
    );
    await PhoneUsageService.checkAndMaybeWarn();
    return true;
  });
}
