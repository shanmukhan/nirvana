import 'package:shared_preferences/shared_preferences.dart';

/// Persisted settings for the continuous-phone-usage warning
/// (see [PhoneUsageConfig] in lib/domain/routine_config.dart for the
/// shape/defaults this mirrors).
///
/// Stored via SharedPreferences rather than the RoutineConfig/sqflite
/// row because the background WorkManager isolate that evaluates the
/// warning has no Riverpod/DB context — SharedPreferences is readable
/// from both the main and background isolates with no extra wiring.
/// Once the full RoutineConfig editor lands (PROJECT_PLAN.md Phase 3)
/// this can move there.
class PhoneUsagePrefs {
  static const _enabledKey = 'phone_usage_enabled';
  static const _thresholdMinutesKey = 'phone_usage_threshold_minutes';
  static const _snoozeMinutesKey = 'phone_usage_snooze_minutes';
  static const _snoozedUntilKey = 'phone_usage_snoozed_until_epoch_ms';

  static const defaultThresholdMinutes = 15;
  static const defaultSnoozeMinutes = 15;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  static Future<int> thresholdMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_thresholdMinutesKey) ?? defaultThresholdMinutes;
  }

  static Future<void> setThresholdMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_thresholdMinutesKey, minutes);
  }

  static Future<int> snoozeMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_snoozeMinutesKey) ?? defaultSnoozeMinutes;
  }

  static Future<void> setSnoozeMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_snoozeMinutesKey, minutes);
  }

  static Future<DateTime?> snoozedUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_snoozedUntilKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<void> snoozeFor(Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(duration);
    await prefs.setInt(_snoozedUntilKey, until.millisecondsSinceEpoch);
  }
}
