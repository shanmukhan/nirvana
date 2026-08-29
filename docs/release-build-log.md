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

## v1.0.6+6 (2026-08-29) — hotfix for a stuck-at-splash crash in v1.0.5+5

**Symptom:** after installing the v1.0.5+5 update, the app never got past
the native splash screen — icon displayed, nothing else, no crash dialog.
Zero entries in Play Console's Crashes & ANRs (`Monitor and improve →
Android vitals → Crashes and ANRs`), which was itself a clue: this wasn't
a reported crash, it was a hang before `runApp()`.

**Diagnosis:** connected the affected device via `adb` (USB debugging) and
captured `adb logcat` around a fresh launch (`adb shell am force-stop
com.nirvana.nirvana && adb shell monkey -p com.nirvana.nirvana -c
android.intent.category.LAUNCHER 1`). Found:

```
E flutter : [ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception:
PlatformException(invalid_sound, The resource nirvana_tone could not be
found. Please make sure it has been added as a raw resource to your
Android head project., null, null)
  ...
  #4 NotificationService.scheduleDaily (notification_service.dart:214)
  #5 ReminderScheduler._scheduleWater (reminder_scheduler.dart:160)
  #7 ReminderScheduler.rescheduleAll (reminder_scheduler.dart:54)
  #8 main (main.dart:31)
```

An unhandled exception inside `main()`'s `await
ReminderScheduler.instance.rescheduleAll()` — before `runApp()` — kills
the isolate before Flutter ever renders a frame, so the native splash
just sits there forever with no ANR (nothing is unresponsive to input;
there's no UI yet) and no crash report (Android's crash reporting is
keyed to the activity lifecycle, which never gets that far).

**Root cause:** `app/android/app/src/main/res/raw/nirvana_tone.wav`
(added earlier in this session for the custom notification sound, see
`requirements/2026-08-29-ux-and-notification-improvements.md` item 2)
*was* present in the source tree and made it through Gradle's resource
merge and packaging steps
(`packaged_res/release/packageReleaseResources/raw/nirvana_tone.wav`) —
but was missing from the final AAB
(`base/res/raw/...`, checked via `unzip -l app-release.aab`). Traced it
to Android's **R8 resource shrinker**, which runs on release builds by
default in this project even with no explicit `isMinifyEnabled`/
`isShrinkResources` set in `build.gradle.kts` (confirmed via the
`minifyReleaseWithR8` → `shrunk_resources_proto_format` intermediate,
which no longer contained the raw file). `flutter_local_notifications`
looks the sound resource up by name string at runtime
(`getIdentifier("nirvana_tone", "raw", ...)`) rather than through a
static `R.raw.nirvana_tone` reference, so the shrinker has no static
signal that it's used and strips it as dead weight — silently, with no
build warning.

**Fix:** added `app/android/app/src/main/res/raw/keep.xml`:

```xml
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@raw/nirvana_tone" />
```

the standard Android resource-shrinker "keep" mechanism
(https://developer.android.com/build/shrink-code#keep-resources) for
resources only referenced dynamically. Verified via
`unzip -l app-release.aab | grep res/raw` — `nirvana_tone.wav` now
survives into the shipped bundle.

**Also required a full cache wipe** (`rm -rf android/app/build
android/.gradle build .dart_tool` + `./gradlew --stop`) partway through
diagnosis, purely to rule out stale Gradle/AAPT2 caching as a
contributing factor before concluding it was the shrinker — a plain
`flutter clean` alone was already sufficient once the actual fix
(`keep.xml`) was in place.

**Verification note:** could not do a live on-device relaunch test —
the phone already had v1.0.5+5 installed via Play Store, which Play App
Signing re-signs with Google's own key, so a locally-built,
upload-key-signed APK can't overwrite it via `adb install`
(`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) without first uninstalling (which
would wipe that device's local data — declined). Confirmed the fix
structurally instead (resource present in the final bundle post-shrink)
and shipped it as a normal Play Store update instead, which resolves
signing cleanly.

**Takeaway for future custom raw-resource work:** any Android raw/drawable
resource referenced only by name string from Dart/plugin code (not a
compile-time `R.xxx` reference) needs a `res/raw/keep.xml` (or
equivalent `res/<type>/keep.xml`) entry, or it will silently vanish from
release builds only — debug/profile builds don't shrink resources, so
this class of bug is invisible until a real release build ships.

**Verified this fix doesn't regress:** re-checked after the splash-screen
work below (`unzip -l app-release.aab | grep res/raw` still shows
`nirvana_tone.wav`) since both touch Android resource generation.

## Native splash screen (2026-08-29)

Added a proper native splash screen — previously just a blank white
`launch_background.xml` (the Flutter template default, never customized).

**Image chosen:** `assets/images/Nirvana_Budha_Splash.jpeg` (om symbol +
meditating silhouette, full-bleed dark teal atmosphere with light rays),
over the alternate `assets/images/Nirvana_Splash.jpeg`. Reasoning: the
latter is an icon-on-a-rounded-square-card graphic (looks like an app
icon / store listing mockup) — it has visible card edges that would look
wrong stretched edge-to-edge as an actual splash. The Budha version is
already full-frame poster art with no such framing, so it reads correctly
as a splash screen. Background color `#0a0f28` sampled from the image's
corner pixels (Python/Pillow, `im.getpixel(...)` at all four corners) to
match the letterboxing on screens with a different aspect ratio than the
768×1376 source image.

**Implementation:** used the `flutter_native_splash` package
(`dart run flutter_native_splash:create`) rather than hand-editing
`launch_background.xml`/`LaunchScreen.storyboard` — it generates the
correct per-density Android drawables, handles the Android 12+
`SplashScreen` API (`values-v31/styles.xml`,
`values-night-v31/styles.xml`) which the legacy `windowBackground`
approach doesn't touch, and updates the iOS `LaunchImage` asset catalog,
all from one `pubspec.yaml` config block.

**Android 12+ constraint:** the modern `SplashScreen` API only supports a
centered icon on a solid/gradient background — arbitrary full-bleed
images aren't possible there (OS platform limitation, not a package one).
Config's `android_12:` block falls back to the existing app launcher icon
(`assets/icon/icon.png`) centered on the same `#0a0f28` background for
Android 12+ devices; the full poster art is used for the legacy splash
(pre-Android-12) and as the widget shown immediately after until
`runApp()`'s first frame, via `fullscreen: true`.

**Verification:** `flutter analyze` and `flutter test` clean; confirmed
generated files present — `android/app/src/main/res/drawable*/splash.png`
+ `android12splash.png` per density, `values-v31/styles.xml` with
`android:windowSplashScreenAnimatedIcon`/`windowSplashScreenBackground`,
`ios/Runner/Assets.xcassets/LaunchImage.imageset/*` — and present in a
rebuilt release AAB (`unzip -l` showed `res/drawable-*/splash.png` and
`android12splash.png` entries).
