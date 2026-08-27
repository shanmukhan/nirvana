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
