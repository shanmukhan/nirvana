import 'package:sqflite/sqflite.dart';

import '../../services/reminder_prefs.dart';
import 'id_generator.dart';

enum DeskBreakLogStatus { done, skipped, autoMissed }

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
/// cross-platform way to run code exactly N minutes after a specific local
/// notification fires while the app is killed, so unanswered slots are
/// swept lazily instead: [sweepAutoMissed] is called whenever the app reads
/// adherence data (Desk Breaks screen, log screen) and inserts an
/// `autoMissed` row for any slot whose scheduled time is more than
/// [autoMissAfter] in the past with no existing row.
class DeskBreakLogRepository {
  final Database _db;

  DeskBreakLogRepository(this._db);

  static const autoMissAfter = Duration(minutes: 10);

  Future<void> recordResponse({
    required DeskBreakType type,
    required int slotHour,
    required int slotMinute,
    required DeskBreakLogStatus status,
    DateTime? logDate,
  }) async {
    final day = logDate ?? DateTime.now();
    final firedAt = DateTime(day.year, day.month, day.day, slotHour, slotMinute);
    await _db.insert('desk_break_log', {
      'id': newId(),
      'desk_break_type': type.name,
      'log_date': _dateKey(day),
      'slot_hour': slotHour,
      'slot_minute': slotMinute,
      'status': status.name,
      'fired_at': firedAt.toIso8601String(),
      'responded_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Inserts an `autoMissed` row for every configured slot, for every
  /// enabled desk-break type, whose scheduled time today is more than
  /// [autoMissAfter] in the past and has no existing log row yet.
  Future<void> sweepAutoMissed(
    Map<DeskBreakType, List<(int hour, int minute)>> slotsByType,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final batch = _db.batch();
    var any = false;
    for (final entry in slotsByType.entries) {
      for (final (hour, minute) in entry.value) {
        final slotTime = DateTime(today.year, today.month, today.day, hour, minute);
        if (slotTime.isAfter(now.subtract(autoMissAfter))) continue;
        any = true;
        batch.insert('desk_break_log', {
          'id': newId(),
          'desk_break_type': entry.key.name,
          'log_date': _dateKey(today),
          'slot_hour': hour,
          'slot_minute': minute,
          'status': DeskBreakLogStatus.autoMissed.name,
          'fired_at': slotTime.toIso8601String(),
          'responded_at': null,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(Duration(days: days - 1));
    final rows = await _db.query(
      'desk_break_log',
      where: 'log_date >= ?',
      whereArgs: [_dateKey(start)],
    );
    final summary = <DeskBreakType, Map<DeskBreakLogStatus, int>>{
      for (final type in DeskBreakType.values)
        type: {for (final status in DeskBreakLogStatus.values) status: 0},
    };
    for (final row in rows) {
      final type = DeskBreakType.values.byName(row['desk_break_type'] as String);
      final status = DeskBreakLogStatus.values.byName(row['status'] as String);
      summary[type]![status] = (summary[type]![status] ?? 0) + 1;
    }
    return summary;
  }
}
