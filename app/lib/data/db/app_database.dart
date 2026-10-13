import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'schema.dart';
import '../../domain/stored_dates.dart';

/// Opens (creating on first launch) the app's local SQLite database.
/// The whole app is local-first: every screen must work fully offline
/// against this store. See PROJECT_PLAN.md §2.
class AppDatabase {
  AppDatabase._();

  static Database? _db;

  static Future<Database> instance() async {
    return _db ??= await _open();
  }

  static Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'nirvana.db');
    return openDatabase(
      dbPath,
      version: latestSchemaVersion,
      onConfigure: configure,
      onOpen: (db) async {
        await repairLegacyExerciseReferences(db);
        await normalizeLegacyDates(db);
      },
      onCreate: (db, version) async {
        for (final statement in createTableStatements) {
          await db.execute(statement);
        }
        for (final statement in createIndexStatements) {
          await db.execute(statement);
        }
      },
      onUpgrade: migrate,
    );
  }

  static Future<void> configure(Database db) => db.execute('PRAGMA foreign_keys = ON');

  static Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    for (var version = oldVersion; version < newVersion; version++) {
      for (final sql in migrationStatements[version - 1]) {
        await db.execute(sql);
      }
    }
  }

  static Future<void> normalizeLegacyDates(Database db) => db.transaction((txn) async {
    for (final sql in createTableStatements) {
      final table = RegExp(r'CREATE TABLE (\w+)').firstMatch(sql)!.group(1)!;
      final columns = (await txn.rawQuery(
        'PRAGMA table_info($table)',
      )).map((c) => c['name'] as String).where(isStoredDateColumn).toList();
      if (columns.isEmpty) continue;
      final candidates = [
        for (final column in columns)
          column == 'log_date' || (table == 'sleep_entry' && column == 'date')
              ? 'length($column) != 10'
              : '(length($column) NOT IN (23, 26) OR substr($column, -1) = \'Z\' '
                    'OR instr(substr($column, 20), \'+\') > 0 OR instr(substr($column, 20), \'-\') > 0 '
                    'OR (length($column) = 26 AND substr($column, -3) = \'000\'))',
      ];
      final rows = await txn.query(
        table,
        columns: ['id', ...columns],
        where: candidates.join(' OR '),
      );
      final batch = txn.batch();
      for (final row in rows) {
        final changes = <String, Object?>{};
        for (final column in columns) {
          final value = row[column];
          if (value is! String) continue;
          try {
            final normalized = normalizeStoredDate(table, column, value);
            if (normalized != value) changes[column] = normalized;
          } on FormatException {
            // Preserve corrupt legacy rows for recovery rather than deleting them.
          }
        }
        if (changes.isNotEmpty) {
          batch.update(table, changes, where: 'id = ?', whereArgs: [row['id']]);
        }
      }
      await batch.commit(noResult: true);
    }
  });

  /// Keep legacy sessions without silently discarding their history.
  static Future<void> repairLegacyExerciseReferences(Database db) => db.transaction((txn) async {
    final orphans = await txn.rawQuery(
      'SELECT DISTINCT s.exercise_definition_id AS id FROM exercise_session s '
      'LEFT JOIN exercise_definition d ON d.id = s.exercise_definition_id WHERE d.id IS NULL',
    );
    for (final row in orphans) {
      await txn.insert('exercise_definition', {
        'id': row['id'],
        'name': 'Recovered exercise',
        'instructions': 'The exercise definition for this older record was missing.',
        'default_sets': 1,
        'default_reps': 1,
      });
    }
  });
}
