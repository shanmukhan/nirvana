# Dhyana (Meditation) Module

Dhyana sits alongside hydration, movement, and exercise as a core daily habit — a stillness practice rather than a movement one. The goal is a short, low-friction sitting practice that fits around a desk-work day, not a formal or lengthy meditation program.

## Why it's in scope

- Stress and poor sleep make both weight management and pain perception worse; a brief daily settling practice supports both.
- It's cheap to build (a timer + a bell + a log) and reuses the same reminder/notification infrastructure as the other break types.
- It fits the app's existing principle of consistency over intensity — the same philosophy that governs walking, strength, and diet in the base plan.

## Default schedule

- **Primary session:** ~7:00 PM, 10 minutes, seated, eyes closed, breath awareness. Placed after the evening strength session and before dinner, so it functions as a wind-down transition.
- **Optional secondary session:** a short 3–5 minute session mid-morning (around 11:00 AM) on high-stress or high-meeting days — off by default, toggle in settings.
- **Weekend:** sessions may run longer (15–20 min) since there's no workday time pressure — configurable, never forced.

All times and durations are configurable, same as the rest of the app's schedule.

## Session structure

1. **Settle** (30–60 sec) — sit comfortably, soften the shoulders, a few slow breaths.
2. **Anchor practice** (bulk of the session) — pick one per session, selectable in-app:
   - Breath awareness (count or just observe)
   - Body scan (brief, seated version)
   - Simple mantra/counting
3. **Close** (15–30 sec) — a soft bell, then a slow return of attention to the room.

Sessions should always be guided by a gentle start/end bell, not an abrupt alarm — consistent with the app's existing notification philosophy of not bombarding the user.

## What the app does NOT do

- No pretense of religious instruction or a specific tradition's doctrine — this is a secular stillness/breath practice, and the app should never present it otherwise.
- No streak-shaming or guilt copy for a missed session ("you broke your streak!"). A missed day is just a missed day.
- No forced minimum duration — a 2-minute session still counts as completed.

## Data model addition

`DhyanaSession`:
- `date`
- `plannedDurationMin`
- `actualDurationMin`
- `practiceType` (breath / body-scan / mantra)
- `moodBefore` (optional, 1–5)
- `moodAfter` (optional, 1–5)
- `notes` (optional, free text)

Feeds into `DailySummary` and the Dashboard's Dhyana card (sessions completed today, streak, next reminder) — see [health-plan-source.md §18](health-plan-source.md).

## Notification priority

Medium priority, same tier as movement/knee-mobility breaks (see [health-plan-source.md §19](health-plan-source.md)) — noticeable, but not as insistent as hydration or scheduled exercise, and never fired during an already-active focus block if the app can detect one (future enhancement, not v1).

## Implemented since v1

- **Session log by date** — the Dhyana screen has a date picker (defaults to today) listing every session logged that day: practice type, time, and duration. Backed by `dhyanaSelectedDateProvider` / `dhyanaSessionsForSelectedDateProvider` in `dhyana_providers.dart`.
- **Mood before/after + notes** — `DhyanaSession.moodBefore1to5` / `moodAfter1to5` / `notes` existed in the data model from v1 but weren't wired to any UI. Mood-before is now an optional 1–5 picker in the session setup panel; mood-after and a short note are captured in an optional, skippable dialog when a session ends (`_CloseCheckInDialog`). Both surface in the session log list when present.
- **Weekend session length** — `DhyanaConfig.weekendSession` (17 min default) existed in `routine_config.dart` but nothing read it. The screen now defaults the planned duration to the weekend length on Saturday/Sunday instead of always using the primary (weekday) length.
- **7-day total** — a "Last 7 days: N min sat" line next to the streak (`dhyanaWeekMinutesProvider`), since a bare streak count hides a week that was shorter-but-consistent vs. one long session then nothing.

## Candidate features (not yet implemented)

- **Secondary (mid-morning) session** — `DhyanaConfig.secondarySession` is defined but has no settings toggle and isn't scheduled by `ReminderScheduler`. Needs: a settings card (mirroring `_DhyanaReminderCard`) plus reminder scheduling wiring, so the "optional short session on high-stress days" from the plan above is actually reachable.
- **Real bell sound in-session** — `_start`/`_finish` still play `SystemSound.click` as an explicit stand-in for the "soft bell" described above; `assets/tones/nirvana_dhyana_tone.wav` already exists and is used for the *notification* sound but not the in-app timer. Needs an audio-playback dependency (e.g. `audioplayers`) to play the real tone at session start/end.
- **Edit or delete a logged session** — the session log is currently read-only; a mis-tapped "End now" or wrong practice type can't be corrected without touching the database directly.
- **Manual / backdated session entry** — log a session that happened away from the app (e.g. at a group sit) by hand, with a date/time and duration rather than only via the live timer.
- **Practice-type and mood trends** — a simple breakdown (e.g. minutes by practice type over 30 days, or a mood-before → mood-after delta trend) alongside the existing weight/knee-pain trend charts on the Progress screen.
- **Focus-block suppression** — flagged in the original plan as a future enhancement: skip firing the Dhyana reminder if the app can detect an active focus block.
