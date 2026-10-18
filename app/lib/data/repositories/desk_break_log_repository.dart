import 'package:sqflite/sqflite.dart';

import '../../domain/calendar_days.dart';
import '../../domain/stored_dates.dart';
import '../../services/desk_break_schedule_history.dart';
import '../../services/reminder_prefs.dart';
import 'id_generator.dart';

enum DeskBreakLogStatus { done, skipped, autoMissed, unanswered }

class DeskBreakLogEntry {
  final String id;
  final DeskBreakType type;
  final DateTime logDate;
  final int slotHour;
  final int slotMinute;
  final DeskBreakLogStatus status;
  final DateTime firedAt;
  final DateTime? respondedAt;

  const DeskBreakLogEntry({
    required this.id,
    required this.type,
    required this.logDate,
    required this.slotHour,
    required this.slotMinute,
    required this.status,
    required this.firedAt,
    this.respondedAt,
  });
}

String _dateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// Adherence log for desk-break notifications (health-plan-source.md §4).
///
/// A user response ("done"/"skipped") is recorded when they tap a desk-break
/// notification and answer the yes/no prompt. There is no reliable
/// cross-platform delivery receipt for a scheduled local notification. The app
/// therefore reconciles recorded schedule revisions lazily, inserting an
/// `unanswered` row once a slot is more than [autoMissAfter] in the past.
/// An unanswered slot is not evidence that the user received or missed a nudge.
class DeskBreakLogRepository {
  final Database _db;

  DeskBreakLogRepository(this._db);

  static const autoMissAfter = Duration(minutes: 10);

  Future<void> recordResponse({
    required DeskBreakType type,
    required int slotHour,
    required int slotMinute,
    required DeskBreakLogStatus status,
    required DateTime logDate,
  }) async {
    RangeError.checkValueInInterval(slotHour, 0, 23, 'slotHour');
    RangeError.checkValueInInterval(slotMinute, 0, 59, 'slotMinute');
    final day = logDate;
    final firedAt = DateTime(day.year, day.month, day.day, slotHour, slotMinute);
    await _db.transaction((txn) async {
      final row = <String, Object?>{
        'id': newId(),
        'desk_break_type': type.name,
        'log_date': _dateKey(day),
        'slot_hour': slotHour,
        'slot_minute': slotMinute,
        'status': status.name,
        'fired_at': localTimestamp(firedAt),
        'responded_at': DateTime.now().toIso8601String(),
      };
      await txn.insert('desk_break_log', row, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'desk_break_log',
        {'status': status.name, 'responded_at': row['responded_at']},
        where: 'desk_break_type = ? AND log_date = ? AND slot_hour = ? AND slot_minute = ?',
        whereArgs: [type.name, _dateKey(day), slotHour, slotMinute],
      );
    });
  }

  /// Lazily reconciles historical schedules. Delivery remains unknown.
  Future<void> sweepScheduledOccurrences(
    List<DeskBreakScheduleRevision> revisions, {
    DateTime? now,
    int days = 7,
  }) async {
    final current = now ?? DateTime.now();
    final today = startOfDay(current);
    final batch = _db.batch();
    var any = false;
    for (final type in DeskBreakType.values) {
      final history = revisions.where((r) => r.type == type).toList()
        ..sort((a, b) => a.effectiveAt.compareTo(b.effectiveAt));
      for (var index = 0; index < history.length; index++) {
        final entry = history[index];
        final until = index + 1 < history.length ? history[index + 1].effectiveAt : current;
        for (var offset = 1 - days; offset <= 0; offset++) {
          final day = calendarDayOffset(today, offset);
          for (final (hour, minute) in entry.slots) {
            final slotTime = DateTime(day.year, day.month, day.day, hour, minute);
            if (slotTime.isBefore(entry.effectiveAt) ||
                !slotTime.isBefore(until) ||
                slotTime.isAfter(current.subtract(autoMissAfter))) {
              continue;
            }
            any = true;
            batch.insert('desk_break_log', {
              'id': newId(),
              'desk_break_type': type.name,
              'log_date': _dateKey(day),
              'slot_hour': hour,
              'slot_minute': minute,
              'status': DeskBreakLogStatus.unanswered.name,
              'fired_at': localTimestamp(slotTime),
              'responded_at': null,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
      }
    }
    if (any) await batch.commit(noResult: true);
  }

  /// Logged responses for [day], newest first — used by the Progress
  /// screen's "Today's progress" timeline.
  Future<List<DeskBreakLogEntry>> forDay(DateTime day) async {
    final rows = await _db.query(
      'desk_break_log',
      where: 'log_date = ?',
      whereArgs: [_dateKey(day)],
      orderBy: 'fired_at DESC',
    );
    return rows
        .map(
          (row) => DeskBreakLogEntry(
            id: row['id'] as String,
            type: DeskBreakType.values.byName(row['desk_break_type'] as String),
            logDate: day,
            slotHour: row['slot_hour'] as int,
            slotMinute: row['slot_minute'] as int,
            status: DeskBreakLogStatus.values.byName(row['status'] as String),
            firedAt: DateTime.parse(row['fired_at'] as String),
            respondedAt: row['responded_at'] == null
                ? null
                : DateTime.parse(row['responded_at'] as String),
          ),
        )
        .toList();
  }

  /// Per-type counts of done/skipped/autoMissed over the last [days] days
  /// (today inclusive), for the Desk Breaks adherence summary.
  Future<Map<DeskBreakType, Map<DeskBreakLogStatus, int>>> adherenceSummary(int days) async {
    RangeError.checkValueInInterval(days, 1, 3660, 'days');
    final today = DateTime.now();
    final start = calendarDayOffset(today, 1 - days);
    final rows = await _db.rawQuery(
      'SELECT desk_break_type, status, COUNT(*) AS count FROM desk_break_log '
      'WHERE log_date >= ? AND log_date < ? GROUP BY desk_break_type, status',
      [_dateKey(start), _dateKey(calendarDayOffset(today, 1))],
    );
    final summary = <DeskBreakType, Map<DeskBreakLogStatus, int>>{
      for (final type in DeskBreakType.values)
        type: {for (final status in DeskBreakLogStatus.values) status: 0},
    };
    for (final row in rows) {
      final type = DeskBreakType.values.byName(row['desk_break_type'] as String);
      final status = DeskBreakLogStatus.values.byName(row['status'] as String);
      summary[type]![status] = row['count'] as int;
    }
    return summary;
  }
}
