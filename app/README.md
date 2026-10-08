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
a server, or an API key. Android reminders need notification permission;
exact alarm and battery settings are available in Settings.

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

Interval reminders retain the existing maximum of 16 notifications per
category to limit alarm churn. Water Settings and Desk Breaks show the resulting
count and last reminder time; increase the interval or shorten active hours
when coverage is truncated. Quiet hours suppress reminders in their window.
Physical-device testing is still needed for delivery under Doze, permission
changes, reboots, and platform notification limits.

Meditation measures monotonic elapsed time and excludes paused time. Completion
reconciles delayed callbacks when the app resumes, caps the recorded duration
at the planned length, and retains a paused session if saving fails. Session
state is in memory; it does not survive an OS process kill.

See [the improvement plan and verification log](../docs/2026-10-07-improvement-plan.md)
and [the project plan](../PROJECT_PLAN.md).
