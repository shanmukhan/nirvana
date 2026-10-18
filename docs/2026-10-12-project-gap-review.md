# Nirvana project gap review

Date: 12 October 2026

Reviewed revision: `8361e2c` (`1.1.1+11`)

Status: F01–F13 repaired and locally verified. Release-readiness changes are
implemented; unavailable device/hosted checks and feature extensions remain open.
The findings retain the original review evidence; completion details follow.

Scope: the user selected **defects and release-readiness first**. Optional new
features have not been implemented in this pass.

## Implementation progress — 12 October 2026

| Item | Status | Change and verification |
| --- | --- | --- |
| F01 | Completed | Flutter renders before database/platform initialization; database errors show Retry; optional services fail independently with a retry banner. Two startup regression tests passed. |
| F02 | Completed | Exercise reads await shared bootstrap; initial profile/config creation is transactional; app shows bootstrap recovery. Fresh-read and concurrent-bootstrap tests passed, along with startup/navigation checks (5 tests). |
| F03 | Completed | All scheduling mutations share one serialized queue; failures show a global retry banner and the queue recovers. Overlapping disable and failure/retry tests passed. |
| F04 | Completed | Recurring/legacy taps require an explicit occurrence date (Today/Yesterday/calendar); dated payloads preserve their date. Responses update the same occurrence ID. Routing, late-response, progress and form checks passed (15 tests); actual device delivery still needs verification. |
| F05 | Completed | Successful desk schedules retain activation/revision history; reconciliation covers unattended days without inventing preactivation/disabled slots. Unanswered records explicitly carry unknown delivery rather than claiming a missed notification. History/idempotence tests passed. |
| F06 | Completed | Schema v3 preserves full sets plus partial-set reps; zero-work saves are rejected and excluded from adherence. Stop-before-start, partial, rest, full completion and persistence tests passed. |
| F07 | Completed | Hold/rest countdowns use the monotonic clock; leaving the foreground pauses exercise and requires explicit Resume. Delayed-callback/background tests passed; exercise/backup/progress checks passed (28 tests). |
| F08 | Completed | A shared calendar-day provider refreshes at midnight and on resume; today/weekly queries follow it while explicitly selected meditation dates remain selected. Calendar/startup/progress checks passed (10 tests). |
| F09 | Completed | SQLite foreign keys and repository reference validation reject orphan writes. Legacy orphan sessions receive an explicitly labeled recovered definition without losing history; repaired archives round-trip. Integrity/backup/progress tests passed (23 tests). |
| F10 | Completed | Imported and persisted timestamps use canonical local ISO text; date-only/offset/fractional forms are normalized and calendar-only columns remain dates. Existing valid legacy dates are normalized without deleting records. Backup/date regression tests passed. Historical days retain captured local time; imports convert explicit offsets to the receiving device's local time. |
| F11 | Completed | Hydration streaks query backward in 30-day chunks without a 30-day result cap. A 70/71-day streak test passed. The existing current-goal policy is now explicit in Settings, including past consistency. |
| F12 | Completed | Weight/knee/exercise drafts remain open until writes succeed, with save guards and retry feedback; water submissions share an in-flight guard and retain failed amounts. Dashboard failures have Retry controls. Failure/retry, duplicate submission, disposal and existing form/navigation checks passed. |
| F13 | Completed | Phone-use checks reload preferences, honor quiet hours before reading usage, and warn once per observed continuous screen-on session. Quiet-window and duplicate/new-session tests passed. |
| R01 | Completed in code | iOS interval categories are capped at 12 each (60 + 3 daily + 1 reserved = 64); previews use the same cap. The densest supported iOS schedule produced 63 pending requests in the mocked platform test. |
| R02 | Wiring fixed; build/device validation unavailable | iOS explicitly assigns its notification delegate. Xcode is not installed (`xcodebuild -version` fails with the selected CommandLineTools directory); physical foreground/background/cold-launch/sound/share checks remain open. |
| R03 / G10 | Completed in code | App-wide resume checks refresh timezone/permissions and reconcile changed grants; timezone failure stops scheduling rather than silently using UTC. Settings shows actual pending count, blocked channels, permission/timezone state, contextual permission request, test reminder and retry. Scheduler/timezone/startup tests passed; OS delivery still needs devices. |
| E01 | Automated coverage added | Regression coverage now includes startup failure/retry, concurrent bootstrap/scheduling, dated occurrences, historical schedules, exercise interruption/timing, rollover, timestamps, references, streaks and save failures. Real v1/v2 database upgrades preserve records and add default partial reps. Physical integration checks remain open. |
| E02 | CI/toolchain prepared | Added Flutter 3.44.6/Java 17 pins and a read-only CI workflow for formatting, analysis, tests, Android debug build and source/package sound checks. Source retention checks passed. Hosted CI and signed release packaging have not run. |
| E03 | Completed for the current persistence model | Shared health providers now live outside screens; notification parsing uses a plain domain enum. README defines SQLite hydration vs. SharedPreferences reminder/phone authority. Full preference archive migration remains G09. |
| E04 | Local copy corrected | Site/store copy now describes fixed active-hour hydration intervals and sound cues; plan notes reflect quiet hours, platform caps and deferred sleep. Release history distinguishes unreleased source work from published builds. No site/store publication was performed. |
| E05 | Local policy corrected | Privacy copy accurately describes transient API app metadata, local preferences and iOS system-managed backups. It no longer claims the usage-events API returns only screen events. Actual iOS backup behavior still needs a device. |
| G11 | Layout defect fixed; device checks pending | A 400×500, 1.8×-text test reproduced a 270-pixel knee-form overflow. Knee/exercise/meal forms now scroll; the regression passes and weight/water forms also scroll. Detail charts have a screen-reader description and a textual History alternative. TalkBack/VoiceOver/contrast and additional locales still need separate validation. |

