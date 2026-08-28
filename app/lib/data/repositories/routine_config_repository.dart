import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/routine_config.dart';

/// Reads/writes the single `routine_config` row's `config_json` blob —
/// see lib/data/db/schema.dart for why it's one JSON column rather than
/// a normalized table (deeply nested, rarely queried). The row starts as
/// `'{}'` (set in UserProfileRepository.bootstrapIfMissing); each config
/// section is stored under its own key so sections can be added over
/// time without migrating the ones already there. Only the hydration
/// section is wired up so far — see PROJECT_PLAN.md §7.
class RoutineConfigRepository {
  final Database _db;

  RoutineConfigRepository(this._db);

  Future<HydrationConfig> hydrationConfig(String routineConfigId) async {
    final json = await _loadJson(routineConfigId);
    final hydration = json['hydration'];
    if (hydration is! Map<String, dynamic>) return const HydrationConfig();
    return HydrationConfig.fromMap(hydration);
  }

  Future<void> setHydrationConfig(String routineConfigId, HydrationConfig config) async {
    final json = await _loadJson(routineConfigId);
    json['hydration'] = config.toMap();
    await _db.update(
      'routine_config',
      {'config_json': jsonEncode(json)},
      where: 'id = ?',
      whereArgs: [routineConfigId],
    );
  }

  Future<Map<String, dynamic>> _loadJson(String routineConfigId) async {
    final rows = await _db.query(
      'routine_config',
      where: 'id = ?',
      whereArgs: [routineConfigId],
      limit: 1,
    );
    if (rows.isEmpty) return {};
    final raw = rows.first['config_json'] as String;
    if (raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : {};
  }
}
