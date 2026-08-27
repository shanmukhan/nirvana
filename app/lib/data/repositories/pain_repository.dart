import 'package:sqflite/sqflite.dart';

import '../../domain/entities.dart';
import 'id_generator.dart';

class PainRepository {
  final Database _db;

  PainRepository(this._db);

  Future<PainEntry> log({
    required int painBefore0to10,
    int? painDuring0to10,
    int? painAfter1to2h0to10,
    int? painNextMorning0to10,
    bool swelling = false,
    int stiffness0to10 = 0,
    bool sharpPain = false,
    bool locking = false,
    bool givingWay = false,
    DateTime? recordedAt,
  }) async {
    final entry = PainEntry(
      id: newId(),
      recordedAt: recordedAt ?? DateTime.now(),
      painBefore0to10: painBefore0to10,
      painDuring0to10: painDuring0to10,
      painAfter1to2h0to10: painAfter1to2h0to10,
      painNextMorning0to10: painNextMorning0to10,
      swelling: swelling,
      stiffness0to10: stiffness0to10,
      sharpPain: sharpPain,
      locking: locking,
      givingWay: givingWay,
    );
    await _db.insert('pain_entry', _toRow(entry));
    return entry;
  }

  Future<List<PainEntry>> recent({int limit = 90}) async {
    final rows = await _db.query(
      'pain_entry',
      orderBy: 'recorded_at DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<PainEntry?> latest() async {
    final rows = await recent(limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Map<String, dynamic> _toRow(PainEntry e) => {
    'id': e.id,
    'recorded_at': e.recordedAt.toIso8601String(),
    'pain_before_0_10': e.painBefore0to10,
    'pain_during_0_10': e.painDuring0to10,
    'pain_after_1_2h_0_10': e.painAfter1to2h0to10,
    'pain_next_morning_0_10': e.painNextMorning0to10,
    'swelling': e.swelling ? 1 : 0,
    'stiffness_0_10': e.stiffness0to10,
    'sharp_pain': e.sharpPain ? 1 : 0,
    'locking': e.locking ? 1 : 0,
    'giving_way': e.givingWay ? 1 : 0,
  };

  PainEntry _fromRow(Map<String, Object?> row) => PainEntry(
    id: row['id'] as String,
    recordedAt: DateTime.parse(row['recorded_at'] as String),
    painBefore0to10: row['pain_before_0_10'] as int,
    painDuring0to10: row['pain_during_0_10'] as int?,
    painAfter1to2h0to10: row['pain_after_1_2h_0_10'] as int?,
    painNextMorning0to10: row['pain_next_morning_0_10'] as int?,
    swelling: (row['swelling'] as int) == 1,
    stiffness0to10: row['stiffness_0_10'] as int,
    sharpPain: (row['sharp_pain'] as int) == 1,
    locking: (row['locking'] as int) == 1,
    givingWay: (row['giving_way'] as int) == 1,
  );
}