## Final repair verification

| Check | Result |
| --- | --- |
| Full regression suite | Passed: 74 tests (review baseline: 39) |
| Static analysis | Passed: no issues |
| Dart formatting (`--page-width 100`, no pending changes) | Passed |
| SQLite v1/v2 upgrades, legacy references and timestamp repair | Passed with preserved records |
| Supported maximum iOS reminder plan | Passed in the platform mock: 63 requests, one slot reserved |
| Small-screen/large-text form and save/navigation checks | Passed |
| CI YAML and notification source retention | Passed locally; hosted CI has not run |
| `flutter build apk --debug --no-pub` | Passed against the final source |
| Packaged notification resources | Passed: all five WAV tones present in the final debug APK |
| `git diff --check` and local documentation links | Passed |

Android artifact: `app/build/app/outputs/flutter-apk/app-debug.apk`.
No signed release or deployed site/store update was performed.

Remaining verification: Xcode/iOS build and real-device notification delivery,
permission/channel revocation, reboot/update/Doze, iPad sharing, system backups,
TalkBack/VoiceOver and contrast. The Android build's existing KGP migration
warnings remain tracked; the Flutter/JDK pins prevent an untested toolchain
upgrade in CI.

Remaining feature backlog: G01–G09 (correction tools, profile editing, sleep,
linked knee follow-ups, routine/action variants, meditation recovery/audio,
longer reporting and expanded backups). G10's reminder diagnostics are implemented;
G11's confirmed layout defect is fixed while device checks and language choices
remain open.

## Original assessment (before repairs)

The app has a working offline daily loop and a much stronger baseline after
the [7 October improvements](2026-10-07-improvement-plan.md). The next useful
investment is reliability and accurate records, followed by correction tools
and personalization. Several problems still occur outside the current tests:
first-launch exercise data can stay empty, overlapping reminder changes can
restore disabled alarms, desk-break responses lose their occurrence date, and
partial exercise sessions are overstated.

