import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
        channelDescription: 'Eye-distance and posture reminders',
        importance: Importance.low,
        priority: Priority.low,
      );

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
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

  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

enum NotificationPriorityTier { high, medium, low }
