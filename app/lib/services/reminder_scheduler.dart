import 'notification_service.dart';
import 'reminder_prefs.dart';

/// Turns [ReminderPrefs] into scheduled local notifications. Call
/// [rescheduleAll] on app start and any time a reminder setting changes
/// from Settings — it cancels and re-lays every id this service owns, so
/// it's always safe to call in full rather than diffing.
///
/// Each category gets a fixed id range so re-scheduling is idempotent:
///   1000-1029  water              2000        dhyana
///   3000-3029  eye break          3100-3129   movement break
///   3200-3229  knee mobility      3300-3329   neck exercise
///   4000       knee check-in      5000        weight check-in
/// Interval-based categories (water, desk breaks) are expanded into one
/// fixed daily clock-time notification per slot across the active window,
/// rather than a true periodic timer — flutter_local_notifications has no
/// arbitrary-interval repeat, and daily fixed-time notifications work
/// reliably in the background without needing a WorkManager isolate.
class ReminderScheduler {
  ReminderScheduler._();

  static final ReminderScheduler instance = ReminderScheduler._();

  static const _waterIdBase = 1000;
  static const _dhyanaId = 2000;
  static const _kneeCheckinId = 4000;
  static const _weightCheckinId = 5000;
  static const _maxSlotsPerCategory = 30;

  static const Map<DeskBreakType, int> _deskBreakIdBase = {
    DeskBreakType.eye: 3000,
    DeskBreakType.movement: 3100,
    DeskBreakType.kneeMobility: 3200,
    DeskBreakType.neck: 3300,
  };

  Future<void> rescheduleAll() async {
    await _cancelRange(_waterIdBase, _maxSlotsPerCategory);
    await NotificationService.instance.cancel(_dhyanaId);
    await NotificationService.instance.cancel(_kneeCheckinId);
    await NotificationService.instance.cancel(_weightCheckinId);
    for (final base in _deskBreakIdBase.values) {
      await _cancelRange(base, _maxSlotsPerCategory);
    }

    final quietHours = await _QuietHours.load();

    await _scheduleWater(quietHours);
    await _scheduleDhyana(quietHours);
    await _scheduleKneeCheckin(quietHours);
    await _scheduleWeightCheckin(quietHours);
    for (final type in DeskBreakType.values) {
      await _scheduleDeskBreak(type, quietHours);
    }
  }

  Future<void> _cancelRange(int base, int count) async {
    for (var i = 0; i < count; i++) {
      await NotificationService.instance.cancel(base + i);
    }
  }

  /// Every [hour]:[minute] pair from [fromMinutes] to [toMinutes] stepping
  /// by [intervalMinutes], capped at [_maxSlotsPerCategory] slots, minus
  /// any that fall inside [quietHours].
  List<(int hour, int minute)> _dailySlots({
    required int fromMinutes,
    required int toMinutes,
    required int intervalMinutes,
    required _QuietHours quietHours,
  }) {
    final slots = <(int, int)>[];
    if (intervalMinutes <= 0 || toMinutes <= fromMinutes) return slots;
    for (
      var minutes = fromMinutes;
      minutes <= toMinutes && slots.length < _maxSlotsPerCategory;
      minutes += intervalMinutes
    ) {
      if (quietHours.contains(minutes)) continue;
      slots.add((minutes ~/ 60, minutes % 60));
    }
    return slots;
  }

  Future<void> _scheduleWater(_QuietHours quietHours) async {
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
        priority: NotificationPriorityTier.high,
      );
    }
  }

  Future<void> _scheduleDhyana(_QuietHours quietHours) async {
    if (!await ReminderPrefs.dhyanaEnabled()) return;
    final minutes = await ReminderPrefs.dhyanaTimeMinutes();
    if (quietHours.contains(minutes)) return;
    await NotificationService.instance.scheduleDaily(
      id: _dhyanaId,
      title: 'Dhyana time',
      body: 'A few quiet minutes for your practice.',
      hour: minutes ~/ 60,
      minute: minutes % 60,
      priority: NotificationPriorityTier.medium,
    );
  }

  Future<void> _scheduleKneeCheckin(_QuietHours quietHours) async {
    if (!await ReminderPrefs.kneeEnabled()) return;
    final minutes = await ReminderPrefs.kneeTimeMinutes();
    if (quietHours.contains(minutes)) return;
    await NotificationService.instance.scheduleDaily(
      id: _kneeCheckinId,
      title: 'Knee check-in',
      body: 'How does your knee feel today? Log pain, swelling, and stiffness.',
      hour: minutes ~/ 60,
      minute: minutes % 60,
      priority: NotificationPriorityTier.medium,
    );
  }

  Future<void> _scheduleWeightCheckin(_QuietHours quietHours) async {
    if (!await ReminderPrefs.weightEnabled()) return;
    final minutes = await ReminderPrefs.weightTimeMinutes();
    if (quietHours.contains(minutes)) return;
    await NotificationService.instance.scheduleDaily(
      id: _weightCheckinId,
      title: 'Weigh-in reminder',
      body: 'Log today\'s weight to keep your trend up to date.',
      hour: minutes ~/ 60,
      minute: minutes % 60,
      priority: NotificationPriorityTier.low,
    );
  }

  Future<void> _scheduleDeskBreak(DeskBreakType type, _QuietHours quietHours) async {
    if (!await ReminderPrefs.deskBreakEnabled(type)) return;
    final slots = _dailySlots(
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
        priority: type == DeskBreakType.eye
            ? NotificationPriorityTier.low
            : NotificationPriorityTier.medium,
      );
    }
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
class _QuietHours {
  final bool enabled;
  final int startMinutes;
  final int endMinutes;

  const _QuietHours({required this.enabled, required this.startMinutes, required this.endMinutes});

  static Future<_QuietHours> load() async {
    return _QuietHours(
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
