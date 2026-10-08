import 'package:sqflite/sqflite.dart';

import '../../domain/calendar_days.dart';
import '../../domain/entities.dart';
import '../../domain/log_validation.dart';
import 'date_queries.dart';
import 'id_generator.dart';

class DhyanaRepository {
  final Database _db;

  DhyanaRepository(this._db);

  Future<DhyanaSession> logSession({
    required int plannedDurationMin,
    required int actualDurationMin,
    required DhyanaPractice practiceType,
    int? moodBefore1to5,
    int? moodAfter1to5,
    String? notes,
    DateTime? date,
  }) async {
    requirePositiveNumber(plannedDurationMin, 'plannedDurationMin');
    requirePositiveNumber(actualDurationMin, 'actualDurationMin');
    requireRating(moodBefore1to5, 'moodBefore1to5', min: 1, max: 5);
    requireRating(moodAfter1to5, 'moodAfter1to5', min: 1, max: 5);
    final session = DhyanaSession(
      id: newId(),
      date: date ?? DateTime.now(),
      plannedDurationMin: plannedDurationMin,
      actualDurationMin: actualDurationMin,
      practiceType: practiceType,
      moodBefore1to5: moodBefore1to5,
      moodAfter1to5: moodAfter1to5,
      notes: notes,
    );
    await _db.insert('dhyana_session', _toRow(session));
    return session;
  }

  Future<List<DhyanaSession>> recent({int limit = 60}) async {
    final rows = await _db.query('dhyana_session', orderBy: 'date DESC', limit: limit);
    return rows.map(_fromRow).toList();
  }

  Future<List<DhyanaSession>> forDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = calendarDayOffset(start, 1);
    final rows = await _db.query(
      'dhyana_session',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Consecutive days (ending today or yesterday) with at least one session.
  /// A missed day just ends the streak — no punitive copy anywhere else.
  Future<int> currentStreakDays() async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT substr(date, 1, 10) AS day FROM dhyana_session',
    );
    final daysWithSession = rows.map((row) => DateTime.parse(row['day'] as String)).toSet();

    var cursor = DateTime.now();
    var cursorDay = DateTime(cursor.year, cursor.month, cursor.day);
    if (!daysWithSession.contains(cursorDay)) {
      cursorDay = calendarDayOffset(cursorDay, -1);
      if (!daysWithSession.contains(cursorDay)) return 0;
    }

    var streak = 0;
    while (daysWithSession.contains(cursorDay)) {
      streak++;
      cursorDay = calendarDayOffset(cursorDay, -1);
    }
    return streak;
  }

  Map<String, dynamic> _toRow(DhyanaSession session) => {
    'id': session.id,
    'date': session.date.toIso8601String(),
    'planned_duration_min': session.plannedDurationMin,
    'actual_duration_min': session.actualDurationMin,
    'practice_type': session.practiceType.name,
    'mood_before_1_5': session.moodBefore1to5,
    'mood_after_1_5': session.moodAfter1to5,
    'notes': session.notes,
  };

  DhyanaSession _fromRow(Map<String, Object?> row) => DhyanaSession(
    id: row['id'] as String,
    date: DateTime.parse(row['date'] as String),
    plannedDurationMin: row['planned_duration_min'] as int,
    actualDurationMin: row['actual_duration_min'] as int,
    practiceType: DhyanaPractice.values.byName(row['practice_type'] as String),
    moodBefore1to5: row['mood_before_1_5'] as int?,
    moodAfter1to5: row['mood_after_1_5'] as int?,
    notes: row['notes'] as String?,
  );

  Future<Set<String>> loggedDays(int days, {DateTime? now}) =>
      daysWithRecords(_db, 'dhyana_session', 'date', days, now: now);

  Future<int> totalMinutesForLastDays(int days, {DateTime? now}) async {
    RangeError.checkValueInInterval(days, 1, 3660, 'days');
    final today = now ?? DateTime.now();
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(actual_duration_min), 0) AS total FROM dhyana_session WHERE date >= ? AND date < ?',
      [
        calendarDayOffset(today, 1 - days).toIso8601String(),
        calendarDayOffset(today, 1).toIso8601String(),
      ],
    );
    return rows.first['total'] as int;
  }
}
