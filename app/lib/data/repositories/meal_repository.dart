import 'package:sqflite/sqflite.dart';

import '../../domain/calendar_days.dart';
import '../../domain/entities.dart';
import '../../domain/log_validation.dart';
import 'date_queries.dart';
import 'id_generator.dart';

class MealRepository {
  final Database _db;

  MealRepository(this._db);

  Future<MealEntry> log({
    required MealType mealType,
    required String description,
    double? proteinEstimateG,
    DateTime? loggedAt,
  }) async {
    if (description.trim().isEmpty) {
      throw ArgumentError('Enter a meal description.');
    }
    if (proteinEstimateG != null) {
      requireNonNegativeNumber(proteinEstimateG, 'proteinEstimateG');
    }
    final entry = MealEntry(
      id: newId(),
      loggedAt: loggedAt ?? DateTime.now(),
      mealType: mealType,
      description: description.trim(),
      proteinEstimateG: proteinEstimateG,
    );
    await _db.insert('meal_entry', {
      'id': entry.id,
      'logged_at': entry.loggedAt.toIso8601String(),
      'meal_type': entry.mealType.name,
      'description': entry.description,
      'protein_estimate_g': entry.proteinEstimateG,
    });
    return entry;
  }

  Future<void> delete(String id) => _db.delete('meal_entry', where: 'id = ?', whereArgs: [id]);

  Future<List<MealEntry>> forDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = calendarDayOffset(start, 1);
    final rows = await _db.query(
      'meal_entry',
      where: 'logged_at >= ? AND logged_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'logged_at',
    );
    return rows.map(_fromRow).toList();
  }

  Future<double> totalProteinForDay(DateTime day) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(protein_estimate_g), 0) AS total FROM meal_entry WHERE logged_at >= ? AND logged_at < ?',
      [startOfDay(day).toIso8601String(), calendarDayOffset(day, 1).toIso8601String()],
    );
    return (rows.first['total'] as num).toDouble();
  }

  MealEntry _fromRow(Map<String, Object?> row) => MealEntry(
    id: row['id'] as String,
    loggedAt: DateTime.parse(row['logged_at'] as String),
    mealType: MealType.values.byName(row['meal_type'] as String),
    description: row['description'] as String,
    proteinEstimateG: (row['protein_estimate_g'] as num?)?.toDouble(),
  );

  Future<Set<String>> loggedDays(int days, {DateTime? now}) =>
      daysWithRecords(_db, 'meal_entry', 'logged_at', days, now: now);
}
