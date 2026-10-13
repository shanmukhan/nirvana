import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities.dart';
import '../../domain/routine_config.dart';
import '../../domain/stored_dates.dart';
import '../../services/reminder_prefs.dart';
import '../db/schema.dart';
import 'desk_break_log_repository.dart';

/// Immutable validated archive shared by the preview and restore.
class PreparedBackup {
  final Map<String, List<Map<String, Object?>>> _tables;
  final DateTime? exportedAt;
  PreparedBackup._(this._tables, this.exportedAt);

  Map<String, int> get recordCounts =>
      Map.unmodifiable(_tables.map((name, rows) => MapEntry(name, rows.length)));
  int get totalRecords => _tables.values.fold(0, (sum, rows) => sum + rows.length);
}

/// Portable plaintext backups. Validate before replacing data and retain
/// transactional rollback for any database failure.
class BackupRepository {
  final Database _db;
  BackupRepository(this._db);

  static const backupFormatVersion = 1;
  static const maxBackupBytes = 16 * 1024 * 1024;
  static const maxBackupRows = 100000;
  static final List<String> _tableNames = createTableStatements
      .map((statement) => RegExp(r'CREATE TABLE (\w+)').firstMatch(statement)!.group(1)!)
      .toList();

  Future<String> exportToJson() => _db.transaction((txn) async {
    final data = <String, List<Map<String, Object?>>>{};
    for (final table in _tableNames) {
      data[table] = await txn.query(table);
    }
    final json = jsonEncode({
      'format_version': backupFormatVersion,
      'schema_version': latestSchemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': data,
    });
    _checkSize(json);
    if (data.values.fold<int>(0, (sum, rows) => sum + rows.length) > maxBackupRows) {
      throw const FormatException('Backup exceeds the supported record limit.');
    }
    return json;
  });

