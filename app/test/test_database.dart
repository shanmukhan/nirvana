import 'package:nirvana/data/db/schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openTestDatabase() async {
  sqfliteFfiInit();
  return databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: latestSchemaVersion,
      onCreate: (db, _) async {
        for (final sql in [...createTableStatements, ...createIndexStatements]) {
          await db.execute(sql);
        }
      },
    ),
  );
}
