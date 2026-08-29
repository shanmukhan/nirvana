# Requirements: UX, notifications, settings & data (2026-08-29)

Source: user request, logged 2026-08-29. Implemented incrementally, one item
at a time, directly against `app/lib`.

## 1. Back button / left-swipe → Dashboard, not app close

**Current:** Every screen is a top-level `GoRoute` under `ScreenScaffold`.
Android back / iOS edge-swipe on any non-dashboard screen exits or
backgrounds the app instead of returning to the Dashboard.

**Requirement:** From any screen other than the Dashboard, back
gesture/button navigates to `/` (Dashboard). From the Dashboard itself,
back behaves as normal (exits/backgrounds the app).

**Approach:** Wrap `ScreenScaffold`'s body in `PopScope`, intercepting the
pop when the current route isn't `/` and calling `context.go('/')` instead.

**Status:** ✅ Implemented.

## 2. Custom "Nirvana" notification sound

**Current:** All notification channels (`nirvana_high/medium/low`) use the
platform default sound.

**Requirement:** Reminders play a custom "Nirvana" theme sound instead of
the default system sound.

**Constraint:** Needs an actual audio asset (short `.mp3`/`.wav`, ideally
<5s) placed at `android/app/src/main/res/raw/nirvana_notification.mp3` (or
`.wav`) and `ios/Runner/nirvana_notification.aiff` for iOS — **no such file
exists in the repo today** and none was supplied with the request. Android
notification channel sound is also immutable once a channel is created on a
device, so shipping this requires **new channel ids** (old ones stay as a
silent-migration fallback for users who already have the old channels
created).

**Approach:**
- `nirvana_tone.wav` (1.5s, mono, 44.1kHz PCM) added at
  `app/android/app/src/main/res/raw/nirvana_tone.wav` and
  `app/ios/Runner/Resources/nirvana_tone.wav` (registered in
  `Runner.xcodeproj` as a Resources build-phase member).
- Also added under `app/assets/tones/nirvana_tone.wav` + declared in
  `pubspec.yaml` `flutter: assets:` for consistency/potential in-app
  preview use, though native notification sound playback reads the
  platform-bundled copies above, not the Flutter asset bundle.
- Channel ids bumped to `nirvana_high_v2` / `nirvana_medium_v2` /
  `nirvana_low_v2` with
  `sound: RawResourceAndroidNotificationSound('nirvana_tone')`; iOS uses
  `DarwinNotificationDetails(sound: 'nirvana_tone.wav')`. Old `nirvana_*`
  channel ids are no longer scheduled against — Android gives no API to
  delete another app's existing channel, so a user who already had them
  just keeps an orphaned, unused one.
- Applies to every reminder category (water, dhyana, desk breaks, knee/
  weight check-ins) and the phone-usage warning — all go through the
  same `NotificationService` channel constants.

**Status:** ✅ Implemented.

## 3. Show date on Dashboard

**Requirement:** Dashboard shows today's date, in addition to the "Dashboard"
title.

