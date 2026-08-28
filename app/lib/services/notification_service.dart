import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local-notification plumbing shared by every reminder type (hydration,
/// desk breaks, dhyana, exercise). Scheduling driven by RoutineConfig is
/// built out per habit type as each screen goes live; this wires up plugin
/// init, channels, and permission requests so screens can call `instance`.
/// See PROJECT_PLAN.md §6.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationDetails _highPriorityAndroidDetails =
      AndroidNotificationDetails(
        'nirvana_high',
        'High priority reminders',
        channelDescription: 'Hydration and scheduled exercise reminders',
        importance: Importance.high,
        priority: Priority.high,
      );

  static const AndroidNotificationDetails _mediumPriorityAndroidDetails =
      AndroidNotificationDetails(
        'nirvana_medium',
        'Medium priority reminders',
        channelDescription: 'Movement, knee mobility, and dhyana reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

  static const AndroidNotificationDetails _lowPriorityAndroidDetails =
      AndroidNotificationDetails(
        'nirvana_low',
        'Low priority reminders',
        channelDescription: 'Eye-distance and neck-exercise reminders',
        importance: Importance.low,
        priority: Priority.low,
      );

  /// Action id for the "Snooze" button on the continuous-phone-usage
  /// warning notification (see lib/services/phone_usage_service.dart).
  static const String snoozePhoneUsageActionId = 'snooze_phone_usage';
  static const int phoneUsageWarningNotificationId = 9001;

  Future<void> init({
    void Function(NotificationResponse response)? onNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onBackgroundNotificationResponse,
  }) async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // Falls back to UTC if the platform timezone name can't be resolved —
      // scheduled reminders will then be off by the local UTC offset rather
      // than failing outright.
    }
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationResponse,
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      return await androidImpl.requestNotificationsPermission() ?? false;
    }
    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosImpl != null) {
      return await iosImpl.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidImpl =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Whether exact-time alarms are available — Android 12's "Alarms &
  /// reminders" grant, auto-on by default but user-revocable, and
  /// Android 13+'s explicit SCHEDULE_EXACT_ALARM grant. Without this,
  /// [scheduleDaily] falls back to inexact scheduling, which on some
  /// devices/standby states can defer a reminder by 30-60+ minutes —
  /// unacceptable for a 15-minute-interval habit reminder.
  Future<bool> canScheduleExactAlarms() async =>
      await _androidImpl?.canScheduleExactNotifications() ?? true;

  /// Opens the system "Alarms & reminders" settings screen for this app.
  Future<void> requestExactAlarmsPermission() async {
    await _androidImpl?.requestExactAlarmsPermission();
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required NotificationPriorityTier priority,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: switch (priority) {
          NotificationPriorityTier.high => _highPriorityAndroidDetails,
          NotificationPriorityTier.medium => _mediumPriorityAndroidDetails,
          NotificationPriorityTier.low => _lowPriorityAndroidDetails,
        },
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Warns about continuous phone screen time, with a "Snooze" action
  /// button. See lib/services/phone_usage_service.dart for the detection
  /// logic that calls this.
  Future<void> showPhoneUsageWarning({
    required int continuousMinutes,
    required int snoozeMinutes,
  }) async {
    await _plugin.show(
      id: phoneUsageWarningNotificationId,
      title: "You've been on your phone a while",
      body:
          "That's about $continuousMinutes minutes continuously. "
          'Maybe a good moment for a short break.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'nirvana_medium',
          'Medium priority reminders',
          channelDescription: 'Movement, knee mobility, dhyana, and phone-usage reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              snoozePhoneUsageActionId,
              'Snooze $snoozeMinutes min',
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedules a notification that repeats daily at [hour]:[minute] local
  /// time. Used for every routine reminder (water, dhyana, desk breaks,
  /// knee/weight check-ins) — see lib/services/reminder_scheduler.dart.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required NotificationPriorityTier priority,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final exact = await canScheduleExactAlarms();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: switch (priority) {
          NotificationPriorityTier.high => _highPriorityAndroidDetails,
          NotificationPriorityTier.medium => _mediumPriorityAndroidDetails,
          NotificationPriorityTier.low => _lowPriorityAndroidDetails,
        },
        iOS: const DarwinNotificationDetails(),
      ),
      // Inexact scheduling batches delivery into an OS-chosen window that
      // can run 30-60+ minutes past the target time, especially once the
      // app drops out of a recently-used standby bucket — far too loose
      // for a reminder. Exact scheduling is used whenever the permission
      // is available (default-on for most users; see
      // requestExactAlarmsPermission for the fallback path).
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  Future<void> cancelAll() => _plugin.cancelAll();
}

enum NotificationPriorityTier { high, medium, low }
