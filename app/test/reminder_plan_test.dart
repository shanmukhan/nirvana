import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/domain/reminder_plan.dart';
import 'package:nirvana/services/phone_usage_prefs.dart';
import 'package:nirvana/services/reminder_prefs.dart';
import 'package:nirvana/services/reminder_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('default eye-break coverage reports truncation and last reminder', () {
    final plan = planReminderSlots(fromMinutes: 510, toMinutes: 1080, intervalMinutes: 25);
    expect(plan.eligibleCount, 23);
    expect(plan.slots.length, 16);
    expect(plan.slots.first, (8, 30));
    expect(plan.slots.last, (14, 45));
    expect(plan.truncated, true);
  });
  test('quiet hours filter before applying cap and handle overnight windows', () {
    const quiet = QuietHoursWindow(enabled: true, startMinutes: 1290, endMinutes: 360);
    expect(quiet.contains(359), true);
    expect(quiet.contains(360), false);
    expect(quiet.contains(1290), true);
    final plan = planReminderSlots(
      fromMinutes: 300,
      toMinutes: 420,
      intervalMinutes: 30,
      maxSlots: 2,
      isQuiet: quiet.contains,
    );
    expect(plan.slots, [(6, 0), (6, 30)]);
    expect(plan.eligibleCount, 3);
  });
  test('invalid and reversed windows produce no schedule', () {
    for (final (from, to, interval) in [
      (0, 1440, 30),
      (-1, 10, 5),
      (600, 500, 30),
      (600, 600, 30),
      (0, 600, 0),
      (0, 600, -1),
    ]) {
      final plan = planReminderSlots(fromMinutes: from, toMinutes: to, intervalMinutes: interval);
      expect(plan.slots, isEmpty);
      expect(plan.issue, isNotNull);
    }
  });
  test('corrupt stored preferences fall back to valid UI and scheduler values', () async {
    SharedPreferences.setMockInitialValues({
      'reminder_water_interval_minutes': 0,
      'reminder_desk_eye_interval_minutes': 99999,
      'reminder_water_from_minutes': -1,
      'reminder_dhyana_time_minutes': 'bad',
      'phone_usage_threshold_minutes': 0,
      'phone_usage_snooze_minutes': 'bad',
    });
    expect(await ReminderPrefs.waterIntervalMinutes(), ReminderPrefs.defaultWaterIntervalMinutes);
    expect(await ReminderPrefs.deskBreakIntervalMinutes(DeskBreakType.eye), 25);
    expect(await ReminderPrefs.waterFromMinutes(), ReminderPrefs.defaultWaterFromMinutes);
    expect(await ReminderPrefs.dhyanaTimeMinutes(), ReminderPrefs.defaultDhyanaTimeMinutes);
    expect(await PhoneUsagePrefs.thresholdMinutes(), 15);
    expect(await PhoneUsagePrefs.snoozeMinutes(), 15);
    await expectLater(ReminderPrefs.setWaterToMinutes(1440), throwsRangeError);
    await expectLater(PhoneUsagePrefs.setThresholdMinutes(-1), throwsRangeError);
  });
}
