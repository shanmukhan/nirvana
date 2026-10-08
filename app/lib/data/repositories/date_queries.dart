import 'package:sqflite/sqflite.dart';

import '../../domain/calendar_days.dart';

/// Table/column names are internal constants supplied by repositories.
Future<List<Map<String, Object?>>> queryDateRange(
  DatabaseExecutor db,
  String table,
  String column,
  DateTime start,
  DateTime end,
) => db.query(
  table,
  where: '$column >= ? AND $column < ?',
  whereArgs: [start.toIso8601String(), end.toIso8601String()],
  orderBy: '$column ASC',
);

Future<Set<String>> daysWithRecords(
  DatabaseExecutor db,
  String table,
  String column,
  int days, {
  DateTime? now,
}) async {
  RangeError.checkValueInInterval(days, 1, 3660, 'days');
  final today = startOfDay(now ?? DateTime.now());
  final rows = await db.rawQuery(
    'SELECT DISTINCT substr($column, 1, 10) AS day FROM $table WHERE $column >= ? AND $column < ?',
    [
      calendarDayOffset(today, 1 - days).toIso8601String(),
      calendarDayOffset(today, 1).toIso8601String(),
    ],
  );
  return rows.map((row) => row['day'] as String).toSet();
}
