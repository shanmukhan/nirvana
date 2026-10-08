import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/data/repositories/backup_repository.dart';
import 'package:nirvana/data/repositories/water_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_database.dart';

void main() {
  late Database db;
  late BackupRepository backup;
  setUp(() async {
    db = await openTestDatabase();
    backup = BackupRepository(db);
    await WaterRepository(db).log(250);
  });
  tearDown(() => db.close());

  test('preview is immutable and restore replaces data', () async {
    final json = await backup.exportToJson();
    final preview = await backup.prepareImport(json);
    expect(preview.recordCounts['water_entry'], 1);
    expect(preview.totalRecords, 1);
    expect(() => preview.recordCounts.clear(), throwsUnsupportedError);
    await WaterRepository(db).log(100);
    await backup.restore(preview);
    expect(await WaterRepository(db).totalMlForDay(DateTime.now()), 250);
  });

  test('legacy backup without desk-break table is accepted', () async {
    final data = jsonDecode(await backup.exportToJson()) as Map<String, dynamic>;
    data.remove('schema_version');
    (data['tables'] as Map).remove('desk_break_log');
    await backup.importFromJson(jsonEncode(data));
    expect(await WaterRepository(db).totalMlForDay(DateTime.now()), 250);
  });

  for (final issue in [
    'version',
    'missing',
    'column',
    'negative',
    'duplicate',
    'reference',
    'date',
    'time',
    'type',
    'empty',
    'schema',
  ]) {
    test('rejects $issue and preserves existing data', () async {
      final data = jsonDecode(await backup.exportToJson()) as Map<String, dynamic>;
      final tables = data['tables'] as Map<String, dynamic>;
      final water = (tables['water_entry'] as List).first as Map<String, dynamic>;
      switch (issue) {
        case 'version':
          data['format_version'] = 999;
        case 'missing':
          tables.remove('water_entry');
        case 'column':
          water['unexpected'] = 'value';
        case 'negative':
          water['amount_ml'] = -1;
        case 'duplicate':
          (tables['water_entry'] as List).add(Map.of(water));
        case 'reference':
          tables['exercise_session'] = [
            {
              'id': 'session',
              'performed_at': DateTime.now().toIso8601String(),
              'exercise_definition_id': 'missing',
              'completed_sets': 1,
              'completed_reps': 1,
              'feedback': 'fine',
            },
          ];
        case 'date':
          water['logged_at'] = '2026-02-30T12:00:00';
        case 'time':
          water['logged_at'] = '2026-10-07T12:99:00';
        case 'type':
          water['amount_ml'] = '250';
        case 'empty':
          data['tables'] = <String, dynamic>{};
        case 'schema':
          data['schema_version'] = 999;
      }
      await expectLater(backup.importFromJson(jsonEncode(data)), throwsFormatException);
      expect(await WaterRepository(db).totalMlForDay(DateTime.now()), 250);
    });
  }

  test('a database failure rolls back the whole restore', () async {
    final json = await backup.exportToJson();
    await WaterRepository(db).log(100);
    await db.execute(
      "CREATE TRIGGER reject_water BEFORE INSERT ON water_entry BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(backup.importFromJson(json), throwsA(isA<DatabaseException>()));
    expect(await WaterRepository(db).totalMlForDay(DateTime.now()), 350);
  });
}