  Future<PreparedBackup> prepareImport(String json) async {
    _checkSize(json);
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic> || decoded['format_version'] != backupFormatVersion) {
      throw const FormatException('Unsupported or missing backup format version.');
    }
    final version = decoded['schema_version'];
    if (version != null && (version is! int || version < 1 || version > latestSchemaVersion)) {
      throw const FormatException('Unsupported database schema version.');
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic> || tables.keys.any((name) => !_tableNames.contains(name))) {
      throw const FormatException('Invalid backup tables.');
    }
    final validated = <String, List<Map<String, Object?>>>{};
    var rowCount = 0;
    for (final table in _tableNames) {
      // Original archives may predate desk-break logs. Other tables must
      // always be explicit, so missing content cannot erase existing data.
      if (!tables.containsKey(table) &&
          table == 'desk_break_log' &&
          (version == null || version == 1)) {
        validated[table] = const [];
        continue;
      }
      final rows = tables[table];
      if (rows is! List) {
        throw FormatException('Missing or invalid table: $table.');
      }
      rowCount += rows.length;
      if (rowCount > maxBackupRows) {
        throw const FormatException('Too many backup records.');
      }
      final columns = await _db.rawQuery('PRAGMA table_info($table)');
      final names = columns.map((column) => column['name'] as String).toSet();
      final ids = <String>{};
      final slots = <String>{};
      final result = <Map<String, Object?>>[];
      for (final raw in rows) {
        if (raw is! Map<String, dynamic> || raw.keys.any((key) => !names.contains(key))) {
          throw FormatException('Invalid columns in $table.');
        }
        final row = Map<String, Object?>.from(raw);
        for (final column in columns) {
          final name = column['name'] as String;
          final value = row[name];
          if (value == null) {
            if (column['pk'] == 1 ||
                (column['notnull'] == 1 && column['dflt_value'] == null) ||
                (column['notnull'] == 1 && row.containsKey(name))) {
              throw FormatException('Missing or invalid $table.$name.');
            }
            continue;
          }
          final type = column['type'];
          if ((type == 'TEXT' && value is! String) ||
              (type == 'INTEGER' && value is! int) ||
              (type == 'REAL' && (value is! num || !value.isFinite))) {
            throw FormatException('Invalid type for $table.$name.');
          }
          _validateValue(table, name, value);
          if (value is String && isStoredDateColumn(name)) {
            row[name] = normalizeStoredDate(table, name, value);
          }
        }
        if (!ids.add(row['id'] as String)) {
          throw FormatException('Duplicate id in $table.');
        }
        if (table == 'desk_break_log') {
          final key =
              '${row['desk_break_type']}:${row['log_date']}:${row['slot_hour']}:${row['slot_minute']}';
          if (!slots.add(key)) {
            throw const FormatException('Duplicate desk-break slot.');
          }
        }
        result.add(Map.unmodifiable(row));
      }
      validated[table] = List.unmodifiable(result);
    }
    _validateReferences(validated);
    final exported = decoded['exported_at'];
    if (exported != null && (exported is! String || DateTime.tryParse(exported) == null)) {
      throw const FormatException('Invalid export date.');
    }
    return PreparedBackup._(
      Map.unmodifiable(validated),
      exported == null ? null : DateTime.parse(exported as String),
    );
  }

  Future<void> importFromJson(String json) async => restore(await prepareImport(json));

  Future<void> restore(PreparedBackup backup) => _db.transaction((txn) async {
    for (final table in _tableNames.reversed) {
      await txn.delete(table);
    }
    final batch = txn.batch();
    for (final table in _tableNames) {
      for (final row in backup._tables[table]!) {
        batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.abort);
      }
    }
    await batch.commit(noResult: true);
  });

  static void _checkSize(String json) {
    if (json.length > maxBackupBytes || utf8.encode(json).length > maxBackupBytes) {
      throw const FormatException('Backup is larger than 16 MB.');
    }
  }

  static void _validateValue(String table, String name, Object value) {
    void require(bool valid) {
      if (!valid) throw FormatException('Invalid value for $table.$name.');
    }

    if (name == 'id' || name.endsWith('_id')) {
      require((value as String).trim().isNotEmpty);
    }
    if (isStoredDateColumn(name)) {
      normalizeStoredDate(table, name, value as String);
    }
    if (name.endsWith('_0_10')) require((value as int) >= 0 && value <= 10);
    if (name.endsWith('_1_5')) require((value as int) >= 1 && value <= 5);
    if (['swelling', 'sharp_pain', 'locking', 'giving_way'].contains(name)) {
      require(value == 0 || value == 1);
    }
    if (name.endsWith('_kg') || name == 'height_cm' || name == 'waist_cm' || name == 'amount_ml') {
      require((value as num) > 0);
    }
    if (name == 'protein_estimate_g') require((value as num) >= 0);
    if (name == 'age_years') require((value as int) > 0 && value <= 130);
    if ([
      'default_sets',
      'default_reps',
      'hold_seconds',
      'planned_duration_min',
      'actual_duration_min',
    ].contains(name)) {
      require((value as int) > 0);
    }
    if (name == 'completed_sets' || name == 'completed_reps' || name == 'partial_reps') {
      require((value as int) >= 0);
    }
    if (name == 'slot_hour') require((value as int) >= 0 && value <= 23);
    if (name == 'slot_minute') require((value as int) >= 0 && value <= 59);
    if (name == 'meal_type') {
      require(MealType.values.any((item) => item.name == value));
    }
    if (name == 'practice_type') {
      require(DhyanaPractice.values.any((item) => item.name == value));
    }
    if (name == 'feedback') {
      require(ExerciseFeedback.values.any((item) => item.name == value));
    }
    if (name == 'habit_type') {
      require(HabitType.values.any((item) => item.name == value));
    }
    if (name == 'priority') {
      require(ReminderPriority.values.any((item) => item.name == value));
    }
    if (name == 'desk_break_type') {
      require(DeskBreakType.values.any((item) => item.name == value));
    }
    if (name == 'status') {
      require(
        table == 'desk_break_log'
            ? DeskBreakLogStatus.values.any((item) => item.name == value)
            : ReminderStatus.values.any((item) => item.name == value),
      );
    }
    if (name == 'config_json') {
      final config = jsonDecode(value as String);
      require(config is Map<String, dynamic>);
      if (config is Map<String, dynamic> && config.containsKey('hydration')) {
        final hydration = config['hydration'];
        require(hydration is Map<String, dynamic>);
        HydrationConfig.fromMap(hydration as Map<String, dynamic>);
      }
    }
  }

  static void _validateReferences(Map<String, List<Map<String, Object?>>> tables) {
    final configs = tables['routine_config']!.map((row) => row['id']).toSet();
    final definitions = tables['exercise_definition']!.map((row) => row['id']).toSet();
    for (final row in tables['user_profile']!) {
      if (!configs.contains(row['routine_config_id']) ||
          (row['target_weight_min_kg'] as num) > (row['target_weight_max_kg'] as num)) {
        throw const FormatException('Invalid profile configuration or target range.');
      }
    }
    if (tables['user_profile']!.length > 1) {
      throw const FormatException('Only one local profile is supported.');
    }
    for (final row in tables['exercise_session']!) {
      if (!definitions.contains(row['exercise_definition_id'])) {
        throw const FormatException('Exercise session references a missing definition.');
      }
    }
  }
}
