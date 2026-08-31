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

  /// Resource name (Android `res/raw`, no extension) / bundled file name
  /// (iOS, with extension) for the generic "Nirvana" reminder tone, used by
  /// every reminder that doesn't have its own distinct sound (see
  /// [NotificationChannel]). Android notification-channel sound is
  /// immutable once a channel with a given id has been created on a
  /// device, so switching a channel's sound requires a brand-new channel
  /// id — hence `_v2`/`_v3` here rather than reusing earlier ids. The old
  /// channel ids are simply no longer scheduled against; a user who
  /// already had them created keeps them as an orphaned, unused channel
  /// (Android gives apps no way to delete another app's existing
  /// channel, so there's nothing to clean up).
  static const String _toneResource = 'nirvana_tone';
  static const AndroidNotificationSound _androidTone = RawResourceAndroidNotificationSound(
    _toneResource,
  );
  static const String _iosTone = 'nirvana_tone.wav';

  static const AndroidNotificationDetails _highPriorityAndroidDetails =
      AndroidNotificationDetails(
        'nirvana_high_v2',
        'High priority reminders',
        channelDescription: 'Scheduled exercise reminders',
        importance: Importance.high,
        priority: Priority.high,
        sound: _androidTone,
      );

  static const AndroidNotificationDetails _mediumPriorityAndroidDetails =
      AndroidNotificationDetails(
        'nirvana_medium_v2',
        'Medium priority reminders',
        channelDescription: 'Movement and neck-exercise reminders, phone-usage warnings',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        sound: _androidTone,
      );

  // v3: bumped from Importance.low to defaultImportance — Android channels
  // below IMPORTANCE_DEFAULT are silent by OS design regardless of the
  // `sound` field, so eye-distance/neck-exercise reminders never played a
  // sound. Channel importance/sound is immutable once created on a device,
  // hence the new channel id rather than editing nirvana_low_v2 in place.
  static const AndroidNotificationDetails _lowPriorityAndroidDetails =
      AndroidNotificationDetails(
        'nirvana_low_v3',
        'Low priority reminders',
        channelDescription: 'Weigh-in reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        sound: _androidTone,
      );

  static const DarwinNotificationDetails _iosDetails = DarwinNotificationDetails(
    sound: _iosTone,
  );

  // Water, Dhyana, Knee (check-in + mobility break), and Eye break each get
  // their own channel/sound so they're distinguishable by ear without
  // looking at the phone — same immutable-once-created channel-id rule as
  // above applies, so any future sound change needs a new `_v1` -> `_v2`.
  static const AndroidNotificationDetails _waterAndroidDetails = AndroidNotificationDetails(
    'nirvana_water_v1',
    'Water reminders',
    channelDescription: 'Hydration reminders',
    importance: Importance.high,
    priority: Priority.high,
    sound: RawResourceAndroidNotificationSound('nirvana_water_tone'),
  );
  static const DarwinNotificationDetails _waterIosDetails = DarwinNotificationDetails(
    sound: 'nirvana_water_tone.wav',
  );

  static const AndroidNotificationDetails _dhyanaAndroidDetails = AndroidNotificationDetails(
    'nirvana_dhyana_v1',
    'Dhyana reminders',
    channelDescription: 'Meditation practice reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    sound: RawResourceAndroidNotificationSound('nirvana_dhyana_tone'),
  );
  static const DarwinNotificationDetails _dhyanaIosDetails = DarwinNotificationDetails(
    sound: 'nirvana_dhyana_tone.wav',
  );

  /// Shared by the daily Knee check-in and the Knee-mobility desk break —
  /// both are "knee" reminders to the user, so both get the same sound.
  static const AndroidNotificationDetails _kneeAndroidDetails = AndroidNotificationDetails(
    'nirvana_knee_v1',
    'Knee reminders',
    channelDescription: 'Knee check-in and knee mobility break reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    sound: RawResourceAndroidNotificationSound('nirvana_knee_tone'),
  );
  static const DarwinNotificationDetails _kneeIosDetails = DarwinNotificationDetails(
    sound: 'nirvana_knee_tone.wav',
  );

  static const AndroidNotificationDetails _eyeAndroidDetails = AndroidNotificationDetails(
    'nirvana_eye_v1',
    'Eye break reminders',
    channelDescription: 'Eye-distance break reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    sound: RawResourceAndroidNotificationSound('nirvana_eye_tone'),
  );
  static const DarwinNotificationDetails _eyeIosDetails = DarwinNotificationDetails(
    sound: 'nirvana_eye_tone.wav',
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

  /// Details of the notification that launched the app from a killed
  /// state, if any — flutter_local_notifications' normal tap callback
  /// only fires for a warm/foregrounded app, so a cold launch via
  /// notification tap has to be checked for explicitly. See main.dart.
  Future<NotificationAppLaunchDetails?> appLaunchDetails() =>
      _plugin.getNotificationAppLaunchDetails();

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
    required NotificationChannel channel,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: channel._androidDetails,
        iOS: channel._iosDetails,
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
          'nirvana_medium_v2',
          'Medium priority reminders',
          channelDescription: 'Movement and neck-exercise reminders, phone-usage warnings',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          sound: _androidTone,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              snoozePhoneUsageActionId,
              'Snooze $snoozeMinutes min',
            ),
          ],
        ),
        iOS: _iosDetails,
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
    required NotificationChannel channel,
    String? payload,
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
        android: channel._androidDetails,
        iOS: channel._iosDetails,
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
      payload: payload,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  Future<void> cancelAll() => _plugin.cancelAll();
}

/// Which channel/sound a reminder plays through. Water, Dhyana, Knee (both
/// the check-in and the mobility break), and Eye break each get their own
/// distinct sound so they're recognizable by ear; everything else uses one
/// of the three generic priority-tier channels/sounds.
enum NotificationChannel {
  water(NotificationService._waterAndroidDetails, NotificationService._waterIosDetails),
  dhyana(NotificationService._dhyanaAndroidDetails, NotificationService._dhyanaIosDetails),
  knee(NotificationService._kneeAndroidDetails, NotificationService._kneeIosDetails),
  eye(NotificationService._eyeAndroidDetails, NotificationService._eyeIosDetails),
  genericHigh(NotificationService._highPriorityAndroidDetails, NotificationService._iosDetails),
  genericMedium(
    NotificationService._mediumPriorityAndroidDetails,
    NotificationService._iosDetails,
  ),
  genericLow(NotificationService._lowPriorityAndroidDetails, NotificationService._iosDetails);

  final AndroidNotificationDetails _androidDetails;
  final DarwinNotificationDetails _iosDetails;

  const NotificationChannel(this._androidDetails, this._iosDetails);
}
