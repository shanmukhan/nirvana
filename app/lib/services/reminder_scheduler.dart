import 'package:flutter/foundation.dart';

import '../domain/reminder_plan.dart';
import 'desk_break_schedule_history.dart';
import 'notification_service.dart';
import 'reminder_prefs.dart';

/// Turns [ReminderPrefs] into scheduled local notifications.
///
/// **Call the specific `reschedule*` method for whatever setting just
/// changed** (e.g. [rescheduleWater] after editing the water card) —
/// never [rescheduleAll] from a settings callback. See
/// docs/notification-debugging.md "Finding 3" for why: cancelling and
/// re-laying every category's alarms on every single settings tweak was
/// generating 150-350+ AlarmManager alarms per edit, which is enough for
/// Android's OS-level alarm-abuse heuristics to auto-demote the app into
/// the RESTRICTED app-standby bucket — silently throttling notification
/// delivery even with battery optimization and exact-alarm permission
/// both correctly granted. [rescheduleAll] still exists for app startup
/// (main.dart) and for quiet-hours changes (which affect every category).
///
/// Each category gets a fixed id range so re-scheduling is idempotent:
///   1000-1015  water              2000        dhyana
///   3000-3015  eye break          3100-3115   movement break
///   3200-3215  knee mobility      3300-3315   neck exercise
///   4000       knee check-in      5000        weight check-in
/// Interval-based categories (water, desk breaks) are expanded into one
/// fixed daily clock-time notification per slot across the active window,
/// rather than a true periodic timer — flutter_local_notifications has no
/// arbitrary-interval repeat, and daily fixed-time notifications work
/// reliably in the background without needing a WorkManager isolate.
class ReminderScheduler {
  ReminderScheduler._();

  static final ReminderScheduler instance = ReminderScheduler._();

  Future<void> _pending = Future.value();
  final lastError = ValueNotifier<String?>(null);
  final _failedCategories = <String>{};

  Future<void> _enqueue(String category, Future<void> Function() action) {
    _pending = _pending.then((_) async {
      try {
        await action();
        if (category == 'All') {
          _failedCategories.clear();
        } else {
          _failedCategories.remove(category);
          if (category == 'Desk breaks') {
            _failedCategories.removeAll(DeskBreakType.values.map((type) => type.label));
          }
        }
      } catch (_) {
        _failedCategories.add(category);
      }
      lastError.value = _failedCategories.isEmpty
          ? null
          : 'Could not update ${_failedCategories.join(', ')} reminders. Your settings are saved; retry scheduling.';
    });
    return _pending;
  }

  Future<void> rescheduleAll() => _enqueue('All', _rescheduleAll);
  Future<void> rescheduleWater({QuietHoursWindow? quietHours}) =>
      _enqueue('Water', () => _rescheduleWater(quietHours: quietHours));
  Future<void> rescheduleDhyana({QuietHoursWindow? quietHours}) =>
      _enqueue('Dhyana', () => _rescheduleDhyana(quietHours: quietHours));
  Future<void> rescheduleKneeCheckin({QuietHoursWindow? quietHours}) =>
      _enqueue('Knee', () => _rescheduleKneeCheckin(quietHours: quietHours));
  Future<void> rescheduleWeightCheckin({QuietHoursWindow? quietHours}) =>
      _enqueue('Weight', () => _rescheduleWeightCheckin(quietHours: quietHours));
  Future<void> rescheduleDeskBreak(DeskBreakType type, {QuietHoursWindow? quietHours}) =>
      _enqueue(type.label, () => _rescheduleDeskBreak(type, quietHours: quietHours));
  Future<void> rescheduleAllDeskBreaks() => _enqueue('Desk breaks', _rescheduleAllDeskBreaks);

  static const _waterIdBase = 1000;
  static const _dhyanaId = 2000;
  static const _kneeCheckinId = 4000;
  static const _weightCheckinId = 5000;
  // Lower than before (was 30) — see the class doc: fewer alarms per
  // category means less total alarm churn per reschedule, on top of only
  // rescheduling the category that actually changed.
  static const _maxSlotsPerCategory = 16;
  // Five interval categories + three daily reminders + one reserved request.
  // A fixed allocation avoids cancelling unrelated categories on every edit.
  static int get intervalSlotLimit => defaultTargetPlatform == TargetPlatform.iOS ? 12 : 16;

  static const Map<DeskBreakType, int> _deskBreakIdBase = {
    DeskBreakType.eye: 3000,
    DeskBreakType.movement: 3100,
    DeskBreakType.kneeMobility: 3200,
    DeskBreakType.neck: 3300,
  };