The existing backup validation, transactional restore, navigation validation,
health-value validation, indexed progress queries, meditation elapsed clock,
and reminder coverage previews are present. These completed improvements are
not being proposed again.

This review covers Flutter startup, repositories/schema, providers, logging
screens, guided exercise and meditation, notification/background services,
Android/iOS setup, tests, and repository documentation/site copy. No real health
records, signing credentials, deployed website, store listing, or installed
device state were inspected or modified.

Priority means:

- **P1:** address next; core use can fail or records/reminders become misleading.
- **P2:** address in the following reliability/usability pass.
- **P3:** optional extension after the daily loop is dependable.

Evidence labels distinguish **reproduced** behavior from **code-confirmed**
paths and **platform checks** whose device behavior remains unverified.

## Original review verification

| Check | Result |
| --- | --- |
| Initial working tree | Clean; no applicable `AGENTS.md` found |
| `flutter test --no-pub --reporter expanded` | All 39 existing tests passed |
| Dart analyzer using the installed SDK | No issues found |
| Temporary audit probes, outside the repository | All 7 final probes reproduced the behaviors listed below |
| Android/iOS builds, installation, notification delivery | Not performed during this assessment |

The `flutter analyze --no-pub` wrapper could not write the SDK cache under the
workspace sandbox. Static analysis completed successfully using
`/Users/shanmukhan/Developer/flutter/bin/cache/dart-sdk/bin/dart analyze` from
`app/`. The SDK permission failure is an environment constraint, not an app
finding.

The diagnostic probes asserted the current problematic behavior; their passing
results **do not mean these defects are fixed**. They used an in-memory SQLite
database, widget tests, and a mocked notification channel. The final probe file
was `/private/tmp/nirvana-audit-2026-10-12/audit_probe_test.dart`; no regression
tests or implementation changes were added to the project.

## Reliability and correctness findings

### F01 — Startup depends on every optional platform service succeeding

**P1 · Code-confirmed.**

[main.dart](../app/lib/main.dart) opens the database, initializes
notifications, registers phone-usage work, requests permission, and reschedules
all reminders before `runApp()`. These awaits have no recovery boundary.
A notification/plugin error therefore prevents the first Flutter screen from
rendering; slow platform work also delays startup. The prior release log already
records this failure pattern for a missing notification sound.

**Proposed change:** render an initialization/recovery UI; isolate optional
notification/background failures so logging remains usable. Surface database
initialization failures with retry and recovery information. Keep permission
requests in a contextual user flow.

**Acceptance:** injected notification initialization, WorkManager, scheduling,
and database errors produce a usable screen or explicit recovery state; none
leave the app indefinitely at its native splash.

### F02 — First-launch exercise definitions can remain cached as empty

**P1 · Reproduced.**

[userProfileProvider](../app/lib/providers/repository_providers.dart)
asynchronously seeds definitions, while
[exerciseDefinitionsProvider](../app/lib/screens/exercise/exercise_screen.dart)
queries independently. There is no bootstrap dependency or invalidation after
seeding. The audit started both providers on an empty database: the database
ended with six definitions, but the watched definitions provider stayed at zero.
The Dashboard can therefore show an empty exercise library on a fresh install.

**Proposed change:** expose one bootstrap future and make seed-dependent reads
await it. Create the initial profile/config atomically as part of bootstrap.

**Acceptance:** a fresh database reaches six exercises without navigation or
restart; bootstrap failures can be retried without duplicate profile/config
records. Add an assertion beyond the existing navigation-only first-launch test.

### F03 — Overlapping reschedules can leave disabled reminders scheduled

**P1 · Reproduced.**

[ReminderScheduler](../app/lib/services/reminder_scheduler.dart) cancels an
ID range and then schedules its computed slots. Settings callbacks launch these
operations without serialization or revision checks. The audit delayed the
first water schedule, disabled water and completed a second reschedule, then
released the first operation: `waterEnabled()` was false but eight water alarms
remained in the mocked pending set.

