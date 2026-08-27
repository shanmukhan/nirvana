import 'package:sqflite/sqflite.dart';

import '../../domain/entities.dart';
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
    final rows = await _db.query(
      'dhyana_session',
      orderBy: 'date DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<DhyanaSession>> forDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
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
    final sessions = await recent(limit: 400);
    if (sessions.isEmpty) return 0;
    final daysWithSession = sessions
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();

    var cursor = DateTime.now();
    var cursorDay = DateTime(cursor.year, cursor.month, cursor.day);
    if (!daysWithSession.contains(cursorDay)) {
      cursorDay = cursorDay.subtract(const Duration(days: 1));
      if (!daysWithSession.contains(cursorDay)) return 0;
    }

    var streak = 0;
    while (daysWithSession.contains(cursorDay)) {
      streak++;
      cursorDay = cursorDay.subtract(const Duration(days: 1));
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
}
