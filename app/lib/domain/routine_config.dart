/// Every configurable time/interval/target in the app lives here, not hard-coded
/// in a screen or notification handler. See PROJECT_PLAN.md §3.
library;

/// A single point in a daily schedule, e.g. "6:00 AM".
class TimeOfDayConfig {
  final int hour;
  final int minute;

  const TimeOfDayConfig(this.hour, this.minute);

  factory TimeOfDayConfig.fromMinutesSinceMidnight(int minutes) =>
      TimeOfDayConfig(minutes ~/ 60, minutes % 60);

  int get minutesSinceMidnight => hour * 60 + minute;

  Map<String, dynamic> toMap() => {'hour': hour, 'minute': minute};

  factory TimeOfDayConfig.fromMap(Map<String, dynamic> map) =>
      TimeOfDayConfig(map['hour'] as int, map['minute'] as int);
}

/// A single scheduled hydration prompt with a target volume range.
class HydrationSlot {
  final TimeOfDayConfig time;
  final int minMl;
  final int maxMl;

  const HydrationSlot({
    required this.time,
    required this.minMl,
    required this.maxMl,
  });
}

class HydrationConfig {
  final int dailyGoalMl;
  final List<HydrationSlot> slots;
  final List<int> quickLogAmountsMl;

  const HydrationConfig({
    this.dailyGoalMl = 2250,
    this.slots = const [
      HydrationSlot(time: TimeOfDayConfig(6, 0), minMl: 300, maxMl: 500),
      HydrationSlot(time: TimeOfDayConfig(7, 30), minMl: 250, maxMl: 250),
      HydrationSlot(time: TimeOfDayConfig(9, 30), minMl: 250, maxMl: 250),
      HydrationSlot(time: TimeOfDayConfig(11, 30), minMl: 250, maxMl: 250),
      HydrationSlot(time: TimeOfDayConfig(13, 0), minMl: 250, maxMl: 300),
      HydrationSlot(time: TimeOfDayConfig(15, 0), minMl: 250, maxMl: 250),
      HydrationSlot(time: TimeOfDayConfig(17, 0), minMl: 250, maxMl: 250),
      HydrationSlot(time: TimeOfDayConfig(19, 0), minMl: 250, maxMl: 250),
      HydrationSlot(time: TimeOfDayConfig(20, 30), minMl: 150, maxMl: 250),
    ],
    this.quickLogAmountsMl = const [150, 250, 300, 500],
  });
}

/// Repeating interval-based desk break (eye, movement, knee mobility, posture).
class DeskBreakConfig {
  final bool enabled;
  final int intervalMinutes;
  final int durationMinutes;
  final TimeOfDayConfig activeFrom;
  final TimeOfDayConfig activeTo;

  const DeskBreakConfig({
    required this.enabled,
    required this.intervalMinutes,
    required this.durationMinutes,
    this.activeFrom = const TimeOfDayConfig(8, 30),
    this.activeTo = const TimeOfDayConfig(18, 0),
  });
}

class DeskBreaksConfig {
  final DeskBreakConfig eyeBreak;
  final DeskBreakConfig movementBreak;
  final DeskBreakConfig kneeMobilityBreak;
  final DeskBreakConfig postureBreak;

  const DeskBreaksConfig({
    this.eyeBreak = const DeskBreakConfig(
      enabled: true,
      intervalMinutes: 25,
      durationMinutes: 1,
    ),
    this.movementBreak = const DeskBreakConfig(
      enabled: true,
      intervalMinutes: 50,
      durationMinutes: 4,
    ),
    this.kneeMobilityBreak = const DeskBreakConfig(
      enabled: true,
      intervalMinutes: 120,
      durationMinutes: 4,
    ),
    this.postureBreak = const DeskBreakConfig(
      enabled: true,
      intervalMinutes: 75,
      durationMinutes: 4,
    ),
  });
}

enum DhyanaPracticeType { breathAwareness, bodyScan, mantra }

