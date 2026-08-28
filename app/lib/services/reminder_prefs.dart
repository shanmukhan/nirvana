import 'package:shared_preferences/shared_preferences.dart';

/// Persisted per-category reminder settings, edited from Settings and read
/// by [ReminderScheduler] to (re)schedule local notifications.
///
/// Stored via SharedPreferences rather than the RoutineConfig/sqflite row —
/// same rationale as [PhoneUsagePrefs]: nothing here needs a background
/// isolate today, but keeping every reminder setting in one simple,
/// synchronously-readable store avoids mixing two persistence layers for
/// what is conceptually one "Reminders" settings page. Defaults mirror
/// [RoutineConfig]'s built-in defaults. See PROJECT_PLAN.md §6/§7.
class ReminderPrefs {
  ReminderPrefs._();

  // Water
  static const _waterEnabledKey = 'reminder_water_enabled';
  static const _waterIntervalKey = 'reminder_water_interval_minutes';
  static const _waterFromKey = 'reminder_water_from_minutes';
  static const _waterToKey = 'reminder_water_to_minutes';

  // Dhyana
  static const _dhyanaEnabledKey = 'reminder_dhyana_enabled';
  static const _dhyanaTimeKey = 'reminder_dhyana_time_minutes';

  // Knee check-in
  static const _kneeEnabledKey = 'reminder_knee_enabled';
  static const _kneeTimeKey = 'reminder_knee_time_minutes';

  // Weight check-in
  static const _weightEnabledKey = 'reminder_weight_enabled';
  static const _weightTimeKey = 'reminder_weight_time_minutes';

  // Desk breaks: eye / movement / knee mobility / neck
  static const _deskFromKey = 'reminder_desk_from_minutes';
  static const _deskToKey = 'reminder_desk_to_minutes';

  // Quiet hours (health-plan-source.md §19) — suppresses every reminder
  // category (water, desk breaks, dhyana, knee/weight check-ins) whose
  // computed time falls inside this window. See ReminderScheduler.
  static const _quietHoursEnabledKey = 'reminder_quiet_hours_enabled';
  static const _quietHoursStartKey = 'reminder_quiet_hours_start_minutes';
  static const _quietHoursEndKey = 'reminder_quiet_hours_end_minutes';

  static const defaultWaterIntervalMinutes = 120;
  static const defaultWaterFromMinutes = 6 * 60;
  static const defaultWaterToMinutes = 21 * 60;
  static const defaultDhyanaTimeMinutes = 19 * 60;
  static const defaultKneeTimeMinutes = 20 * 60;
  static const defaultWeightTimeMinutes = 7 * 60;
  static const defaultDeskFromMinutes = 8 * 60 + 30;
  static const defaultDeskToMinutes = 18 * 60;
  // Mirrors RoutineConfig's default QuietHoursConfig (21:30-6:00).
  static const defaultQuietHoursStartMinutes = 21 * 60 + 30;
  static const defaultQuietHoursEndMinutes = 6 * 60;

  static Future<bool> _getBool(String key, bool fallback) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? fallback;
  }

  static Future<void> _setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  static Future<int> _getInt(String key, int fallback) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? fallback;
  }

  static Future<void> _setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  // --- Water ---
  static Future<bool> waterEnabled() => _getBool(_waterEnabledKey, true);
  static Future<void> setWaterEnabled(bool v) => _setBool(_waterEnabledKey, v);
  static Future<int> waterIntervalMinutes() =>
      _getInt(_waterIntervalKey, defaultWaterIntervalMinutes);
  static Future<void> setWaterIntervalMinutes(int v) => _setInt(_waterIntervalKey, v);
  static Future<int> waterFromMinutes() => _getInt(_waterFromKey, defaultWaterFromMinutes);
  static Future<void> setWaterFromMinutes(int v) => _setInt(_waterFromKey, v);
  static Future<int> waterToMinutes() => _getInt(_waterToKey, defaultWaterToMinutes);
  static Future<void> setWaterToMinutes(int v) => _setInt(_waterToKey, v);

  // --- Dhyana ---
  static Future<bool> dhyanaEnabled() => _getBool(_dhyanaEnabledKey, true);
  static Future<void> setDhyanaEnabled(bool v) => _setBool(_dhyanaEnabledKey, v);
  static Future<int> dhyanaTimeMinutes() => _getInt(_dhyanaTimeKey, defaultDhyanaTimeMinutes);
  static Future<void> setDhyanaTimeMinutes(int v) => _setInt(_dhyanaTimeKey, v);

  // --- Knee check-in ---
  static Future<bool> kneeEnabled() => _getBool(_kneeEnabledKey, true);
  static Future<void> setKneeEnabled(bool v) => _setBool(_kneeEnabledKey, v);
  static Future<int> kneeTimeMinutes() => _getInt(_kneeTimeKey, defaultKneeTimeMinutes);
  static Future<void> setKneeTimeMinutes(int v) => _setInt(_kneeTimeKey, v);

  // --- Weight check-in ---
  static Future<bool> weightEnabled() => _getBool(_weightEnabledKey, true);
  static Future<void> setWeightEnabled(bool v) => _setBool(_weightEnabledKey, v);
  static Future<int> weightTimeMinutes() => _getInt(_weightTimeKey, defaultWeightTimeMinutes);
  static Future<void> setWeightTimeMinutes(int v) => _setInt(_weightTimeKey, v);

  // --- Desk breaks (eye / movement / knee mobility / neck) ---
  static Future<bool> deskBreakEnabled(DeskBreakType type) =>
      _getBool('reminder_desk_${type.name}_enabled', true);
  static Future<void> setDeskBreakEnabled(DeskBreakType type, bool v) =>
      _setBool('reminder_desk_${type.name}_enabled', v);
  static Future<int> deskBreakIntervalMinutes(DeskBreakType type) =>
      _getInt('reminder_desk_${type.name}_interval_minutes', type.defaultIntervalMinutes);
  static Future<void> setDeskBreakIntervalMinutes(DeskBreakType type, int v) =>
      _setInt('reminder_desk_${type.name}_interval_minutes', v);

  static Future<int> deskFromMinutes() => _getInt(_deskFromKey, defaultDeskFromMinutes);
  static Future<void> setDeskFromMinutes(int v) => _setInt(_deskFromKey, v);
  static Future<int> deskToMinutes() => _getInt(_deskToKey, defaultDeskToMinutes);
  static Future<void> setDeskToMinutes(int v) => _setInt(_deskToKey, v);

  // --- Quiet hours ---
  static Future<bool> quietHoursEnabled() => _getBool(_quietHoursEnabledKey, true);
  static Future<void> setQuietHoursEnabled(bool v) => _setBool(_quietHoursEnabledKey, v);
  static Future<int> quietHoursStartMinutes() =>
      _getInt(_quietHoursStartKey, defaultQuietHoursStartMinutes);
  static Future<void> setQuietHoursStartMinutes(int v) => _setInt(_quietHoursStartKey, v);
  static Future<int> quietHoursEndMinutes() =>
      _getInt(_quietHoursEndKey, defaultQuietHoursEndMinutes);
  static Future<void> setQuietHoursEndMinutes(int v) => _setInt(_quietHoursEndKey, v);
}

enum DeskBreakType {
  eye('Eye break', 25),
  movement('Movement break', 50),
  kneeMobility('Knee mobility break', 120),
  neck('Neck exercise', 75);

  final String label;
  final int defaultIntervalMinutes;

  const DeskBreakType(this.label, this.defaultIntervalMinutes);
}
