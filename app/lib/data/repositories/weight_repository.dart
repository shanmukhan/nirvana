import 'package:sqflite/sqflite.dart';

import '../../domain/entities.dart';
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
    final rows = await _db.query(
      'weight_entry',
      orderBy: 'taken_at DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  /// Average of the most recent entries within the last 7 days.
  Future<double?> sevenDayAverageKg() async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final rows = await _db.query(
      'weight_entry',
      where: 'taken_at >= ?',
      whereArgs: [since.toIso8601String()],
    );
    if (rows.isEmpty) return null;
    final total = rows.fold<double>(0, (sum, row) => sum + (row['weight_kg'] as num));
    return total / rows.length;
  }

  Map<String, dynamic> _toRow(WeightEntry entry) => {
    'id': entry.id,
    'taken_at': entry.takenAt.toIso8601String(),
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
