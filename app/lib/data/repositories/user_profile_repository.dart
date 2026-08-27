import 'package:sqflite/sqflite.dart';

import '../../domain/entities.dart';
import 'id_generator.dart';

/// Loads the single local UserProfile/RoutineConfig, creating them with
/// the baseline from health-plan-source.md §1 on first launch. There is
/// exactly one profile until Phase 4 (multi-user readiness).
class UserProfileRepository {
  final Database _db;

  UserProfileRepository(this._db);

  Future<UserProfile> bootstrapIfMissing() async {
    final existing = await current();
    if (existing != null) return existing;

    final routineConfigId = newId();
    await _db.insert('routine_config', {
      'id': routineConfigId,
      // Full RoutineConfig editing lands in Phase 3 (PROJECT_PLAN.md §7);
      // until then the app runs on the in-code defaults in
      // lib/domain/routine_config.dart, keyed by this id.
      'config_json': '{}',
    });

    final profile = UserProfile(
      id: newId(),
      name: 'You',
      ageYears: 41,
      heightCm: 165,
      kneeOaSide: 'left',
      startingWeightKg: 72,
      targetWeightMinKg: 65,
      targetWeightMaxKg: 67,
      routineConfigId: routineConfigId,
    );
    await _db.insert('user_profile', {
      'id': profile.id,
      'name': profile.name,
      'age_years': profile.ageYears,
      'height_cm': profile.heightCm,
      'knee_oa_side': profile.kneeOaSide,
      'starting_weight_kg': profile.startingWeightKg,
      'target_weight_min_kg': profile.targetWeightMinKg,
      'target_weight_max_kg': profile.targetWeightMaxKg,
      'routine_config_id': profile.routineConfigId,
    });
    return profile;
  }

  Future<UserProfile?> current() async {
    final rows = await _db.query('user_profile', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return UserProfile(
      id: row['id'] as String,
      name: row['name'] as String,
      ageYears: row['age_years'] as int,
      heightCm: (row['height_cm'] as num).toDouble(),
      kneeOaSide: row['knee_oa_side'] as String,
      startingWeightKg: (row['starting_weight_kg'] as num).toDouble(),
      targetWeightMinKg: (row['target_weight_min_kg'] as num).toDouble(),
      targetWeightMaxKg: (row['target_weight_max_kg'] as num).toDouble(),
      routineConfigId: row['routine_config_id'] as String,
    );
  }
}