  /// Reschedules every category. Only call this from app startup or after
  /// a quiet-hours change — anywhere else, call the specific `reschedule*`
  /// method for the one category that changed (see class doc).
  Future<void> _rescheduleAll() async {
    final quietHours = await QuietHoursWindow.load();
    await _rescheduleWater(quietHours: quietHours);
    await _rescheduleDhyana(quietHours: quietHours);
    await _rescheduleKneeCheckin(quietHours: quietHours);
    await _rescheduleWeightCheckin(quietHours: quietHours);
    for (final type in DeskBreakType.values) {
      await _rescheduleDeskBreak(type, quietHours: quietHours);
    }
  }

  Future<void> _rescheduleWater({QuietHoursWindow? quietHours}) async {
    await _cancelRange(_waterIdBase, _maxSlotsPerCategory);
    await _scheduleWater(quietHours ?? await QuietHoursWindow.load());
  }

  Future<void> _rescheduleDhyana({QuietHoursWindow? quietHours}) async {
    await NotificationService.instance.cancel(_dhyanaId);
    await _scheduleDhyana(quietHours ?? await QuietHoursWindow.load());
  }

  Future<void> _rescheduleKneeCheckin({QuietHoursWindow? quietHours}) async {
    await NotificationService.instance.cancel(_kneeCheckinId);
    await _scheduleKneeCheckin(quietHours ?? await QuietHoursWindow.load());
  }

  Future<void> _rescheduleWeightCheckin({QuietHoursWindow? quietHours}) async {
    await NotificationService.instance.cancel(_weightCheckinId);
    await _scheduleWeightCheckin(quietHours ?? await QuietHoursWindow.load());
  }

  Future<void> _rescheduleDeskBreak(DeskBreakType type, {QuietHoursWindow? quietHours}) async {
    try {
      await _cancelRange(_deskBreakIdBase[type]!, _maxSlotsPerCategory);
      await _scheduleDeskBreak(type, quietHours ?? await QuietHoursWindow.load());
    } catch (_) {
      await DeskBreakScheduleHistory.record(type, []);
      rethrow;
    }
  }

  /// Desk-break active-window (from/to) is shared by all four desk-break
  /// types, so changing it needs all four rescheduled — still far fewer
  /// alarms than a full [rescheduleAll].
  Future<void> _rescheduleAllDeskBreaks() async {
    final quietHours = await QuietHoursWindow.load();
    for (final type in DeskBreakType.values) {
      await _rescheduleDeskBreak(type, quietHours: quietHours);
    }
  }

  Future<void> _cancelRange(int base, int count) async {
    for (var i = 0; i < count; i++) {
      await NotificationService.instance.cancel(base + i);
    }
  }

  /// Every [hour]:[minute] pair from [fromMinutes] to [toMinutes] stepping
  /// by [intervalMinutes], capped at [intervalSlotLimit] slots, minus
  /// any that fall inside [quietHours].
  List<(int hour, int minute)> _dailySlots({
    required int fromMinutes,
    required int toMinutes,
    required int intervalMinutes,
    required QuietHoursWindow quietHours,
  }) {
    return planReminderSlots(
      fromMinutes: fromMinutes,
      toMinutes: toMinutes,
      intervalMinutes: intervalMinutes,
      maxSlots: intervalSlotLimit,
      isQuiet: quietHours.contains,
    ).slots;
  }

  Future<void> _scheduleWater(QuietHoursWindow quietHours) async {
    if (!await ReminderPrefs.waterEnabled()) return;
    final slots = _dailySlots(
      fromMinutes: await ReminderPrefs.waterFromMinutes(),
      toMinutes: await ReminderPrefs.waterToMinutes(),
      intervalMinutes: await ReminderPrefs.waterIntervalMinutes(),
      quietHours: quietHours,
    );
    for (var i = 0; i < slots.length; i++) {
      final (hour, minute) = slots[i];
      await NotificationService.instance.scheduleDaily(
        id: _waterIdBase + i,
        title: 'Time for water',
        body: 'A glass of water keeps you on track for today\'s goal.',
        hour: hour,
        minute: minute,
        channel: NotificationChannel.water,
        payload: 'water',
      );
    }
  }

