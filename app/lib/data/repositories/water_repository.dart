import 'package:sqflite/sqflite.dart';

import '../../domain/entities.dart';
import 'id_generator.dart';

class WaterRepository {
  final Database _db;

  WaterRepository(this._db);

  Future<WaterEntry> log(int amountMl, {DateTime? loggedAt}) async {
    final entry = WaterEntry(
      id: newId(),
      loggedAt: loggedAt ?? DateTime.now(),
      amountMl: amountMl,
    );
    await _db.insert('water_entry', {
      'id': entry.id,
      'logged_at': entry.loggedAt.toIso8601String(),
      'amount_ml': entry.amountMl,
    });
    return entry;
  }

  Future<List<WaterEntry>> forDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
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
    final entries = await forDay(day);
    return entries.fold<int>(0, (sum, e) => sum + e.amountMl);
  }
}
