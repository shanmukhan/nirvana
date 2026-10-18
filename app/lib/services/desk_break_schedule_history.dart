import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/calendar_days.dart';
import 'reminder_prefs.dart';

class DeskBreakScheduleRevision {
  final DeskBreakType type;
  final DateTime effectiveAt;
  final List<(int, int)> slots;
  const DeskBreakScheduleRevision(this.type, this.effectiveAt, this.slots);
}

/// Records what was successfully scheduled, never assuming that it was delivered.
class DeskBreakScheduleHistory {
  static const key = 'desk_break_schedule_history_v1';
  static final revision = ValueNotifier<int>(0);

  static Future<List<DeskBreakScheduleRevision>> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final rows = jsonDecode(prefs.getString(key) ?? '[]') as List;
      return rows.map((raw) {
        final type = DeskBreakType.values.byName(raw['type'] as String);
        final at = DateTime.parse(raw['at'] as String);
        final slots = (raw['slots'] as List).map((s) {
          final hour = s[0] as int;
          final minute = s[1] as int;
          RangeError.checkValueInInterval(hour, 0, 23);
          RangeError.checkValueInInterval(minute, 0, 59);
          return (hour, minute);
        }).toList();
        return DeskBreakScheduleRevision(type, at, slots);
      }).toList()..sort((a, b) => a.effectiveAt.compareTo(b.effectiveAt));
    } catch (_) {
      // Missing/corrupt history is unknown, never evidence of missed breaks.
      return [];
    }
  }

  static Future<void> record(DeskBreakType type, List<(int, int)> slots, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final entries = await load();
    final previous = entries.where((e) => e.type == type).lastOrNull;
    if (previous != null && listEquals(previous.slots, slots)) return;
    entries.add(DeskBreakScheduleRevision(type, at, List.of(slots)));
    final cutoff = calendarDayOffset(at, -14);
    final retained = <DeskBreakScheduleRevision>[];
    for (final type in DeskBreakType.values) {
      final history = entries.where((e) => e.type == type).toList();
      final older = history.where((e) => e.effectiveAt.isBefore(cutoff)).lastOrNull;
      if (older != null) retained.add(older);
      retained.addAll(history.where((e) => !e.effectiveAt.isBefore(cutoff)));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode([
        for (final e in retained)
          {
            'type': e.type.name,
            'at': e.effectiveAt.toIso8601String(),
            'slots': [
              for (final (h, m) in e.slots) [h, m],
            ],
          },
      ]),
    );
    revision.value++;
  }
}
