import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../db/schema.dart';

/// JSON export/import of the entire local database (requirements §9),
/// for backup and device migration. Table names come straight from
/// [createTableStatements] so a newly added table is picked up
/// automatically without touching this file.
class BackupRepository {
  final Database _db;

  BackupRepository(this._db);

  static const int backupFormatVersion = 1;

  static final List<String> _tableNames = createTableStatements
      .map((statement) => RegExp(r'CREATE TABLE (\w+)').firstMatch(statement)!.group(1)!)
      .toList();

  Future<String> exportToJson() async {
    final data = <String, List<Map<String, Object?>>>{};
    for (final table in _tableNames) {
      data[table] = await _db.query(table);
    }
    return jsonEncode({
      'format_version': backupFormatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': data,
    });
  }

  /// Wipes every known table and repopulates it from [json], inside a
  /// single transaction so a malformed backup can't leave the database
  /// half-overwritten.
  Future<void> importFromJson(String json) async {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final tables = decoded['tables'] as Map<String, dynamic>;
    await _db.transaction((txn) async {
      for (final table in _tableNames) {
        await txn.delete(table);
      }
      for (final entry in tables.entries) {
        if (!_tableNames.contains(entry.key)) continue;
        for (final row in entry.value as List<dynamic>) {
          await txn.insert(
            entry.key,
            Map<String, Object?>.from(row as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}
