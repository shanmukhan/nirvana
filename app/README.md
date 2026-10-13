# Nirvana

An offline Flutter health and habit companion for hydration, weight, knee
check-ins, exercise, meals, meditation, desk breaks, and progress history.
The primary targets are Android and iOS; desktop and web scaffolds are not
feature-complete. Phone-usage warnings require Android Usage Access.

## Development

Use Flutter with Dart 3.12.2 or newer (verified with Flutter 3.44.6). Android
builds require SDK 37 and a compatible JDK; the project uses Gradle 9.1.

```sh
cd app # when starting from the repository root
flutter pub get
flutter run
```

The database and preferences are local. The app does not require an account,
a server, or an API key. Allow notification permission from Settings > Reminder status. Logging works
when permission is declined; exact alarm and battery settings are available
in Settings.

## Checks

```sh
flutter analyze
flutter test
flutter build apk --debug --no-pub
```

Tests cover archive validation and rollback, progress and history date ranges,
provider refresh, health-log validation, route parsing, reminder coverage,
and meditation timing/pause/resume. SQLite tests use an in-memory database
and the FFI factory without an isolate.

## Android release

Copy `android/key.properties.example` to the ignored
`android/key.properties`, then fill in `storeFile`, `storePassword`, `keyAlias`,
and `keyPassword`. Keep the keystore and credentials outside version control.
Release tasks fail if signing configuration is missing or invalid; debug
builds do not need release credentials.

```sh
flutter build appbundle --release
```

Gradle also accepts `-PnirvanaSigningPropertiesFile=/path/to/key.properties`
for CI or an alternate credentials location. Use the existing upload key for
updates to the published application.

## Backups and privacy

Settings can export database records and the hydration goal, then preview and
restore a JSON archive. Reminder/phone-usage preferences are not part of the
archive. Restore replaces existing records atomically, validates the archive
before deleting data, and refreshes cached views. Older archives without the
desk-break table remain supported.

Backups are **plaintext private health data**. Store/share them carefully and
export current data before replacing it. The app removes its temporary export
copy after sharing. Archives are limited to 16 MB / 100,000 rows. Android
system cloud backup and device transfer of app data are disabled; explicit
export remains available.

## Reminder and timer behavior

Interval reminders use a maximum of 16 per category on Android and 12 on
iOS. Five iOS interval categories plus three daily reminders consume at most
63 pending requests, reserving one slot within the 64-request budget. Water Settings and Desk Breaks show the resulting
count and last reminder time; increase the interval or shorten active hours
when coverage is truncated. Quiet hours suppress reminders in their window.
Physical-device testing is still needed for delivery under Doze, permission
changes, reboots, and platform notification limits.

Meditation measures monotonic elapsed time and excludes paused time. Completion
reconciles delayed callbacks when the app resumes, caps the recorded duration
at the planned length, and retains a paused session if saving fails. Session
state is in memory; it does not survive leaving its screen or an OS process kill.

See [the latest gap review](../docs/2026-10-12-project-gap-review.md),
[the improvement plan and verification log](../docs/2026-10-07-improvement-plan.md),
and [the project plan](../PROJECT_PLAN.md).


## Toolchain and automation

The repository pins Flutter in `../.flutter-version` and Java in
`../.java-version`. CI checks formatting (100-column Dart style), analysis,
tests, notification sound retention, and an Android debug build. The workflow
has been prepared locally; its first hosted run is still needed.

```sh
python3 ../scripts/check_notification_resources.py
# After a debug/release build, also verify the actual package:
python3 ../scripts/check_notification_resources.py build/app/outputs/flutter-apk/app-debug.apk
```

Reminder preferences and phone-usage preferences in SharedPreferences are
currently authoritative for those settings; SQLite RoutineConfig is authoritative
for hydration settings. Legacy unused RoutineConfig sections are retained for
archive compatibility. No background service depends on screen-owned providers.

Health-log timestamps use canonical local ISO text. Historical calendar days
retain the local time captured when recorded; explicit offsets in imported
archives are converted to the receiving device's local time. Hydration consistency
uses the current goal, including previous days.

The desk-break summary reconciles the last seven days against successfully
scheduled activation/revision history. Unanswered means no response was logged;
OS delivery is unknown. Undated recurring reminders ask which date you are
answering, so a notification left overnight cannot silently overwrite today's log.
