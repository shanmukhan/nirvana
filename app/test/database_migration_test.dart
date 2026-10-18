import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/data/db/app_database.dart';
import 'package:nirvana/data/db/schema.dart';
import 'package:nirvana/data/repositories/exercise_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  for (final oldVersion in [1, 2]) {
    test('v$oldVersion upgrade preserves exercise history and adds default partial reps', () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('nirvana-migration-');
      final path = '${dir.path}/test.db';
      var db = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: oldVersion,
          onCreate: (db, _) async {
            for (final sql in createTableStatements) {
              if (oldVersion == 1 && sql.contains('CREATE TABLE desk_break_log')) continue;
              await db.execute(
                sql.replaceAll('    partial_reps INTEGER NOT NULL DEFAULT 0,\n', ''),
              );
            }
          },
        ),
      );
      await ExerciseRepository(db).seedDefinitionsIfEmpty();
      await db.insert('exercise_session', {
        'id': 'old-session',
        'performed_at': '2026-10-11T09:00:00.000',
        'exercise_definition_id': 'quad-set',
        'completed_sets': 2,
        'completed_reps': 15,
      });
      await db.close();
      db = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: latestSchemaVersion,
          onConfigure: AppDatabase.configure,
          onUpgrade: AppDatabase.migrate,
        ),
      );
      final row = (await db.query('exercise_session')).single;
      expect(row['id'], 'old-session');
      expect(row['completed_sets'], 2);
      expect(row['partial_reps'], 0);
      expect(await db.query('desk_break_log'), isEmpty);
      expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
      await db.close();
      await dir.delete(recursive: true);
    });
  }
}