**Proposed change:** serialize scheduling mutations or discard superseded
revisions; capture settings coherently. Handle scheduling failures visibly and
allow retry rather than showing only the saved preference.

**Acceptance:** rapidly changing enabled/time/interval/quiet-hours settings
leaves exactly the latest requested schedule, including zero alarms after
disable. Failed scheduling never silently presents itself as successful.

### F04 — A desk-break response is assigned to the tap date

**P1 · Reproduced data path; delayed device tap not exercised.**

The scheduled
[payload](../app/lib/services/reminder_scheduler.dart) and
[notification route](../app/lib/domain/navigation_input.dart) contain only
type/hour/minute. The
[response screen](../app/lib/screens/deskbreaks/desk_break_log_screen.dart)
passes no date, so
[recordResponse](../app/lib/data/repositories/desk_break_log_repository.dart)
uses `DateTime.now()`. A notification left overnight is consequently recorded
against today's slot and can replace today's existing response.

**Proposed change:** retain an occurrence identity/date through delivery and
navigation, or ask the user to confirm the occurrence when a recurring payload
cannot identify it. Make response updates idempotent for that occurrence.

**Acceptance:** responding after midnight updates the original occurrence,
preserves today's separate record, and displays the date/time being answered.
Test warm and cold notification launches.

### F05 — Desk-break adherence is inferred from today's current settings

**P1 · Code-confirmed.**

[sweepAutoMissed](../app/lib/data/repositories/desk_break_log_repository.dart)
only considers today and receives slots generated from current preferences.
[deskBreakAdherenceProvider](../app/lib/providers/desk_break_providers.dart)
runs that sweep when its data is loaded; Dashboard and Progress do not invoke it.
There is no schedule history or delivery/permission evidence.

This has three consequences: previous unattended days are omitted; enabling or
changing reminders later in a day can invent misses for earlier slots that
were never scheduled; and a planned slot can be labeled missed even when
notifications were blocked. The Desk Breaks copy says counting happens shortly
after a notification fires, although no actual fire event is recorded.

**Proposed change:** persist schedule activation/revisions and distinguish
scheduled, responded, and unknown delivery. Reconcile elapsed occurrences
lazily across the reporting window using the historical schedule. Explain the
lazy behavior in the UI.

**Acceptance:** no misses before activation; settings changes do not rewrite
past expectations; unvisited days have a defined reporting policy; blocked or
unknown delivery is not presented as proven user non-compliance.

### F06 — Guided exercise overstates partial work and accepts zero work

**P1 · Partial-count behavior reproduced; zero-work path code-confirmed.**

[\_finishNow](../app/lib/screens/exercise/guided_exercise_screen.dart)
always returns the definition's full rep count and counts a partially completed
set as a completed set. Finishing after one rep of a ten-rep exercise returned
`1 × 10` in the audit. Finishing before any rep can return `0 × 10`; the log sheet
and repository permit zero counts, while dashboard/adherence completion is
based on a session row's existence.

**Proposed change:** preserve full sets and partial-set reps explicitly, with
a clear display convention. Decide whether zero-work attempts should be saved
as attempts, and exclude them from completed-exercise metrics.

**Acceptance:** finishing before the first rep, during a partial set, during
rest, and after final completion records the actual work. An empty attempt
does not mark exercise adherence complete.

### F07 — Exercise countdowns still count callbacks

**P2 · Code-confirmed.**

The guided exercise
[hold](../app/lib/screens/exercise/guided_exercise_screen.dart) and
[rest](../app/lib/screens/exercise/guided_exercise_screen.dart) timers decrement
once per callback. They have no elapsed clock or lifecycle reconciliation;
delayed callbacks can stretch a countdown. Pause/resume is absent. Meditation
already has a tested elapsed-clock implementation that can inform this work.

