# Nirvana — Project Plan

Personal-first health companion covering weight management, knee OA support, hydration, desk-break reminders (eye/movement/posture/knee mobility), dhyana (meditation), exercise, food tracking, sleep, and progress — built for one user first, with configuration built in from day one so it can extend to others later.

Source content:
- [docs/health-plan-source.md](docs/health-plan-source.md) — the full personal health/knee-OA/food/exercise plan this app implements.
- [docs/dhyana-plan.md](docs/dhyana-plan.md) — the meditation module design.

## 1. Product principle

Optimize for **consistency, not perfection** (see [health-plan-source.md §23](docs/health-plan-source.md)). Every feature — reminders, dashboard, streaks — should reinforce showing up daily in a small way, never guilt the user for a missed day, and never present itself as medical diagnosis or treatment (see [health-plan-source.md §22](docs/health-plan-source.md)).

## 2. Target platform

- **Mobile-first** (this is a reminder-driven, all-day companion app — needs to run in the background and push local notifications reliably).
- **Local-first data**: the app must be fully usable offline; sync is a later addition, not a dependency for v1.
- **Decision: Flutter + `sqflite`** (chosen over the React Native/Expo alternative for familiarity). Business logic (reminder scheduling, streak calc, weekly-average calc) lives in plain Dart modules under `lib/domain/` and `lib/data/`, decoupled from UI (`lib/screens/`), so it stays portable.
- Local notifications for all reminder types (hydration, movement, eye, knee mobility, neck/posture, dhyana, exercise) — no server dependency required for the core loop. Package: `flutter_local_notifications`.

## 3. Configurability (the "personal-first, multi-user-later" hook)

Everything currently expressed as a fixed time/value in the source plan (§2 timetable, §3 hydration schedule, break intervals in §4, exercise days in §7) must live in a `UserProfile`/`RoutineConfig` record, not in code. This is the one architectural decision that determines whether the app can later support other users — get the config schema right in v1 even though there's only one user, because retrofitting it later means migrating every reminder and screen.

## 4. Core entities (data model)

From [health-plan-source.md §21](docs/health-plan-source.md), extended with dhyana:

- `UserProfile` — baseline stats, targets, configured schedule/routine
- `RoutineConfig` — configurable times/intervals for every reminder type
- `WeightEntry`
- `WaterEntry`
- `MealEntry`
- `ExerciseSession`, `ExerciseDefinition`
- `PainEntry`
- `DhyanaSession` (see [dhyana-plan.md](docs/dhyana-plan.md))
- `SleepEntry`
- `HabitCompletion`
- `Reminder`
- `DailySummary` — rolled-up view for the dashboard

## 5. Screens (v1 scope)

1. Dashboard / Today — see [health-plan-source.md §18](docs/health-plan-source.md) for exact card list (Weight, Water, Movement, Desk health, Exercise, Nutrition, Knee, Dhyana)
2. Water
3. Exercise (with per-exercise timer/rep/pain-rating flow, §20)
4. Food
5. Weight
6. Knee (pain/swelling/stiffness log, §8)
7. Desk Breaks (eye, movement, knee mobility, posture)
8. Dhyana
9. Progress / History
10. Settings (RoutineConfig editor — this is where "configurable, not hard-coded" is enforced)

## 6. Notification system

Three priority tiers (high/medium/low) with snooze, skip, reschedule, quiet hours, and separate weekday/weekend schedules — full spec in [health-plan-source.md §19](docs/health-plan-source.md). Dhyana reminders sit at medium priority alongside movement/knee-mobility breaks.

## 7. Build phases

### Phase 0 — Foundation (this repo, now)
- Repo scaffold, docs (done)
- Tech stack decision + project init: **Flutter**, scaffolded in `app/` (done)
- `RoutineConfig` schema + local SQLite schema for all entities above (done — see `app/lib/domain/routine_config.dart`, `app/lib/domain/entities.dart`, `app/lib/data/db/`)
- Basic navigation shell for the 10 screens (done — drawer nav + go_router in `app/lib/app_shell/`, stub screens in `app/lib/screens/`; `flutter analyze` and `flutter test` both pass)
- Remaining before Phase 1: wire `flutter_local_notifications` init, decide on a DAO/repository pattern over `sqflite` for the entities, seed the 6 `ExerciseDefinition` rows from health-plan-source.md §6

### Phase 1 — MVP: the daily loop
- Dashboard with live data from Water, Weight, Knee, Dhyana
- Hydration: quick-log buttons, progress ring, reminders with snooze/skip
- Desk breaks: eye, movement, knee-mobility, posture reminders on configurable intervals
- Dhyana: timer + start/end bell + session log (see [dhyana-plan.md](docs/dhyana-plan.md))
- Weight entry + 7-day average + trend
- Manual exercise logging (no video yet) with pain rating (§8)

### Phase 2 — Guided exercise + food
- Exercise screen: illustrated/timed sessions for the 6 strength exercises (§6) with sets/reps/timer/completion/"too painful" feedback
- Food logging against the meal templates in §9–§15, protein estimate
- Weekly hydration consistency chart, streaks (non-shaming)

### Phase 3 — Progress & polish
- Progress/History screens: weight trend, pain trend, adherence over the 4-month roadmap (§17)
- Notification tuning: quiet hours, weekend schedule, "learn the routine" heuristics (§19)
- Settings: full RoutineConfig editor exposed to the user

### Phase 4 — Multi-user readiness (only if/when needed)
- Auth + per-user profile switch
- Optional cloud sync layer on top of the existing local-first store (additive, not a rewrite)

## 8. Safety boundaries (non-negotiable, all phases)

No copy in the app may claim to diagnose, treat, or cure knee OA. Any pain-related flow must follow the stop-and-refer rules in [health-plan-source.md §8](docs/health-plan-source.md) and §22 — sharp pain, significant swelling, locking/giving-way, or next-day worsening all route to a "consider professional assessment" message, never a "push through it" message.

## 9. Repo layout (proposed)

```
nirvana/
  PROJECT_PLAN.md
  docs/
    health-plan-source.md
    dhyana-plan.md
  app/                        # Flutter app
    lib/
      domain/                 # RoutineConfig + entities, plain Dart, no UI/DB deps
      data/db/                # sqflite schema + AppDatabase
      app_shell/               # go_router routes, nav destinations
      screens/<screen>/       # one folder per v1 screen
      main.dart
    test/
```
