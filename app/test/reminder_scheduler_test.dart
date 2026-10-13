import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/services/notification_service.dart';
import 'package:nirvana/services/reminder_prefs.dart';
import 'package:nirvana/services/reminder_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final pending = <int>{};
  Future<void> Function()? onSchedule;
  var fail = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pending.clear();
    onSchedule = null;
    fail = false;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'UTC',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'initialize' || call.method == 'canScheduleExactNotifications') {
          return true;
        }
        if (call.method == 'cancel') {
          final args = call.arguments;
          pending.remove(args is Map ? args['id'] as int : args as int);
        }
        if (call.method == 'zonedSchedule') {
          if (fail) throw PlatformException(code: 'schedule_failed');
          await onSchedule?.call();
          pending.add((call.arguments as Map)['id'] as int);
        }
        return null;
      },
    );
    await NotificationService.instance.init();
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('densest supported iOS schedule stays within its reserved pending budget', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    IOSFlutterLocalNotificationsPlugin.registerWith();
    await ReminderPrefs.setQuietHoursEnabled(false);
    await ReminderPrefs.setWaterFromMinutes(0);
    await ReminderPrefs.setWaterToMinutes(1439);
    await ReminderPrefs.setWaterIntervalMinutes(30);
    await ReminderPrefs.setDeskFromMinutes(0);
    await ReminderPrefs.setDeskToMinutes(1439);
    for (final type in DeskBreakType.values) {
      await ReminderPrefs.setDeskBreakIntervalMinutes(type, 15);
    }
    await ReminderScheduler.instance.rescheduleAll();
    expect(ReminderScheduler.instance.lastError.value, isNull);
    expect(pending, hasLength(63));
    expect(pending.where((id) => id >= 1000 && id < 1100), hasLength(12));
  });

  test('timezone lookup failure is surfaced rather than silently scheduling UTC', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Unknown/Zone',
    );
    await expectLater(
      NotificationService.instance.refreshTimezone(),
      throwsA(isA<LocationNotFoundException>()),
    );
    await ReminderScheduler.instance.rescheduleWater();
    expect(ReminderScheduler.instance.lastError.value, isNotNull);
    expect(pending, isEmpty);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Asia/Kolkata',
    );
    await ReminderScheduler.instance.rescheduleWater();
    expect(ReminderScheduler.instance.lastError.value, isNull);
    expect(NotificationService.instance.timezoneIdentifier, 'Asia/Kolkata');
    expect(pending, hasLength(8));
  });

  test('disable queued during scheduling leaves no stale water alarms', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    onSchedule = () async {
      onSchedule = null;
      entered.complete();
      await release.future;
    };
    final enabling = ReminderScheduler.instance.rescheduleWater();
    await entered.future;
    await ReminderPrefs.setWaterEnabled(false);
    final disabling = ReminderScheduler.instance.rescheduleWater();
    release.complete();
    await Future.wait([enabling, disabling]);
    expect(pending, isEmpty);
    expect(await ReminderPrefs.waterEnabled(), false);
  });

  test('failed scheduling is visible and does not poison subsequent requests', () async {
    fail = true;
    await ReminderScheduler.instance.rescheduleWater();
    expect(ReminderScheduler.instance.lastError.value, isNotNull);
    fail = false;
    await ReminderPrefs.setDhyanaEnabled(false);
    await ReminderScheduler.instance.rescheduleDhyana();
    expect(ReminderScheduler.instance.lastError.value, contains('Water'));
    await ReminderScheduler.instance.rescheduleWater();
    expect(ReminderScheduler.instance.lastError.value, isNull);
    expect(pending, hasLength(8));
  });
}