**Approach:** Add the formatted date (e.g. "Fri, Aug 29") as a subtitle
under the app-bar title via `ScreenScaffold`'s optional subtitle slot,
scoped to the Dashboard only (other screens don't need it).

**Status:** ✅ Implemented.

## 4. Actionable desk-break notifications (Eye break, Knee mobility, etc.) with adherence tracking

**Requirement:** Tapping a desk-break notification (Eye break, Movement,
Knee mobility, Neck exercise) opens a small confirmation screen: "Did you do
this?" Yes/No. If the notification is not attended to within a few minutes
of firing, it's automatically logged as "No" (not done). Every outcome
(done / not done / auto-marked) is recorded with timestamp so it can be
shown back to the user later (e.g. an adherence rate per desk-break type).

**Approach:**
- New table `desk_break_log` (id, desk_break_type, notification_fired_at,
  responded_at, status: `done` | `skipped` | `auto_missed`).
- `NotificationService.scheduleDaily`/`showNow` gets an optional `payload`
  (desk-break type + fired-at) attached to the notification.
- `onNotificationResponse` routes to a new `/desk-break-log/:type` screen
  via a payload-driven navigation from `main.dart`.
- Auto-mark-as-missed: schedule a **local zonedSchedule "sweep" job** a few
  minutes after each fired notification that flips any still-`pending` row
  for that notification to `auto_missed`. Since there's no reliable
  cross-platform background timer for "N minutes after this specific
  notification fires" without a foreground app or WorkManager isolate, the
  practical implementation is a **lazy sweep**: any pending row older than
  the threshold gets auto-marked `auto_missed` the next time the app
  opens/reads desk-break logs (Dashboard, Progress, or the log screen
  itself) rather than exactly N minutes after firing in the background.
  This is called out explicitly since it differs from "exactly N minutes
  later even with the app killed."
- Progress screen gets a new "Desk break adherence" section using this log.

**Status:** ✅ Implemented (lazy-sweep auto-miss, not a background-exact
timer — see approach note above).

## 5. Move desk-break-related settings into the Desk Breaks screen

**Current:** All reminder settings, including the four desk-break toggles
and windows, live in one long `SettingsScreen` list.

**Requirement:** Desk-break reminder settings (`_DeskBreaksReminderCard`)
move out of Settings and into the existing Desk Breaks screen, shortening
Settings.

**Status:** ✅ Implemented.

## 6. Water notification sound + tap-to-log amount

**Requirement:** Water reminders get a distinct "water" sound. Tapping a
water notification opens a screen to log how much was drunk (quick-log
buttons + custom amount).

**Sound note:** only one custom tone (`nirvana_tone.wav`, item 2) was
supplied, so water reminders use that same tone rather than a second,
water-specific sound — a distinct one can be dropped in later the same way.

**Approach:** Water notification payload routes to `/water-log` (a focused
log-only screen reusing the quick-log + custom-ml entry from item 8),
instead of navigating into the full Water screen.

**Status:** ✅ Implemented (tap-to-log + the shared `nirvana_tone` sound).

## 7. Timestamp every logged entry

**Current check:** `weight_entry.taken_at`, `water_entry.logged_at`,
`meal_entry.logged_at`, `exercise_session.performed_at`,
`pain_entry.recorded_at`, `dhyana_session.date` — every existing log table
already stores a timestamp captured at write time (`DateTime.now()` in the
respective repository). New table `desk_break_log` (item 4) follows the
same pattern.

**Status:** ✅ Already satisfied by existing schema/repositories; verified,
no change needed beyond keeping the pattern for new tables.

## 8. Water screen: custom amount entry

**Current:** Water screen only has quick-log buttons for the configured
preset amounts.

**Requirement:** Add a way to type a custom ml amount and log it.

**Approach:** A "Custom amount" row (number field + Log button) below the
quick-log `Wrap`, validating a positive integer before calling
`waterRepository.log`.

**Status:** ✅ Implemented.

## 9. Import / export

**Requirement:** User can export their data and re-import it (backup /
device migration).

**Approach:**
- Export: serialize every table in `schema.dart` to a single JSON file
  (`nirvana_backup_<date>.json`), written via `share_plus`/file picker save
  dialog (`file_selector` or platform share sheet — whichever is already
  available; otherwise add `share_plus`).
- Import: pick a previously-exported JSON file, wipe and repopulate all
  tables inside a transaction (destructive — confirm with the user before
  overwriting).
- Surfaced as two buttons in Settings under a new "Data" section.

**Status:** ✅ Implemented (JSON export/import of all tables, share-sheet
export, file-picker import with confirmation).

---

## Implementation order

1. Back button → Dashboard (#1)
2. Dashboard date (#3)
3. Water custom amount (#8)
4. Move desk-break settings (#5)
5. Desk-break log table + notification tap-to-log + adherence (#4)
6. Water notification tap-to-log (#6)
7. Import/export (#9)
8. Custom notification sound (#2, #6 sound half) — `nirvana_tone.wav` supplied and wired up
