# Nirvana improvement plan

Date: 7 October 2026

Status: all eight implementation items completed; final checks passed. Physical
device verification and larger deferred extensions are listed below.

## Scope and baseline

Review the existing local-first Flutter app, fix demonstrated security and
correctness gaps, improve database and reminder behavior, and add small related
features. Implement the following items sequentially, with focused regression
coverage. Keep health guidance, offline behavior, and existing user data intact.

The initial working tree was clean. No `AGENTS.md` instructions were found.
Baseline: Flutter 3.44.6 / Dart 3.12.2; `flutter analyze` passes and the existing
single dashboard/navigation widget test passes.

## Ordered work

1. **Protect backup restore and add a restore preview.** The importer does not
   check format versions, required tables, column names, or domain values before
   deleting current records; a valid JSON object with empty tables can erase the
   database. Validate the entire archive before mutation, limit file size and
   row count, reject duplicates and broken references, retain transactional
   rollback, and export a consistent database snapshot. Preview record counts
   before the existing replacement confirmation. Refresh cached screen data
   after restore, handle export/picker errors, and remove temporary exports.
   Preserve compatibility with older backups that predate desk-break logs.
2. **Harden Android release and privacy defaults.** Release configuration
   silently falls back to debug signing when credentials are missing. Require
   release signing for release tasks while preserving debug development. Exclude
   private health records and preferences from automatic Android cloud backup
   and device transfer; the explicit JSON export remains available. Document
   the plaintext export and release setup without reading credential contents.
3. **Validate notification and navigation input.** Desk-break payloads and route
   parameters currently use throwing parsers; invalid enum names, clock values,
   or dates can crash navigation. Share validation between notification taps
   and routes, return a usable fallback for invalid links, and add reminder tap
   destinations for dhyana, knee, and weight.
4. **Validate health-log input.** Weight accepts zero, negative, and non-finite
   numbers; custom protein estimates and hydration values lack repository
   validation. Reject invalid values at the persistence boundary and provide
   clear form feedback. Validate hydration configuration to protect goal
   calculations and sliders from invalid persisted/imported values.
5. **Improve progress queries and history accuracy.** Weekly adherence issues
   three queries per day and does not watch meal/exercise changes. Day history
   filters only the ten latest weight/pain records, hiding older entries.
   Use indexed date ranges and SQL aggregates, watch every relevant change,
   and make the advertised 90-day trends use a date window. Test calendar
   boundaries and histories with more than ten records.
6. **Make meditation timing reliable and add pause/resume.** The timer counts
   callbacks rather than elapsed time, so it drifts when callbacks are delayed
   or the app is backgrounded. Use a monotonic elapsed clock, prevent duplicate
   completion, handle async disposal/save errors, and add pause/resume without
   counting paused time. Test elapsed-time and completion behavior.
7. **Expose reminder coverage and guard scheduling inputs.** The scheduler
   silently truncates interval reminders after 16 slots (for example, the
   default eye-break schedule stops before the end of the workday). Retain the
   existing alarm cap and make the resulting coverage visible in Settings and
   Desk Breaks. Share a testable slot planner and guard invalid persisted times
   and intervals. Reload phone-usage preferences before background checks so
   changes made in another isolate are respected.
8. **Finish verification and documentation.** Run formatter, analyzer, focused
   and full tests; inspect the final diff. Replace the scaffold README with
   useful setup/check/release instructions. Record completed work, evidence,
   and platform checks that still need a physical device here.

## Validation approach

- SQLite integration tests: rejected archives preserve data, valid and legacy
  archives round-trip, duplicate/reference failures roll back, aggregates and
  date windows return correct results.
- Unit/widget tests: invalid routes and notifications, invalid form/repository
  input, reminder planning/quiet hours/caps, timer pause/resume and completion,
  and provider refresh behavior.
- Run `flutter analyze`, `flutter test`, and formatting checks after the work.
- Android alarm delivery, notification actions, OS backup behavior, and signed
  release installation require device/build validation; report their actual
  verification status rather than treating unit tests as device verification.

## Deferred extensions

Encrypted portable backups, unified routine/reminder persistence, sleep UI,
weekday/weekend scheduling, and cross-device sync are larger product changes.
Evaluate them separately after the current fixes; avoid adding dependencies or
network services without a demonstrated need.

## Completion log

The plan was created before implementation. Results from the sequential work:

