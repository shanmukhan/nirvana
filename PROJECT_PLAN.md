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
7. Desk Breaks (eye, movement, knee mobility, neck exercise)
8. Dhyana
9. Progress / History
10. Settings (RoutineConfig editor — this is where "configurable, not hard-coded" is enforced)

## 6. Notification system

Three priority tiers (high/medium/low) with snooze, skip, reschedule, quiet hours, and separate weekday/weekend schedules — full spec in [health-plan-source.md §19](docs/health-plan-source.md). Dhyana reminders sit at medium priority alongside movement/knee-mobility breaks.

### Reminder scheduling (done, first cut)

Every habit reminder — water, dhyana, the four desk breaks (eye/movement/knee-mobility/neck), knee check-in, weigh-in — is now enable/time configurable from **Settings** and actually fires as a local notification, not just a stub screen:

- `app/lib/services/reminder_prefs.dart` — per-category enabled flag + time-of-day (or interval + active window, for water/desk breaks), persisted via SharedPreferences. Stored outside the RoutineConfig/sqflite row for the same reason as the phone-usage settings below: one simple, synchronously-readable store for everything the Settings screen edits, until the full RoutineConfig editor (§7 below) lands.
- `app/lib/services/reminder_scheduler.dart` — turns those prefs into scheduled notifications via `NotificationService.scheduleDaily`. Interval-based categories (water, desk breaks) are expanded into fixed daily clock-time slots across the configured active window rather than a true periodic timer, since `flutter_local_notifications` has no arbitrary-interval repeat and daily fixed-time notifications survive in the background without a WorkManager isolate. Each category owns a fixed notification-id range so `rescheduleAll()` (called on every settings change, and once at app start in `main.dart`) can safely cancel-and-relay everything rather than diffing.
- `app/lib/services/notification_service.dart` — now initializes the `timezone` database and the device's local timezone (via `flutter_timezone`) on startup, and exposes `scheduleDaily(hour, minute, ...)` using `zonedSchedule` with `matchDateTimeComponents: DateTimeComponents.time` (daily repeat) and `AndroidScheduleMode.exactAllowWhileIdle` when available, falling back to inexact otherwise — see the on-device testing note below for why exact is required.
- `app/lib/screens/settings/settings_screen.dart` — one card per category (Water, Dhyana, Desk Breaks, Knee check-in, Weigh-in), each with an enable switch and time/interval pickers that write straight through to prefs and reschedule.
- Android manifest now requests `POST_NOTIFICATIONS` (Android 13+ runtime permission, requested at app start) and `RECEIVE_BOOT_COMPLETED` (so scheduled reminders survive a device reboot).
- Not yet wired: quiet hours, snooze/skip actions on these notifications (the phone-usage warning already has its own snooze action, below), and weekday/weekend schedule variants for dhyana — those land with the full RoutineConfig editor in Phase 3.
- **On-device testing note (Moto G40 Fusion, Android 12):** during initial testing, reminders appeared not to fire at all — `dumpsys alarm` showed the AlarmManager alarm firing on schedule, but no notification channel was ever created and nothing was posted. First root cause found: every `flutter run` redeploy force-stops and reinstalls the app, and Android cancels all of an app's pending alarms on force-stop — so each redeploy silently wiped the just-scheduled test reminder before it could fire (not a bug in the reminder system; just don't redeploy mid-test). Second root cause, found after that was ruled out: reminders were scheduled with `AndroidScheduleMode.inexactAllowWhileIdle`, which lets the OS batch delivery into a window that on this device ran 30-60+ minutes past the target time — useless for a 15-minute-interval reminder. Fixed by switching `NotificationService.scheduleDaily` to `AndroidScheduleMode.exactAllowWhileIdle` whenever exact-alarm scheduling is available (`canScheduleExactAlarms`/`requestExactAlarmsPermission`, both from `flutter_local_notifications`), with the inexact mode kept only as a fallback. `app/lib/services/battery_optimization_service.dart` + the "Background reliability" card in Settings additionally let the user exempt Nirvana from OS/OEM battery optimization (`Permission.ignoreBatteryOptimizations`, via `permission_handler`) and, in the same card, grant the exact-alarms permission if it isn't already — Motorola's battery manager in particular is known to kill backgrounded apps independently of AlarmManager/Doze. Note: adding `permission_handler` required bumping `compileSdk` to 37 in `app/android/app/build.gradle.kts` (the plugin's Android dependency requires it; Flutter's own default hadn't caught up as of this Flutter version).

### Continuous phone usage warning (not in health-plan-source.md — added by request)

Warns when the phone screen has been continuously on for longer than a configurable threshold (default 15 min), with a snooze action button on the notification. Configurable from Settings: enabled/disabled, threshold minutes, snooze minutes (`app/lib/screens/settings/settings_screen.dart`).

- **Android-only.** Detects continuous screen-on time via `UsageStatsManager` (`usage_stats` package), which needs the system "Usage access" permission (`PACKAGE_USAGE_STATS`) — granted from a system settings screen, not a normal runtime dialog. There is no equivalent whole-device usage API on iOS (only per-app usage the app itself can see), so this feature doesn't exist there.
- Runs as a periodic **WorkManager** background task (`app/lib/services/phone_usage_service.dart`) rather than a foreground timer, so it still fires when Nirvana isn't open. WorkManager's Android minimum periodic interval is 15 minutes, which happens to line up with the default threshold.
- Settings are stored in SharedPreferences (`app/lib/services/phone_usage_prefs.dart`), not the RoutineConfig/sqflite row — the WorkManager background isolate has no access to the running app's Riverpod/DB state, and SharedPreferences is readable from both. Revisit once the full RoutineConfig editor (below) lands, if it's worth unifying.
- Not yet verified on-device (device was offline when this was built) — verify the notification + snooze flow actually fires after reconnecting.

## 7. Build phases

### Phase 0 — Foundation (this repo, now)
- Repo scaffold, docs (done)
- Tech stack decision + project init: **Flutter**, scaffolded in `app/` (done)
- `RoutineConfig` schema + local SQLite schema for all entities above (done — see `app/lib/domain/routine_config.dart`, `app/lib/domain/entities.dart`, `app/lib/data/db/`)
- Basic navigation shell for the 10 screens (done — drawer nav + go_router in `app/lib/app_shell/`, stub screens in `app/lib/screens/`; `flutter analyze` and `flutter test` both pass)
- Repository layer over `sqflite` (done — one repo per entity in `app/lib/data/repositories/`, wired via Riverpod providers in `app/lib/providers/`), `flutter_local_notifications` init + priority-tiered Android channels (done — `app/lib/services/notification_service.dart`; scheduling driven by `RoutineConfig` is still open, see Phase 1), 6 `ExerciseDefinition` rows seeded from health-plan-source.md §6 on first launch (done)
- App identity for Play Store: app name **Nirvana**, package/applicationId **com.nirvana.nirvana** (fixed once published — see `app/android/app/build.gradle.kts`)
- App icon + theme: launcher icon generated from `assets/images/Nirvana_Icon_2.png` via `flutter_launcher_icons` (config in `app/pubspec.yaml`, source copied to `app/assets/icon/icon.png`; regenerate with `dart run flutter_launcher_icons` after swapping the source image). In-app Material 3 theme (`app/lib/theme/app_theme.dart`) is seeded from the icon's palette — deep teal, sage green, warm gold — with light/dark variants following system theme mode; the nav drawer header shows the icon on a teal gradient (`app/lib/screens/screen_scaffold.dart`).
- Release signing set up for Play Store submission (done): upload keystore lives at `~/secrets/nirvana/upload-keystore.jks` (outside the repo, not committed), referenced from `app/android/key.properties` (gitignored, local-only — copy `key.properties.example` and fill in your own if setting this up on another machine). `app/android/app/build.gradle.kts` reads it for the `release` build type and falls back to the debug key if `key.properties` is absent. Build with `flutter build appbundle --release` → `app/build/app/outputs/bundle/release/app-release.aab`. **The keystore is the permanent signing identity for all future updates — back it up somewhere durable outside this machine.**

### Phase 1 — MVP: the daily loop
- Dashboard with live data from Water, Weight, Knee, Dhyana (done)
- Hydration: quick-log buttons, progress ring (done); snooze/skip reminders — not yet, no scheduled notifications wired up yet
- Desk breaks: eye, movement, knee-mobility, neck-exercise reminders on configurable intervals — not started (screen is still a stub)
- Dhyana: timer + start/end bell (system-sound stand-in, not a real bell yet) + session log (done — see [dhyana-plan.md](docs/dhyana-plan.md))
- Weight entry + 7-day average + trend (done; trend chart not yet — currently a list + average card)
- Knee pain/swelling/stiffness log with red-flag "consider professional assessment" routing (done, pulled forward from §8/§22)
- Manual exercise logging (no video yet) with pain rating (§8) — done: `app/lib/screens/exercise/exercise_screen.dart` lists the 6 seeded `ExerciseDefinition`s, each opens a log sheet (sets/reps steppers, 0-10 pain-during rating, fine/too-painful feedback) that writes an `ExerciseSession` via `ExerciseRepository.logSession`; a "too painful" entry shows the same non-diagnostic stop-and-consider-assessment message as the Knee screen (§8/§22), never "push through it". Dashboard now has an Exercise card (`N of 6 logged today`) alongside Weight/Water/Knee/Dhyana.
- Desk-break + hydration + dhyana + knee/weigh-in reminder scheduling (done, see §6 "Reminder scheduling" above — configurable per-category from Settings, actual local notifications fire on schedule); quiet hours and snooze/skip on these notifications still open.
- **Phase 1 is now feature-complete** per this plan's scope (all bullets above done). Still open, carried into Phase 2/3 below: illustrated/timed exercise sessions (still manual entry, no timer/video), food logging, and the reminder/notification polish noted in §6.

### Phase 2 — Guided exercise + food
- Exercise screen: timed guided sessions for the 6 strength exercises (§6) — done: `app/lib/screens/exercise/guided_exercise_screen.dart`, reached via a "Start guided" button on each exercise card. Hold-based exercises (Quad Set) get a per-rep countdown ring the user starts when ready (haptic buzz at 0); rep-based exercises get a tap-to-count "+1 rep" flow. Either way, a 30s rest countdown (skippable) runs between sets. On completion (or "Finish now" mid-session), it hands the actual completed sets/reps back to the existing log sheet (`exercise_screen.dart`) to add a pain rating and save — same non-diagnostic "too painful" handling as before. No illustrations/video (still text instructions) and no separate exercise-specific rest-time tuning (fixed 30s) — those remain open if wanted later.
- Food logging against the meal templates in §9–§15, protein estimate — done: `app/lib/domain/meal_templates.dart` has a curated quick-pick template per meal type (breakfast/mid-morning/lunch/evening-snack/dinner) from §9-§13, each with a rough protein estimate; `app/lib/screens/food/food_screen.dart` lets you tap a template to log instantly or "Custom" for free-text + a manual protein number, shows today's entries per meal with delete, and tracks total protein against the 80-100g/day range from §15. `app/lib/data/repositories/meal_repository.dart` is the new repo (the `meal_entry` table already existed in the schema, unused until now). Dashboard gained a matching Nutrition card. Protein estimates are rough planning numbers, not measured nutrition data — consistent with the source doc's own disclaimers.
- Weekly hydration consistency chart, streaks (non-shaming) — done: `WaterRepository.dailyTotalsForLastDays` + `weeklyWaterTotalsProvider`/`waterStreakProvider` in `app/lib/providers/water_providers.dart` back a "This week" card on the Water screen — a 7-day bar chart (each bar shows how full that day got relative to the goal, no red/fail styling for a short day) plus the current consistency streak as a chip. Streak logic doesn't penalize an in-progress today, per §1 ("never guilt the user for a missed day").
- **Phase 2 is now feature-complete** per this plan's scope. Carried forward: illustrations/video for exercises, exercise-specific rest-time tuning (fixed 30s today), and reminder-notification polish (quiet hours, snooze/skip) noted in §6.

### Phase 3 — Progress & polish
- Progress/History screens: weight trend, pain trend, adherence over the 4-month roadmap (§17) — done, first cut: `app/lib/screens/progress/progress_screen.dart` + `app/lib/providers/progress_providers.dart`. Weight and knee-pain trends render as a small custom line chart (`_TrendChart`/`CustomPainter` — no external chart package) over the last 90 days; a "This week" adherence grid shows Water/Dhyana/Exercise/Meals as filled-or-not dots per day. Deliberately non-shaming per §1: an unmet day is just an unfilled dot, never red or flagged as a failure, and charts need ≥2 data points before rendering (shows a plain "log a few entries" prompt otherwise). Not done: adherence rolled up over the full 4-month roadmap (currently only a 7-day window) and month-over-month roadmap-phase tracking (§17's Month 1-4 targets aren't surfaced anywhere yet).
- Notification tuning: quiet hours (§19) — done: `ReminderPrefs.quietHoursEnabled/StartMinutes/EndMinutes` (default 21:30-6:00, mirroring `RoutineConfig`'s default `QuietHoursConfig`) + a `_QuietHours` window check in `app/lib/services/reminder_scheduler.dart` that suppresses any computed reminder time — across every category, not just one — falling inside the window (handles the overnight wraparound). Exposed as a "Quiet hours" card in Settings. **Not done:** a separate weekend/workday schedule and "learn the routine" heuristics — deliberately skipped. A per-weekday schedule would need `DateTimeComponents.dayOfWeekAndTime` scheduling instead of the current daily-repeat model, multiplying the notification-id count per category by up to 5x (some categories already sit near the 30-slot cap), which trades a lot of OS alarm overhead for a feature the default config barely uses (quiet hours already covers the only real day-type difference — overnight). "Learn the routine" (adaptive heuristics) is out of scope for a rules-based local-notification system as built; would need behavior tracking + a scheduling model change, not a small addition.
- Settings: full RoutineConfig editor exposed to the user — done, first cut: `app/lib/data/repositories/routine_config_repository.dart` reads/writes the `routine_config` table's `config_json` blob (which existed since Phase 0 but sat at `'{}'`, unused, until now) via `HydrationConfig.toMap`/`.fromMap`. A "Hydration goal" card at the top of Settings edits the daily water-goal ml value, persisted there — every screen that used to read the hardcoded `defaultHydrationConfig` const (Water, Dashboard, Progress adherence) now reads the live `hydrationConfigProvider` instead. **Scoped, not "full":** only `HydrationConfig.dailyGoalMl`/`quickLogAmountsMl` are wired up — the only RoutineConfig fields actually read anywhere in the app. The rest of the RoutineConfig tree (`DeskBreaksConfig`, `DhyanaConfig`, `ExerciseScheduleConfig`, `NotificationConfig`, `PhoneUsageConfig`, wake/sleep time) is either superseded by the simpler `ReminderPrefs` store already covering the same ground (desk-break intervals, dhyana time, quiet hours) or isn't read by any screen today (`HydrationConfig.slots`, `ExerciseScheduleConfig`, wake/sleep) — building editor UI for config nothing consumes isn't worth it. Unifying `ReminderPrefs` into `RoutineConfig` proper (one persistence model instead of two) is the natural next step if that duplication becomes a real problem.
- **Phase 3, as scoped in this plan, is now feature-complete**, with the exceptions called out above (4-month roadmap rollup, weekend/workday schedule, "learn the routine" heuristics, unified RoutineConfig/ReminderPrefs storage). What's left overall: illustrations/video + rest-time tuning for exercises (Phase 2), notification snooze/skip actions (Phase 1/§6), and Phase 4 (multi-user, cloud sync) if ever needed.

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
      data/
        db/                   # sqflite schema + AppDatabase
        repositories/         # one repository per entity, wraps sqflite
      providers/              # Riverpod providers wiring repositories to screens
      services/               # NotificationService (flutter_local_notifications)
      app_shell/               # go_router routes, nav destinations
      screens/<screen>/       # one folder per v1 screen
      main.dart
    test/
```
