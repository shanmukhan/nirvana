# Release build log

Running log of Play Store release builds — what shipped, and any build
issues found (and fixed) along the way. Same format as
`notification-debugging.md`: keep appending dated entries, don't
overwrite past ones.

## v1.0.5+5 (2026-08-29)

**Command:** `flutter build appbundle --release` from `app/`.

**Output:** `app/build/app/outputs/bundle/release/app-release.aab`
(56.6MB), signed via `android/key.properties` →
`/Users/shanmukhan/secrets/nirvana/upload-keystore.jks`. Confirmed via
the merged release manifest
(`build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`):
`package="com.nirvana.nirvana"`, `versionCode="5"`, `versionName="1.0.5"`.

**What's in this build:** back-button-to-Dashboard navigation, Dashboard
date display, actionable desk-break notifications with adherence
tracking, desk-break settings moved to the Desk Breaks screen, water
notification tap-to-log, custom water amount entry, JSON import/export,
and a custom "Nirvana" notification sound (`nirvana_tone.wav`) — see
`requirements/2026-08-29-ux-and-notification-improvements.md` for the
full spec.

**Version bump:** was `1.0.4+4`; bumped to `1.0.5+5` (minor bump,
`versionCode` +1) since this build adds user-facing features rather than
just a fix.

### Finding — `file_picker` AAR fails `compileSdk` metadata check (2026-08-29)

**Symptom:** `flutter build appbundle --release` failed at
`:file_picker:checkReleaseAarMetadata` with:

```
Dependency ':flutter_plugin_android_lifecycle' requires libraries and
applications that depend on it to compile against version 36 or later
of the Android APIs.
:file_picker is currently compiled against android-34.
```

**Cause:** `pubspec.yaml` pinned `file_picker: ^8.1.7` (added for the
import/export backup feature). That version's precompiled AAR was built
against `compileSdk 34`, which no longer satisfies the `compileSdk 36+`
floor that a newer `flutter_plugin_android_lifecycle` transitive
dependency requires — independent of this app's own `compileSdk`
(already 37, per the `permission_handler` note in
`notification-debugging.md` Finding 2).

**Fix:** bumped `file_picker` to `^10.3.3` in `app/pubspec.yaml`
(resolved to `10.3.10`), which ships an AAR built against a current
`compileSdk`. `flutter pub get` + `flutter analyze` + `flutter test` all
clean afterward; `flutter build appbundle --release` then succeeded.
