import 'package:sqflite/sqflite.dart';

import '../../domain/calendar_days.dart';
import '../../domain/stored_dates.dart';
import '../../domain/entities.dart';
import '../../domain/log_validation.dart';
import 'id_generator.dart';

class WaterRepository {
  final Database _db;

  WaterRepository(this._db);

  Future<WaterEntry> log(int amountMl, {DateTime? loggedAt}) async {
    requirePositiveNumber(amountMl, 'amountMl');
    final entry = WaterEntry(id: newId(), loggedAt: loggedAt ?? DateTime.now(), amountMl: amountMl);
    await _db.insert('water_entry', {
      'id': entry.id,
      'logged_at': localTimestamp(entry.loggedAt),
      'amount_ml': entry.amountMl,
    });
    return entry;
  }

  Future<List<WaterEntry>> forDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = calendarDayOffset(start, 1);
    final rows = await _db.query(
      'water_entry',
      where: 'logged_at >= ? AND logged_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'logged_at DESC',
    );
    return rows
        .map(
          (row) => WaterEntry(
            id: row['id'] as String,
            loggedAt: DateTime.parse(row['logged_at'] as String),
            amountMl: row['amount_ml'] as int,
          ),
        )
        .toList();
  }

  Future<int> totalMlForDay(DateTime day) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount_ml), 0) AS total FROM water_entry WHERE logged_at >= ? AND logged_at < ?',
      [startOfDay(day).toIso8601String(), calendarDayOffset(day, 1).toIso8601String()],
    );
    return rows.first['total'] as int;
  }

  /// Query backward in small windows until the first day below the current goal.
  Future<int> currentStreakDays({required int goalMl, DateTime? now}) async {
    requirePositiveNumber(goalMl, 'goalMl');
    var cursor = startOfDay(now ?? DateTime.now());
    var streak = 0;
    var first = true;
    while (true) {
      final totals = (await dailyTotalsForLastDays(30, now: cursor)).reversed.toList();
      for (var index = 0; index < totals.length; index++) {
        final total = totals[index].value;
        if (first && index == 0 && total < goalMl) continue;
        if (total < goalMl) return streak;
        streak++;
      }
      first = false;
      cursor = calendarDayOffset(cursor, -30);
    }
  }

  /// Total ml per day for the [days] days ending today (oldest first) —
  /// used for the weekly hydration consistency chart/streak on the Water
  /// screen. A single ranged query rather than N calls to [forDay].
  Future<List<MapEntry<DateTime, int>>> dailyTotalsForLastDays(int days, {DateTime? now}) async {
    RangeError.checkValueInInterval(days, 1, 3660, 'days');
    final today = startOfDay(now ?? DateTime.now());
    final start = calendarDayOffset(today, 1 - days);
    final rows = await _db.rawQuery(
      'SELECT substr(logged_at, 1, 10) AS day, SUM(amount_ml) AS total FROM water_entry '
      'WHERE logged_at >= ? AND logged_at < ? GROUP BY substr(logged_at, 1, 10)',
      [start.toIso8601String(), calendarDayOffset(today, 1).toIso8601String()],
    );
    final totals = {for (final row in rows) row['day'] as String: row['total'] as int};
    return [
      for (var i = 0; i < days; i++)
        MapEntry(
          calendarDayOffset(start, i),
          totals[calendarDateKey(calendarDayOffset(start, i))] ?? 0,
        ),
    ];
  }
}