  Future<void> _scheduleDhyana(QuietHoursWindow quietHours) async {
    if (!await ReminderPrefs.dhyanaEnabled()) return;
    final minutes = await ReminderPrefs.dhyanaTimeMinutes();
    if (quietHours.contains(minutes)) return;
    await NotificationService.instance.scheduleDaily(
      id: _dhyanaId,
      title: 'Dhyana time',
      body: 'A few quiet minutes for your practice.',
      hour: minutes ~/ 60,
      minute: minutes % 60,
      channel: NotificationChannel.dhyana,
      payload: 'dhyana',
    );
  }

  Future<void> _scheduleKneeCheckin(QuietHoursWindow quietHours) async {
    if (!await ReminderPrefs.kneeEnabled()) return;
    final minutes = await ReminderPrefs.kneeTimeMinutes();
    if (quietHours.contains(minutes)) return;
    await NotificationService.instance.scheduleDaily(
      id: _kneeCheckinId,
      title: 'Knee check-in',
      body: 'How does your knee feel today? Log pain, swelling, and stiffness.',
      hour: minutes ~/ 60,
      minute: minutes % 60,
      channel: NotificationChannel.knee,
      payload: 'knee',
    );
  }

  Future<void> _scheduleWeightCheckin(QuietHoursWindow quietHours) async {
    if (!await ReminderPrefs.weightEnabled()) return;
    final minutes = await ReminderPrefs.weightTimeMinutes();
    if (quietHours.contains(minutes)) return;
    await NotificationService.instance.scheduleDaily(
      id: _weightCheckinId,
      title: 'Weigh-in reminder',
      body: 'Log today\'s weight to keep your trend up to date.',
      hour: minutes ~/ 60,
      minute: minutes % 60,
      channel: NotificationChannel.genericLow,
      payload: 'weight',
    );
  }

  Future<void> _scheduleDeskBreak(DeskBreakType type, QuietHoursWindow quietHours) async {
    final slots = !await ReminderPrefs.deskBreakEnabled(type)
        ? <(int, int)>[]
        : _dailySlots(
            fromMinutes: await ReminderPrefs.deskFromMinutes(),
            toMinutes: await ReminderPrefs.deskToMinutes(),
            intervalMinutes: await ReminderPrefs.deskBreakIntervalMinutes(type),
            quietHours: quietHours,
          );
    final base = _deskBreakIdBase[type]!;
    for (var i = 0; i < slots.length; i++) {
      final (hour, minute) = slots[i];
      await NotificationService.instance.scheduleDaily(
        id: base + i,
        title: type.label,
        body: _deskBreakBody(type),
        hour: hour,
        minute: minute,
        channel: switch (type) {
          DeskBreakType.eye => NotificationChannel.eye,
          DeskBreakType.kneeMobility => NotificationChannel.knee,
          DeskBreakType.movement || DeskBreakType.neck => NotificationChannel.genericMedium,
        },
        payload: 'deskbreak:${type.name}:$hour:$minute',
      );
    }
    await DeskBreakScheduleHistory.record(type, slots);
  }

  String _deskBreakBody(DeskBreakType type) => switch (type) {
    DeskBreakType.eye => 'Look at something 20 feet away for 20 seconds.',
    DeskBreakType.movement => 'Stand up and move for a few minutes.',
    DeskBreakType.kneeMobility => 'Time for a knee mobility break.',
    DeskBreakType.neck => 'Chin tucks, neck rotations, shoulder rolls.',
  };
}

/// health-plan-source.md §19 "Quiet hours" — a window (typically
/// overnight) during which no reminder should be scheduled, across every
/// category. Loaded once per [ReminderScheduler.rescheduleAll] call
/// rather than re-read per category.
class QuietHoursWindow {
  final bool enabled;
  final int startMinutes;
  final int endMinutes;

  const QuietHoursWindow({
    required this.enabled,
    required this.startMinutes,
    required this.endMinutes,
  });

  static Future<QuietHoursWindow> load() async {
    return QuietHoursWindow(
      enabled: await ReminderPrefs.quietHoursEnabled(),
      startMinutes: await ReminderPrefs.quietHoursStartMinutes(),
      endMinutes: await ReminderPrefs.quietHoursEndMinutes(),
    );
  }

  /// True if [minutesSinceMidnight] falls within the quiet-hours window.
  /// Handles the overnight-wraparound case (start > end, e.g. 21:30-6:00)
  /// as well as a same-day window (start < end).
  bool contains(int minutesSinceMidnight) {
    if (!enabled) return false;
    if (startMinutes == endMinutes) return false;
    if (startMinutes < endMinutes) {
      return minutesSinceMidnight >= startMinutes && minutesSinceMidnight < endMinutes;
    }
    return minutesSinceMidnight >= startMinutes || minutesSinceMidnight < endMinutes;
  }
}
