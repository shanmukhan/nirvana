import 'package:flutter_test/flutter_test.dart';
import 'package:nirvana/data/db/app_database.dart';
import 'package:nirvana/data/repositories/backup_repository.dart';
import 'package:nirvana/data/repositories/exercise_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_database.dart';

void main() {
  test('repository and SQLite reject orphan writes', () async {
    final db = await openTestDatabase();
    await expectLater(
      ExerciseRepository(
        db,
      ).logSession(exerciseDefinitionId: 'missing', completedSets: 1, completedReps: 10),
      throwsArgumentError,
    );
    await expectLater(
      db.insert('exercise_session', {
        'id': 'orphan',
        'performed_at': DateTime.now().toIso8601String(),
        'exercise_definition_id': 'missing',
        'completed_sets': 1,
        'completed_reps': 10,
      }),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.query('exercise_session'), isEmpty);
    await db.close();
  });
  test('legacy orphan is preserved and its repaired backup round-trips', () async {
    final db = await openTestDatabase();
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.insert('exercise_session', {
      'id': 'legacy',
      'performed_at': DateTime.now().toIso8601String(),
      'exercise_definition_id': 'missing',
      'completed_sets': 1,
      'completed_reps': 10,
    });
    await AppDatabase.configure(db);
    await AppDatabase.repairLegacyExerciseReferences(db);
    await AppDatabase.repairLegacyExerciseReferences(db);
    expect(await db.query('exercise_definition'), hasLength(1));
    final backup = BackupRepository(db);
    await backup.importFromJson(await backup.exportToJson());
    expect((await db.query('exercise_session')).single['id'], 'legacy');
    await db.close();
  });
}