**Proposed change:** define the background/pause policy for each exercise phase,
then use elapsed time and explicit phase transitions. Retain actual work when
stopping or leaving the screen.

**Acceptance:** delayed callbacks, device sleep/resume, rest skipping, and
pause/resume follow the chosen policy without duplicate reps or transitions.

### F08 — Today-based data has no calendar rollover trigger

**P2 · Code-confirmed.**

[Water](../app/lib/providers/water_providers.dart),
[Dhyana](../app/lib/providers/dhyana_providers.dart), exercise/meal today
providers, and adherence capture `DateTime.now()` when evaluated. They depend
on write counters, not an observable date. The Progress Today card only captures
the date when rebuilt. Keeping a screen open across midnight, or returning to
it from the background, does not reliably refresh yesterday's cached data.
The selected meditation-log date also persists independently.

**Proposed change:** use a shared current-calendar-day provider updated at
midnight and on resume/timezone changes. Make default-today selection distinct
from an explicitly selected historical date.

**Acceptance:** a screen held open through midnight and an overnight background
resume both show the new day's totals/history without requiring a new log.
Explicitly selected past dates remain selected.

### F09 — Repository writes can create records that cannot restore

**P2 · Reproduced.**

[ExerciseRepository.logSession](../app/lib/data/repositories/exercise_repository.dart)
validates counts but does not verify the exercise ID. The schema declares an
exercise reference, but
[AppDatabase](../app/lib/data/db/app_database.dart) does not enable SQLite
foreign-key enforcement. A session referencing `missing-exercise` saved and
exported successfully; importing that same archive was rejected by the stronger
backup reference validator. The ordinary UI supplies known definitions, so this
is a persistence-boundary gap rather than a reproduced normal-screen failure.

**Proposed change:** enforce references at the write boundary and database
level. Audit existing orphan rows before enabling constraints. Review restore
insert ordering before adding profile-to-config constraints.

**Acceptance:** invalid references fail before insertion, existing valid records
remain readable, and every supported database state exports a restorable archive.

### F10 — Accepted backup timestamp forms are incompatible with history queries

**P2 · Reproduced.**

[Backup validation](../app/lib/data/repositories/backup_repository.dart)
allows a date-only string in timestamp columns. The
[date-range queries](../app/lib/data/repositories/date_queries.dart) compare
raw text against full ISO timestamps. Importing a valid weight row with
`taken_at: "2026-10-12"` left it visible in recent entries but invisible in that
day's history. Mixed fractional precision and UTC/local forms also need a
defined representation instead of assuming every accepted string sorts alike.

**Proposed change:** distinguish calendar-date columns from instant columns;
normalize accepted timestamps to one storage representation or reject unsupported
forms. Define how timezone changes affect historical day attribution.

**Acceptance:** every accepted timestamp appears in the intended day and trend
window, including boundary/offset cases. Rejected imports preserve current data.

### F11 — Hydration streaks silently stop at 30 days

**P2 · Reproduced.**

[waterStreakProvider](../app/lib/providers/water_providers.dart) queries only
30 days and reports that count as the current streak. Forty consecutive
goal-met days produced a displayed streak of 30 in the audit.

**Proposed change:** compute the full consecutive streak with bounded/chunked
queries, or explicitly label the metric as consistency within the last 30 days.
Also decide whether past adherence should use the goal in effect at the time;
currently a new hydration goal reclassifies earlier days against the new goal.

**Acceptance:** 31-, 40-, and longer-day runs are accurate or clearly described
as a windowed measure; goal-change history follows a documented product policy.

### F12 — Many log flows lack save failure recovery and duplicate-submit guards

**P2 · Code-confirmed.**

