/// Core data entities, decoupled from UI and persistence.
/// See PROJECT_PLAN.md §4 and health-plan-source.md §21.
library;

class UserProfile {
  final String id;
  final String name;
  final int ageYears;
  final double heightCm;
  final String kneeOaSide; // e.g. "left", "right", "none"
  final double startingWeightKg;
  final double targetWeightMinKg;
  final double targetWeightMaxKg;
  final String routineConfigId;

  const UserProfile({
    required this.id,
    required this.name,
    required this.ageYears,
    required this.heightCm,
    required this.kneeOaSide,
    required this.startingWeightKg,
    required this.targetWeightMinKg,
    required this.targetWeightMaxKg,
    required this.routineConfigId,
  });
}

class WeightEntry {
  final String id;
  final DateTime takenAt;
  final double weightKg;
  final double? waistCm;
  final String? notes;

  const WeightEntry({
    required this.id,
    required this.takenAt,
    required this.weightKg,
    this.waistCm,
    this.notes,
  });
}

class WaterEntry {
  final String id;
  final DateTime loggedAt;
  final int amountMl;

  const WaterEntry({
    required this.id,
    required this.loggedAt,
    required this.amountMl,
  });
}

enum MealType { breakfast, midMorning, lunch, eveningSnack, dinner }

class MealEntry {
  final String id;
  final DateTime loggedAt;
  final MealType mealType;
  final String description;
  final double? proteinEstimateG;

  const MealEntry({
    required this.id,
    required this.loggedAt,
    required this.mealType,
    required this.description,
    this.proteinEstimateG,
  });
}

/// A named exercise from the library, e.g. "Straight Leg Raise".
/// See health-plan-source.md §6.
class ExerciseDefinition {
  final String id;
  final String name;
  final String instructions;
  final int defaultSets;
  final int defaultReps;
  final int? holdSeconds;

  const ExerciseDefinition({
    required this.id,
    required this.name,
    required this.instructions,
    required this.defaultSets,
    required this.defaultReps,
    this.holdSeconds,
  });
}

enum ExerciseFeedback { fine, tooPainful }

class ExerciseSession {
  final String id;
  final DateTime performedAt;
  final String exerciseDefinitionId;
  final int completedSets;
  final int completedReps;
  final int? painRating0to10;
  final ExerciseFeedback feedback;

  const ExerciseSession({
    required this.id,
    required this.performedAt,
    required this.exerciseDefinitionId,
    required this.completedSets,
    required this.completedReps,
    this.painRating0to10,
    this.feedback = ExerciseFeedback.fine,
  });
}

/// Pain/swelling/stiffness log per health-plan-source.md §8.
class PainEntry {
  final String id;
  final DateTime recordedAt;
  final int painBefore0to10;
  final int? painDuring0to10;
  final int? painAfter1to2h0to10;
  final int? painNextMorning0to10;
  final bool swelling;
  final int stiffness0to10;
  final bool sharpPain;
  final bool locking;
  final bool givingWay;

  const PainEntry({
    required this.id,
    required this.recordedAt,
    required this.painBefore0to10,
    this.painDuring0to10,
    this.painAfter1to2h0to10,
    this.painNextMorning0to10,
    this.swelling = false,
    this.stiffness0to10 = 0,
    this.sharpPain = false,
    this.locking = false,
    this.givingWay = false,
  });

  /// True when any red-flag symptom means the user should see the
  /// "consider professional assessment" message, never "push through it".
  /// See health-plan-source.md §8 and §22.
  bool get needsProfessionalAssessmentFlag => sharpPain || locking || givingWay || swelling;
}

class SleepEntry {
  final String id;
  final DateTime date;
  final DateTime? bedTime;
  final DateTime? wakeTime;
  final int? qualityRating1to5;

  const SleepEntry({
    required this.id,
    required this.date,
    this.bedTime,
    this.wakeTime,
    this.qualityRating1to5,
  });
}

enum DhyanaPractice { breathAwareness, bodyScan, mantra }

/// See docs/dhyana-plan.md.
class DhyanaSession {
  final String id;
  final DateTime date;
  final int plannedDurationMin;
  final int actualDurationMin;
  final DhyanaPractice practiceType;
  final int? moodBefore1to5;
  final int? moodAfter1to5;
  final String? notes;

  const DhyanaSession({
    required this.id,
    required this.date,
    required this.plannedDurationMin,
    required this.actualDurationMin,
    required this.practiceType,
    this.moodBefore1to5,
    this.moodAfter1to5,
    this.notes,
  });
}

enum HabitType {
  eyeBreak,
  movementBreak,
  kneeMobilityBreak,
  postureBreak,
  hydration,
  strengthSession,
  morningWalk,
  dhyana,
}

class HabitCompletion {
  final String id;
  final DateTime completedAt;
  final HabitType habitType;

  const HabitCompletion({
    required this.id,
    required this.completedAt,
    required this.habitType,
  });
}

enum ReminderPriority { high, medium, low }

enum ReminderStatus { pending, snoozed, skipped, completed }

class Reminder {
  final String id;
  final HabitType habitType;
  final ReminderPriority priority;
  final DateTime scheduledFor;
  final ReminderStatus status;
  final DateTime? snoozedUntil;

  const Reminder({
    required this.id,
    required this.habitType,
    required this.priority,
    required this.scheduledFor,
    this.status = ReminderStatus.pending,
    this.snoozedUntil,
  });
}

/// Rolled-up view for the Dashboard/Today screen. See health-plan-source.md §18.
class DailySummary {
  final DateTime date;
  final double? currentWeightKg;
  final double? sevenDayAverageWeightKg;
  final int waterConsumedMl;
  final int waterGoalMl;
  final int dhyanaSessionsCompleted;
  final int dhyanaStreakDays;
  final int? kneePain0to10;
  final bool kneeSwelling;
  final int? kneeMorningStiffness0to10;
  final double exerciseCompletionPercent;
  final int mealsLoggedCount;
  final double? proteinEstimateG;

  const DailySummary({
    required this.date,
    this.currentWeightKg,
    this.sevenDayAverageWeightKg,
    this.waterConsumedMl = 0,
    this.waterGoalMl = 0,
    this.dhyanaSessionsCompleted = 0,
    this.dhyanaStreakDays = 0,
    this.kneePain0to10,
    this.kneeSwelling = false,
    this.kneeMorningStiffness0to10,
    this.exerciseCompletionPercent = 0,
    this.mealsLoggedCount = 0,
    this.proteinEstimateG,
  });
}
