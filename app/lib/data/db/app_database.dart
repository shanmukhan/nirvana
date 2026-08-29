import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

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
      onCreate: (db, version) async {
        for (final statement in createTableStatements) {
          await db.execute(statement);
        }
        for (final statement in createIndexStatements) {
          await db.execute(statement);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var v = oldVersion; v < newVersion; v++) {
          for (final statement in migrationStatements[v - 1]) {
            await db.execute(statement);
          }
        }
      },
    );
  }
}
