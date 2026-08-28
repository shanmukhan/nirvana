import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:permission_handler/permission_handler.dart' show Permission;

/// Exempts Nirvana from OS-level battery optimization, so scheduled
/// reminder notifications (see reminder_scheduler.dart) aren't silently
/// dropped by aggressive OEM battery managers — Motorola's in particular
/// is known to kill background apps and swallow notifications even when
/// the underlying AlarmManager alarm fires on time. Exposed as a button
/// in Settings rather than requested automatically, since it's a
/// disruptive system dialog best shown with context.
class BatteryOptimizationService {
  BatteryOptimizationService._();

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// True once the user has exempted the app (or the platform doesn't
  /// apply battery optimization to begin with, e.g. non-Android).
  static Future<bool> isExempted() async {
    if (!_supported) return true;
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Opens the system "ignore battery optimizations" prompt for this app.
  static Future<bool> requestExemption() async {
    if (!_supported) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// Opens the app's system Settings page — fallback for the cases the
  /// direct exemption dialog can't reach (e.g. notification channel
  /// toggles, or an OEM "autostart"/background-activity switch that has
  /// no standard Android API).
  static Future<void> openSystemAppSettings() => ph.openAppSettings();
}