- Backup: added full archive validation, immutable restore previews, consistent
  snapshot export, size/record limits, transactional batched replacement,
  temporary file cleanup, and database-wide provider refresh. Legacy archives
  without desk-break logs remain supported. Regression tests cover destructive
  malformed archives, round-trip, duplicate/reference checks, and rollback.
- Android: release tasks now require explicit signing credentials and a real
  keystore; debug signing fallback removed. Automatic cloud backup and device
  transfer exclude app data. Android 12 needs separate transfer exclusions:
  [Android backup documentation](https://developer.android.com/identity/data/autobackup).
- Navigation: malformed reminder payloads and invalid activity dates are safely
  handled; dhyana/knee/weight notification taps now open their corresponding
  screens. Shared parsing has regression coverage.
- Health input: persistence checks reject non-finite/non-positive measurements,
  invalid ratings, empty meal descriptions, and invalid hydration configuration.
  Weight/protein forms display validation messages and own their controllers.
- Progress: weekly adherence now uses four aggregate queries instead of 22
  record queries, responds to meal/exercise changes, and uses a shared captured
  date. History queries the selected day without a ten-record cutoff; trends
  use 90 calendar days. SQL handles hydration/protein totals and meditation
  weekly totals without loading or truncating session lists. Date boundaries
  use calendar arithmetic rather than 24-hour durations.
- Meditation: elapsed time comes from a monotonic clock; pause/resume excludes
  paused time, resumed apps reconcile delayed callbacks, completion is guarded
  against double saves, and failed saves retain the paused session for retry.
- Reminder coverage: Settings and Desk Breaks show daily reminder counts and
  the final reminder time, including advice for capped/reversed/quiet windows.
  Scheduling and preview share one slot planner; invalid preferences fall back
  to supported values. Phone-usage checks and snooze actions reload preference
  caches before reading settings from another isolate, as required by the
  [package documentation](https://pub.dev/packages/shared_preferences/versions/2.5.5).
  Next-day alarms use calendar construction to preserve local clock time at
  daylight-saving boundaries.

Additional review findings addressed during verification: corrupt legacy
hydration settings fall back safely; completed slider edits clear transient
values so restored goals display correctly; desk-break summaries use SQL counts
and exclude future dates. Website screenshots below the fold will be loaded
on demand, and feature copy now reflects the implemented meditation controls.

UI regression tests also exposed a Progress loading loop: `DateTime.now()` was
used as a family-provider key inside a rebuilding widget, producing a new query
on every provider state update. The Today card now uses a stable calendar date.
Reminder coverage refreshes immediately when quiet hours change on the same
screen. Unknown links offer a working Dashboard button. Form, malformed-route,
and failed-meditation-save retry behavior are covered by widget tests.

## Final verification

| Check | Result |
| --- | --- |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed, 39 tests (baseline: 1) |
| `flutter build apk --debug --no-pub` | Passed, debug APK generated |
| Actual `:app:assembleRelease` with a missing signing-properties path | Rejected with the intended signing-required message before building a release |
| Formatter on changed/new Dart files (`--page-width 100`) | Passed, no pending formatting changes |
| `git diff --check` | Passed |
| Android manifest/extraction XML and website image references | Passed; six below-the-fold screenshots have lazy loading and intrinsic dimensions |

Debug artifact: `app/build/app/outputs/flutter-apk/app-debug.apk`. No release was
published, no real health data was imported, and existing signing credentials
were not moved or exposed. The missing-signing test used the alternate Gradle
properties path described in `app/README.md`.

## Remaining platform checks and limitations

- Test Android/iOS notification taps and delivery on real devices, including
  reboot, Doze, denied/revoked permissions, timezone changes, and extreme
  schedules near platform notification limits. Check phone-usage snooze from
  the background isolate. Scheduling unit tests do not prove OS delivery.
- Verify system backup exclusions and explicit export/share/restore on real
  devices, including iPad share-sheet placement and share cancellation. The
  archive stays plaintext; encryption is a deferred extension.
- Verify meditation resume after device sleep. Session state remains in memory
  and does not survive an OS process kill. The existing 16-slot reminder cap is
  retained and now explained through coverage previews.
- The successful Android build reports existing Kotlin Gradle Plugin/legacy
  Android DSL compatibility warnings (`file_picker`, `flutter_timezone`,
  `share_plus`, `usage_stats`, `workmanager_android`). Track migration before
  upgrading Flutter or Android Gradle Plugin; dependencies were not upgraded
  speculatively during this pass.
- The iOS binary and desktop/web scaffolds were not built during this pass.
  Website and privacy-policy changes are local repository edits awaiting the
  normal publication process.
