import 'package:sqflite/sqflite.dart';

import '../../domain/entities.dart';
import 'id_generator.dart';

/// The 6 strength/knee-support exercises from health-plan-source.md §6.
/// Seeded once on first launch; ids are stable slugs so ExerciseSession
/// rows keep working across reseeds.
const List<ExerciseDefinition> strengthExerciseSeed = [
  ExerciseDefinition(
    id: 'straight-leg-raise',
    name: 'Straight Leg Raise',
    instructions:
        'Lie on your back. Keep one leg bent and the exercising leg straight. '
        'Tighten the thigh. Raise the straight leg slowly. Lower slowly.',
    defaultSets: 2,
    defaultReps: 10,
  ),
  ExerciseDefinition(
    id: 'quad-set',
    name: 'Quad Set',
    instructions:
        'Sit or lie with the leg straight. Tighten the front thigh. Gently '
        'press the back of the knee toward the surface. Hold about 5 seconds.',
    defaultSets: 2,
    defaultReps: 15,
    holdSeconds: 5,
  ),
  ExerciseDefinition(
    id: 'sit-to-stand',
    name: 'Sit-to-Stand',
    instructions:
        'Use a stable chair. Feet approximately hip-width apart. Stand up '
        'under control. Sit down slowly. Use a higher chair and reduce range '
        'if this causes knee pain.',
    defaultSets: 2,
    defaultReps: 10,
  ),
  ExerciseDefinition(
    id: 'glute-bridge',
    name: 'Glute Bridge',
    instructions:
        'Lie on your back. Bend the knees comfortably. Lift the hips. Pause '
        'briefly. Lower slowly.',
    defaultSets: 2,
    defaultReps: 12,
  ),
  ExerciseDefinition(
    id: 'calf-raise',
    name: 'Calf Raise',
    instructions:
        'Hold a stable surface. Rise onto the balls of the feet. Lower slowly.',
    defaultSets: 2,
    defaultReps: 15,
  ),
  ExerciseDefinition(
    id: 'hip-abduction',
    name: 'Hip Abduction',
    instructions:
        'Hold a stable support. Move one leg sideways without leaning your '
        'body. Return slowly.',
    defaultSets: 2,
    defaultReps: 10,
  ),
];

class ExerciseRepository {
  final Database _db;

  ExerciseRepository(this._db);

  Future<void> seedDefinitionsIfEmpty() async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM exercise_definition'),
    );
    if (count != null && count > 0) return;
    final batch = _db.batch();
    for (final def in strengthExerciseSeed) {
      batch.insert('exercise_definition', {
        'id': def.id,
        'name': def.name,
        'instructions': def.instructions,
        'default_sets': def.defaultSets,
        'default_reps': def.defaultReps,
        'hold_seconds': def.holdSeconds,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<ExerciseDefinition>> allDefinitions() async {
    final rows = await _db.query('exercise_definition', orderBy: 'name');
    return rows
        .map(
          (row) => ExerciseDefinition(
            id: row['id'] as String,
            name: row['name'] as String,
            instructions: row['instructions'] as String,
            defaultSets: row['default_sets'] as int,
            defaultReps: row['default_reps'] as int,
            holdSeconds: row['hold_seconds'] as int?,
          ),
        )
        .toList();
  }

  Future<ExerciseSession> logSession({
    required String exerciseDefinitionId,
    required int completedSets,
    required int completedReps,
    int? painRating0to10,
    ExerciseFeedback feedback = ExerciseFeedback.fine,
    DateTime? performedAt,
  }) async {
    final session = ExerciseSession(
      id: newId(),
      performedAt: performedAt ?? DateTime.now(),
      exerciseDefinitionId: exerciseDefinitionId,
      completedSets: completedSets,
      completedReps: completedReps,
      painRating0to10: painRating0to10,
      feedback: feedback,
    );
    await _db.insert('exercise_session', {
      'id': session.id,
      'performed_at': session.performedAt.toIso8601String(),
      'exercise_definition_id': session.exerciseDefinitionId,
      'completed_sets': session.completedSets,
      'completed_reps': session.completedReps,
      'pain_rating_0_10': session.painRating0to10,
      'feedback': session.feedback.name,
    });
    return session;
  }

  Future<List<ExerciseSession>> forDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _db.query(
      'exercise_session',
      where: 'performed_at >= ? AND performed_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return rows
        .map(
          (row) => ExerciseSession(
            id: row['id'] as String,
            performedAt: DateTime.parse(row['performed_at'] as String),
            exerciseDefinitionId: row['exercise_definition_id'] as String,
            completedSets: row['completed_sets'] as int,
            completedReps: row['completed_reps'] as int,
            painRating0to10: row['pain_rating_0_10'] as int?,
            feedback: ExerciseFeedback.values.byName(row['feedback'] as String),
          ),
        )
        .toList();
  }
}
