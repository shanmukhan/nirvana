import 'package:sqflite/sqflite.dart';

import '../../domain/entities.dart';
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
    final entry = MealEntry(
      id: newId(),
      loggedAt: loggedAt ?? DateTime.now(),
      mealType: mealType,
      description: description,
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
    final end = start.add(const Duration(days: 1));
    final rows = await _db.query(
      'meal_entry',
      where: 'logged_at >= ? AND logged_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'logged_at',
    );
    return rows.map(_fromRow).toList();
  }

  Future<double> totalProteinForDay(DateTime day) async {
    final entries = await forDay(day);
    return entries.fold<double>(0, (sum, e) => sum + (e.proteinEstimateG ?? 0));
  }

  MealEntry _fromRow(Map<String, Object?> row) => MealEntry(
    id: row['id'] as String,
    loggedAt: DateTime.parse(row['logged_at'] as String),
    mealType: MealType.values.byName(row['meal_type'] as String),
    description: row['description'] as String,
    proteinEstimateG: row['protein_estimate_g'] as double?,
  );
}
