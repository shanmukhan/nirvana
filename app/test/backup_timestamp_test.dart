import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/data/repositories/backup_repository.dart';
import 'package:nirvana/data/repositories/weight_repository.dart';
import 'package:nirvana/domain/stored_dates.dart';
import 'package:nirvana/data/db/app_database.dart';

import 'test_database.dart';

void main() {
  test('legacy timestamp normalization preserves records and repairs day queries', () async {
    final db = await openTestDatabase();
    await db.insert('weight_entry', {'id': 'legacy', 'taken_at': '2026-10-12', 'weight_kg': 70});
    await AppDatabase.normalizeLegacyDates(db);
    expect((await WeightRepository(db).forDay(DateTime(2026, 10, 12))).single.id, 'legacy');
    await db.close();
  });
  test('date-only and varying-precision imported timestamps remain in day history', () async {
    final db = await openTestDatabase();
    final repo = WeightRepository(db);
    await repo.add(weightKg: 70);
    final backup = BackupRepository(db);
    for (final timestamp in ['2026-10-12', '2026-10-12T00:00:00', '2026-10-12T00:00:00.000001']) {
      final data = jsonDecode(await backup.exportToJson());
      data['tables']['weight_entry'][0]['taken_at'] = timestamp;
      await backup.importFromJson(jsonEncode(data));
      expect(await repo.forDay(DateTime(2026, 10, 12)), hasLength(1));
      expect(await repo.forDay(DateTime(2026, 10, 11)), isEmpty);
    }
    await db.close();
  });
  test('offset timestamps normalize to device-local time and calendar dates remain dates', () {
    const timestamp = '2026-10-12T00:30:00+05:30';
    expect(
      normalizeStoredDate('weight_entry', 'taken_at', timestamp),
      DateTime.parse(timestamp).toLocal().toIso8601String(),
    );
    expect(normalizeStoredDate('desk_break_log', 'log_date', timestamp), '2026-10-12');
    for (final invalid in ['2026-02-30', '2026-10-12T25:00:00', '2026-10-12T12:00:00+05:99']) {
      expect(() => normalizeStoredDate('weight_entry', 'taken_at', invalid), throwsFormatException);
    }
  });
}