Water quick/custom logging and
[notification logging](../app/lib/screens/water/water_log_screen.dart),
[weight](../app/lib/screens/weight/weight_screen.dart),
[knee](../app/lib/screens/knee/knee_screen.dart), exercise, and desk-break
responses await database writes without consistent error handling or an
in-flight guard. Several sheets close before the write succeeds. Errors can
lose the draft or provide no usable retry, while repeated taps can submit
duplicate water entries. Some paths use `ref`/controllers after awaits without
first checking whether the screen is still mounted. Dashboard errors are often
rendered as a bare dash, hiding a failed read.

**Proposed change:** keep drafts until successful save, show clear retry
feedback, disable submission while saving, and guard disposal. Standardize
loading/empty/error presentation and retry across Dashboard and log screens.

**Acceptance:** injected write/read failures preserve the entered values and
offer retry; repeated taps save once; navigating away during a write causes no
disposed-state errors. Match the stronger meditation save-retry behavior.

### F13 — Phone-usage warnings bypass quiet hours

**P2 · Code-confirmed; policy decision needed.**

[checkAndMaybeWarn](../app/lib/services/phone_usage_service.dart) checks
enabled, Usage Access, threshold, and snooze state, but does not consult quiet
hours. Thus a background warning can sound during the window used to suppress
routine reminders. This exception is not explained in Settings.

**Proposed change:** apply quiet hours to the warning or make its exception an
explicit preference and describe it. Define a repeat-warning policy for the same
continuous session rather than implicitly warning on every eligible worker run.

**Acceptance:** an overnight background check follows the documented quiet-hours
and repeat policy, including snooze and preference changes across isolates.

## Platform readiness checks

### R01 — Enforce a total notification budget

**P1 for iOS readiness · Code plus package documentation; device behavior untested.**

