import 'package:sqflite/sqflite.dart';

import '../../domain/calendar_days.dart';
import '../../domain/stored_dates.dart';
import '../../domain/entities.dart';
import '../../domain/log_validation.dart';
import 'date_queries.dart';
import 'id_generator.dart';

class WeightRepository {
  final Database _db;

  WeightRepository(this._db);

  Future<WeightEntry> add({
    required double weightKg,
    double? waistCm,
    String? notes,
    DateTime? takenAt,
  }) async {
    requirePositiveNumber(weightKg, 'weightKg');
    if (waistCm != null) requirePositiveNumber(waistCm, 'waistCm');
    final entry = WeightEntry(
      id: newId(),
      takenAt: takenAt ?? DateTime.now(),
      weightKg: weightKg,
      waistCm: waistCm,
      notes: notes,
    );
    await _db.insert('weight_entry', _toRow(entry));
    return entry;
  }

  Future<List<WeightEntry>> recent({int limit = 90}) async {
    final rows = await _db.query('weight_entry', orderBy: 'taken_at DESC', limit: limit);
    return rows.map(_fromRow).toList();
  }

  /// Average of the most recent entries within the last 7 days.
  Future<double?> sevenDayAverageKg() async {
    final today = DateTime.now();
    final rows = await _db.rawQuery(
      'SELECT AVG(weight_kg) AS average FROM weight_entry WHERE taken_at >= ? AND taken_at < ?',
      [
        calendarDayOffset(today, -6).toIso8601String(),
        calendarDayOffset(today, 1).toIso8601String(),
      ],
    );
    return (rows.first['average'] as num?)?.toDouble();
  }

  Future<List<WeightEntry>> forDay(DateTime day) async => (await queryDateRange(
    _db,
    'weight_entry',
    'taken_at',
    startOfDay(day),
    calendarDayOffset(day, 1),
  )).map(_fromRow).toList();

  Future<List<WeightEntry>> lastDays(int days, {DateTime? now}) async {
    RangeError.checkValueInInterval(days, 1, 3660, 'days');
    final today = now ?? DateTime.now();
    return (await queryDateRange(
      _db,
      'weight_entry',
      'taken_at',
      calendarDayOffset(today, 1 - days),
      calendarDayOffset(today, 1),
    )).map(_fromRow).toList();
  }

  Map<String, dynamic> _toRow(WeightEntry entry) => {
    'id': entry.id,
    'taken_at': localTimestamp(entry.takenAt),
    'weight_kg': entry.weightKg,
    'waist_cm': entry.waistCm,
    'notes': entry.notes,
  };

  WeightEntry _fromRow(Map<String, Object?> row) => WeightEntry(
    id: row['id'] as String,
    takenAt: DateTime.parse(row['taken_at'] as String),
    weightKg: (row['weight_kg'] as num).toDouble(),
    waistCm: (row['waist_cm'] as num?)?.toDouble(),
    notes: row['notes'] as String?,
  );
}
