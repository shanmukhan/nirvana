/// SQLite schema for the local-first store. One table per entity in
/// lib/domain/entities.dart. Times are stored as ISO-8601 strings, enums as
/// their Dart name (e.g. "breathAwareness"), and RoutineConfig as a single
/// JSON blob column since it is a deeply nested, rarely-queried record.
const List<String> createTableStatements = [
  '''
  CREATE TABLE user_profile (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    age_years INTEGER NOT NULL,
    height_cm REAL NOT NULL,
    knee_oa_side TEXT NOT NULL,
    starting_weight_kg REAL NOT NULL,
    target_weight_min_kg REAL NOT NULL,
    target_weight_max_kg REAL NOT NULL,
    routine_config_id TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE routine_config (
    id TEXT PRIMARY KEY,
    config_json TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE weight_entry (
    id TEXT PRIMARY KEY,
    taken_at TEXT NOT NULL,
    weight_kg REAL NOT NULL,
    waist_cm REAL,
    notes TEXT
  )
  ''',
  '''
  CREATE TABLE water_entry (
    id TEXT PRIMARY KEY,
    logged_at TEXT NOT NULL,
    amount_ml INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE meal_entry (
    id TEXT PRIMARY KEY,
    logged_at TEXT NOT NULL,
    meal_type TEXT NOT NULL,
    description TEXT NOT NULL,
    protein_estimate_g REAL
  )
  ''',
  '''
  CREATE TABLE exercise_definition (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    instructions TEXT NOT NULL,
    default_sets INTEGER NOT NULL,
    default_reps INTEGER NOT NULL,
    hold_seconds INTEGER
  )
  ''',
  '''
  CREATE TABLE exercise_session (
    id TEXT PRIMARY KEY,
    performed_at TEXT NOT NULL,
    exercise_definition_id TEXT NOT NULL REFERENCES exercise_definition(id),
    completed_sets INTEGER NOT NULL,
    completed_reps INTEGER NOT NULL,
    pain_rating_0_10 INTEGER,
    feedback TEXT NOT NULL DEFAULT 'fine'
  )
  ''',
  '''
  CREATE TABLE pain_entry (
    id TEXT PRIMARY KEY,
    recorded_at TEXT NOT NULL,
    pain_before_0_10 INTEGER NOT NULL,
    pain_during_0_10 INTEGER,
    pain_after_1_2h_0_10 INTEGER,
    pain_next_morning_0_10 INTEGER,
    swelling INTEGER NOT NULL DEFAULT 0,
    stiffness_0_10 INTEGER NOT NULL DEFAULT 0,
    sharp_pain INTEGER NOT NULL DEFAULT 0,
    locking INTEGER NOT NULL DEFAULT 0,
    giving_way INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE sleep_entry (
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,
    bed_time TEXT,
    wake_time TEXT,
    quality_rating_1_5 INTEGER
  )
  ''',
  '''
  CREATE TABLE dhyana_session (
    id TEXT PRIMARY KEY,
    date TEXT NOT NULL,
    planned_duration_min INTEGER NOT NULL,
    actual_duration_min INTEGER NOT NULL,
    practice_type TEXT NOT NULL,
    mood_before_1_5 INTEGER,
    mood_after_1_5 INTEGER,
    notes TEXT
  )
  ''',
  '''
  CREATE TABLE habit_completion (
    id TEXT PRIMARY KEY,
    completed_at TEXT NOT NULL,
    habit_type TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE reminder (
    id TEXT PRIMARY KEY,
    habit_type TEXT NOT NULL,
    priority TEXT NOT NULL,
    scheduled_for TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    snoozed_until TEXT
  )
  ''',
  '''
  CREATE TABLE desk_break_log (
    id TEXT PRIMARY KEY,
    desk_break_type TEXT NOT NULL,
    log_date TEXT NOT NULL,
    slot_hour INTEGER NOT NULL,
    slot_minute INTEGER NOT NULL,
    status TEXT NOT NULL,
    fired_at TEXT NOT NULL,
    responded_at TEXT,
    UNIQUE(desk_break_type, log_date, slot_hour, slot_minute)
  )
  ''',
];

/// Statements to bring an existing database up to [latestSchemaVersion].
/// Keyed by the version being migrated *to* — e.g. index 0 holds the
/// statements that take a v1 database to v2.
const List<List<String>> migrationStatements = [
  [
    '''
    CREATE TABLE desk_break_log (
      id TEXT PRIMARY KEY,
      desk_break_type TEXT NOT NULL,
      log_date TEXT NOT NULL,
      slot_hour INTEGER NOT NULL,
      slot_minute INTEGER NOT NULL,
      status TEXT NOT NULL,
      fired_at TEXT NOT NULL,
      responded_at TEXT,
      UNIQUE(desk_break_type, log_date, slot_hour, slot_minute)
    )
    ''',
    'CREATE INDEX idx_desk_break_log_log_date ON desk_break_log(log_date)',
  ],
];

const int latestSchemaVersion = 2;

const List<String> createIndexStatements = [
  'CREATE INDEX idx_weight_entry_taken_at ON weight_entry(taken_at)',
  'CREATE INDEX idx_water_entry_logged_at ON water_entry(logged_at)',
  'CREATE INDEX idx_meal_entry_logged_at ON meal_entry(logged_at)',
  'CREATE INDEX idx_exercise_session_performed_at ON exercise_session(performed_at)',
  'CREATE INDEX idx_pain_entry_recorded_at ON pain_entry(recorded_at)',
  'CREATE INDEX idx_dhyana_session_date ON dhyana_session(date)',
  'CREATE INDEX idx_habit_completion_completed_at ON habit_completion(completed_at)',
  'CREATE INDEX idx_reminder_scheduled_for ON reminder(scheduled_for)',
  'CREATE INDEX idx_desk_break_log_log_date ON desk_break_log(log_date)',
];