Five interval categories can each schedule 16 entries, plus three daily
check-ins: **83 pending requests** at supported settings. The scheduler has a
per-category cap but no total budget. The pinned plugin documents an iOS limit
of 64 pending notifications. A settings combination can therefore exceed the
documented capacity even when every individual coverage preview looks valid.
The limit is described in the
[22.3.0 package documentation](https://pub.dev/packages/flutter_local_notifications/versions/22.3.0#ios-pending-notifications-limit).

Allocate a platform-wide budget before scheduling, reserve capacity for other
notifications, and show total coverage. Verify actual pending IDs/counts and
delivery under the densest permitted settings. Do not assume the 16-entry cap
also solves Android Doze/OEM delivery constraints.

### R02 — Verify iOS delegate wiring and a complete iOS build

**P1 for iOS readiness · Configuration gap; runtime effect unverified.**

[AppDelegate.swift](../app/ios/Runner/AppDelegate.swift#L8) registers Flutter
plugins but contains no explicit `UNUserNotificationCenter` delegate assignment.
That assignment is part of the pinned plugin's
[iOS general setup](https://pub.dev/packages/flutter_local_notifications/versions/22.3.0#general-setup).
Check how this interacts with the current implicit-engine/scene lifecycle before
claiming foreground presentation and tap callbacks work. The notification WAV
files are present in the Xcode resource build phase, so they are not a missing
resource finding.

Build the iOS target and test foreground, background, and cold-launch reminder
taps, permissions, sounds, and iPad sharing. No iOS build result is recorded
for the latest implementation pass.

### R03 — Refresh scheduling state after timezone and permission changes

**P2 · Code-confirmed lifecycle gap; device consequences untested.**

[NotificationService.init](../app/lib/services/notification_service.dart)
loads the timezone once and silently retains UTC if lookup fails. There is no
app-wide resume reconciliation for timezone changes or notification revocation.
The battery Settings card handles becoming exact-capable only while that card
is mounted; it is not a global scheduler lifecycle. Settings also gives stronger
delivery guarantees than battery/exact-alarm grants alone demonstrate.

Refresh these states centrally on resume, surface permission/channel status and
timezone lookup failure, and reconcile the schedule against the current grants.
Verify travel/timezone changes, exact-alarm grant/revocation, reboot/update,
Doze, blocked channels, and a denied notification permission on real devices.

## Missing features and usability opportunities

These items are separate from the demonstrated defects. Their scope should be
chosen explicitly; model fields or plan bullets alone do not require implementing
every feature immediately.

| ID / priority | Gap and evidence | Proposed outcome / acceptance |
| --- | --- | --- |
| G01 / P2 | Most health logs have no edit/delete/undo path. Meals have delete; weight, water, knee, exercise, and meditation largely expose append-only logs. | Correct an amount/date or remove an accidental entry with confirmation/undo; all affected totals and trends refresh. Add backdated logging where useful. |
| G02 / P2 | The initial profile hardcodes age 41, height 165, left knee, starting weight 72 and target 65–67 in [bootstrap](../app/lib/data/repositories/user_profile_repository.dart). There is no profile editor. Protein targets remain fixed constants. | Provide a small profile/goals editor before broader distribution; persist user choices and show which targets are configurable. Keep health guidance within the existing project boundaries. |
| G03 / P2 if retained in scope | Sleep is named in the plan and has an entity/table, but no repository, provider, route, screen, or dashboard card. | Either implement local bedtime/wake/quality logging with history, or explicitly mark sleep as deferred throughout product documentation. |
| G04 / P2 | Pain-during, pain-after-1–2-hours, and pain-next-morning fields exist, but the Knee form only captures the immediate rating/symptoms. The assessment flag does not use next-day worsening, despite the project's stated follow-up requirement. | Add linked follow-up check-ins and reflect the already documented assessment rules; test capture and presentation without introducing new medical guidance. |
| G05 / P3 | Exercise schedule/progression config is unused. Strength sessions lack illustrations and per-exercise rest settings; walking/activity duration is not a logging flow. | Surface today's configured routine and optional walking/duration logs; add reviewed visual instructions and rest customization if useful. |
| G06 / P2–P3 | Weekday/weekend reminder schedules, a secondary meditation reminder, and snooze/skip for routine reminders remain absent. Phone usage alone has a snooze action. | Add the highest-value schedule/action first, with occurrence IDs and a total notification budget; verify day-specific delivery and adherence semantics. |
| G07 / P2 | Meditation advertises a bell but calls `SystemSoundType.click`. Session state belongs to the screen and is lost on navigation away as well as process death. | Correct the bell claim or implement a bundled sound; protect active-session navigation and consider optional persisted recovery. Test the background completion policy separately from elapsed-time accuracy. |
| G08 / P3 | Progress offers seven-day adherence and 90-day weight/pain views; four-month roadmap phases and meditation practice/mood trends are not surfaced. | Add longer selectable reporting windows and roadmap/mood views after record correctness; distinguish logged/completed/goal-met metrics. |
| G09 / P2–P3 | JSON backups omit reminder/phone preferences, remain plaintext, and replace data rather than merge. These limits are now documented. No selective/date-range CSV/report export exists. | Prioritize full-device migration of preferences with versioned validation; consider optional encrypted archives and readable exports separately. Preserve preview and rollback. |
| G10 / P2 | Notification permission is requested before the first UI; there is no unified reminders-health panel with actual pending coverage or a test notification. | Explain permission in context, display denied/channel/exact-alarm status, offer a test reminder and actionable retry. Keep health logging usable when permission is declined. |
| G11 / P2 before broader release | Large-text, small-screen, keyboard, TalkBack/VoiceOver, dark-mode contrast and chart alternatives have no recorded coverage. Several entry screens use fixed `Column` layouts. App localization delegates/resources are absent. | Record a device/accessibility pass; make forms scroll under large text/keyboard, expose chart values accessibly, and decide supported languages/units. Treat layout failures as unverified until exercised. |

Cloud sync/authentication and multiple profiles remain explicitly deferred in
the project plan. They are optional product decisions, not prerequisites for
improving this offline app.

## Engineering and documentation gaps

- **E01 / P2 — Test coverage misses lifecycle boundaries.** Current SQLite
  helpers create the latest schema directly; there is no v1-to-v2 migration
  fixture, device integration suite, or startup platform-failure test. Add
  focused regression cases for F01–F13, fresh install and restore bootstrap,
  real upgrade data preservation, and permission/background behavior. Extract
  injectable clock/scheduler/platform boundaries where needed.
- **E02 / P2 — No tracked CI/toolchain enforcement.** There is no tracked CI
  workflow, SDK pin, or automated release-resource check. Add format/analyze/test
  and an Android debug build on a pinned Flutter/JDK setup; verify all five
  dynamic notification sounds survive release packaging. Track the already
  recorded Android plugin/Gradle compatibility warnings with a validated
  upgrade plan, not speculative dependency bumps. Keep release signing separate.
- **E03 / P2 — Architecture still couples providers to screens and duplicated
  configuration.** Progress/Dashboard import providers from screen files;
  `domain/navigation_input.dart` imports the service-owned desk-break enum;
  `RoutineConfig`, reminder preferences, and phone preferences overlap. Move
  shared providers/types to stable modules and define the authoritative settings
  model as part of preference migration, avoiding an unnecessary full rewrite.
- **E04 / P2 — Public copy and status documents drift from implementation.**
  [Site copy](../site/index.html) and
  [store draft](play-store-listing.md) promise bedtime-aware hydration taper and
  a start/end bell; current water reminders use one fixed interval and meditation
  uses a system click. The project plan still says quiet hours are unwired in an
  older section and refers to a previous 30-slot cap. The release build log ends
  at `1.0.9+9` while source is `1.1.1+11`; actual shipping status was not verified.
  Reconcile claims, deferred features, cap values and release evidence in one
  checklist; publish only through the normal authorized process.
- **E05 / P2 — Privacy wording should describe the actual usage API boundary.**
  [The policy](../privacy-policy.html) says screen usage reads only on/off
  timing and never which apps are used. Nirvana calls `UsageStats.queryEvents`,
  whose installed `usage_stats 2.0.1` native implementation returns all queried
  events with package/class metadata before Dart ignores everything except
  types 15/16. No storage/transmission of that metadata was found in the reviewed
  path. Narrow acquisition where supported or explain accurately that only
  screen-interactive timing is used and app metadata is not retained. Verify
  iOS system-backup behavior separately; Android exclusions are implemented.

## Suggested implementation order

1. **Protect the core loop:** F01 startup recovery, F02 bootstrap ordering,
   F03 scheduling serialization, F06 actual exercise counts, and F12 safe saves.
2. **Make history dependable:** F04 occurrence dates, F05 historical schedules,
   F08 calendar rollover, F09 references, F10 timestamps, and F11 streak semantics.
3. **Verify platform behavior:** R01–R03, F07 exercise timing, F13 quiet-hours
   policy, migration tests/CI, and the accessibility/device checklist.
4. **Improve daily usability:** correction/undo, profile editing, reminder
   diagnostics, and the promised knee follow-up flow.
5. **Choose optional product scope:** sleep, routine variants, full preference
   migration/encrypted backups, roadmap/mood reporting, and walking guidance.

Use acceptance criteria above to define individual work items. Preserve offline
operation, existing data, and the project's health-guidance boundaries. This
document retains the review baseline; implementation progress is tracked above.
No deployment has been performed.

## 13 October 2026 — Android release preparation

Prepared a signed Android App Bundle for `1.1.2+12`, increasing the version code
from 11. The release build succeeded, signature verification returned
`jar verified`, and all five notification tones survived release packaging.
Final checks passed again: 74 tests, no analyzer issues, clean formatting and
`git diff --check`. The artifact path, checksum, and verifier warnings are recorded
in [the release build log](release-build-log.md).

This prepares the repaired app for manual Google Play upload. No store upload,
publication, or website deployment has been performed. Optional additions remain
deferred under the selected defects-and-release-readiness scope.