class DhyanaSessionConfig {
  final bool enabled;
  final TimeOfDayConfig time;
  final int durationMinutes;
  final DhyanaPracticeType defaultPractice;

  const DhyanaSessionConfig({
    required this.enabled,
    required this.time,
    required this.durationMinutes,
    this.defaultPractice = DhyanaPracticeType.breathAwareness,
  });
}

class DhyanaConfig {
  final DhyanaSessionConfig primarySession;
  final DhyanaSessionConfig secondarySession;
  final DhyanaSessionConfig weekendSession;

  const DhyanaConfig({
    this.primarySession = const DhyanaSessionConfig(
      enabled: true,
      time: TimeOfDayConfig(19, 0),
      durationMinutes: 10,
    ),
    this.secondarySession = const DhyanaSessionConfig(
      enabled: false,
      time: TimeOfDayConfig(11, 0),
      durationMinutes: 4,
    ),
    this.weekendSession = const DhyanaSessionConfig(
      enabled: true,
      time: TimeOfDayConfig(19, 0),
      durationMinutes: 17,
    ),
  });
}

enum Weekday { mon, tue, wed, thu, fri, sat, sun }

class StrengthSessionConfig {
  final TimeOfDayConfig time;
  final Set<Weekday> days;

  const StrengthSessionConfig({
    this.time = const TimeOfDayConfig(18, 0),
    this.days = const {Weekday.mon, Weekday.wed, Weekday.fri},
  });
}

class MorningWalkConfig {
  final bool enabled;
  final TimeOfDayConfig time;
  final int targetMinutes;

  const MorningWalkConfig({
    this.enabled = true,
    this.time = const TimeOfDayConfig(6, 15),
    this.targetMinutes = 20,
  });
}

class ExerciseScheduleConfig {
  final MorningWalkConfig morningWalk;
  final StrengthSessionConfig strengthSession;

  const ExerciseScheduleConfig({
    this.morningWalk = const MorningWalkConfig(),
    this.strengthSession = const StrengthSessionConfig(),
  });
}

class QuietHoursConfig {
  final TimeOfDayConfig start;
  final TimeOfDayConfig end;

  const QuietHoursConfig({
    this.start = const TimeOfDayConfig(21, 30),
    this.end = const TimeOfDayConfig(6, 0),
  });
}

/// Weekday vs weekend schedules differ; notifications respect quiet hours
/// and priority tiers. See PROJECT_PLAN.md §6 / health-plan-source.md §19.
class NotificationConfig {
  final QuietHoursConfig quietHours;
  final QuietHoursConfig quietHoursWeekend;
  final int defaultSnoozeMinutes;

  const NotificationConfig({
    this.quietHours = const QuietHoursConfig(),
    this.quietHoursWeekend = const QuietHoursConfig(
      start: TimeOfDayConfig(22, 0),
      end: TimeOfDayConfig(7, 0),
    ),
    this.defaultSnoozeMinutes = 15,
  });
}

/// The single record holding every configurable time/interval/target in
/// the app. One row per user profile; edited from the Settings screen.
class RoutineConfig {
  final String id;
  final HydrationConfig hydration;
  final DeskBreaksConfig deskBreaks;
  final DhyanaConfig dhyana;
  final ExerciseScheduleConfig exerciseSchedule;
  final NotificationConfig notifications;
  final TimeOfDayConfig wakeTime;
  final TimeOfDayConfig sleepTime;

  const RoutineConfig({
    required this.id,
    this.hydration = const HydrationConfig(),
    this.deskBreaks = const DeskBreaksConfig(),
    this.dhyana = const DhyanaConfig(),
    this.exerciseSchedule = const ExerciseScheduleConfig(),
    this.notifications = const NotificationConfig(),
    this.wakeTime = const TimeOfDayConfig(6, 0),
    this.sleepTime = const TimeOfDayConfig(22, 0),
  });
}
