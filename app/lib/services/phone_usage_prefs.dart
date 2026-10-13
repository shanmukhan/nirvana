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
  static const _lastWarnedSessionKey = 'phone_usage_last_warned_session_epoch_ms';

  static const defaultThresholdMinutes = 15;
  static const defaultSnoozeMinutes = 15;

  /// Each isolate has its own cache; refresh before background decisions.
  static Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  }

  static Future<int> _getMinutes(String key, int fallback) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(key);
    return value is int && value >= 5 && value <= 60 ? value : fallback;
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(_enabledKey);
    return value is bool ? value : true;
  }

  static Future<bool> hasWarnedFor(DateTime sessionStart) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastWarnedSessionKey) == sessionStart.millisecondsSinceEpoch;
  }

  static Future<void> markWarned(DateTime sessionStart) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastWarnedSessionKey, sessionStart.millisecondsSinceEpoch);
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  static Future<int> thresholdMinutes() async {
    return _getMinutes(_thresholdMinutesKey, defaultThresholdMinutes);
  }

  static Future<void> setThresholdMinutes(int minutes) async {
    RangeError.checkValueInInterval(minutes, 5, 60, 'minutes');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_thresholdMinutesKey, minutes);
  }

  static Future<int> snoozeMinutes() async {
    return _getMinutes(_snoozeMinutesKey, defaultSnoozeMinutes);
  }

  static Future<void> setSnoozeMinutes(int minutes) async {
    RangeError.checkValueInInterval(minutes, 5, 60, 'minutes');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_snoozeMinutesKey, minutes);
  }

  static Future<DateTime?> snoozedUntil() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.get(_snoozedUntilKey);
    return ms is int && ms >= 0 && ms <= 8640000000000000
        ? DateTime.fromMillisecondsSinceEpoch(ms)
        : null;
  }

  static Future<void> snoozeFor(Duration duration) async {
    if (duration.inMilliseconds <= 0) {
      throw ArgumentError('Snooze must be greater than zero.');
    }
    final prefs = await SharedPreferences.getInstance();
    final until = DateTime.now().add(duration);
    await prefs.setInt(_snoozedUntilKey, until.millisecondsSinceEpoch);
  }
}
