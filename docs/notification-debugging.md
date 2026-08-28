# Notification debugging log

Running log of root causes found (and fixed) while getting reminder
notifications to actually fire reliably on-device, plus anything still
open. Device used for all of this: Moto G40 Fusion, Android 12 (API 31).
Keep appending to this file — don't overwrite past entries — as new
findings come up.

## Finding 1 — force-stop clears pending alarms (2026-08-28, ~14:30-15:00 IST)

**Symptom:** reminders never fired during testing.

**Cause:** every `flutter run -d <device>` redeploy force-stops and
reinstalls the app. Android cancels **all** of an app's pending
`AlarmManager` alarms on force-stop. So each redeploy during a test
window silently wiped the just-scheduled test reminder before it could
fire.

**Fix:** none needed in code — just don't redeploy mid-test. Confirmed
via `adb shell dumpsys alarm` (alarms present before a redeploy, gone
after) and `logcat` showing `Force stopping com.nirvana.nirvana ...
pkg removed` at each reinstall.

## Finding 2 — inexact alarm scheduling batches delivery up to ~1h late (2026-08-28, ~15:00-16:30 IST)

**Symptom:** once Finding 1 was controlled for, a reminder still didn't
fire anywhere near its scheduled time.

**Cause:** `NotificationService.scheduleDaily` used
`AndroidScheduleMode.inexactAllowWhileIdle`. Android is free to batch
inexact alarms into an OS-chosen delivery window to save battery — on
this device, observed windows were 17-60+ minutes past the target time
(`adb shell dumpsys alarm` showed `window=+17m..+60m` on scheduled
alarms). Fine for a "some time this hour" reminder, useless for a
15-minute-interval habit reminder.

**Fix:** `NotificationService` now checks
`canScheduleExactNotifications()` (from `flutter_local_notifications`)
and uses `AndroidScheduleMode.exactAllowWhileIdle` whenever available,
falling back to inexact only if not. Added a "Background reliability"
Settings card with an "Allow exact alarms" button
(`requestExactAlarmsPermission()`) for the rare case it isn't
auto-granted. Also added a battery-optimization-exemption button in the
same card (`BatteryOptimizationService`, `permission_handler`) — separate
Android subsystem, also worth ruling out. Confirmed fix via `dumpsys
alarm` showing `exactAllowReason=permission` on scheduled alarms
afterward.

Note: adding `permission_handler` required bumping `compileSdk` to 37 in
`app/android/app/build.gradle.kts` — Flutter's own default hadn't caught
up to what the plugin's Android dependency required.

## Finding 3 — excessive alarm churn triggers OS-level App Standby throttling (2026-08-28, ~21:30-22:30 IST)

**Symptom:** with both Finding 1 and 2 controlled for — clean redeploy,
exact-alarm permission confirmed granted, battery optimization confirmed
"Unrestricted" in system Settings — a test reminder (Dhyana, set 8
minutes out, app backgrounded) *still* didn't fire. `adb shell dumpsys
alarm` showed the alarm's `origWhen` entry present before the target
time and **gone** after, meaning `AlarmManager` did fire it — but no
notification was posted, no new notification channel appeared, and
`adb logcat` (all buffers, full window around the target time) showed
**zero** trace of `ScheduledNotificationReceiver`/`dexterous` — not even
a crash. For comparison, the *immediate* notification path (the
continuous-phone-usage warning, posted directly by a live Dart isolate
via `NotificationService.showNow`) posted successfully in the same
session, proving the notification pipeline itself works — the failure
is specific to the scheduled-alarm path.

**Cause, found via `adb shell am get-standby-bucket com.nirvana.nirvana`
and `adb shell dumpsys usagestats --standby-buckets`:** the app had been
auto-demoted into Android's **RESTRICTED App Standby Bucket**
(`bucket=45`/shorthand `5`, `reason=u-mb`). This is a *separate* Android
subsystem from both the Doze power-save whitelist (Finding 2's "Battery
optimization: Unrestricted", confirmed still correctly set) and the
exact-alarm permission — being exempt from one doesn't exempt you from
the other, and `adb shell am set-standby-bucket ... active` couldn't
override it (bucket kept reasserting itself, consistent with an
OS/OEM-level policy re-evaluating it rather than a one-off flag).

The trigger: `ReminderScheduler.rescheduleAll()` cancelled and re-laid
**every** reminder category — up to ~150-350 `AlarmManager` alarms
(`adb shell dumpsys alarm | grep -c com.nirvana.nirvana` peaked at 346)
— on **every single Settings edit** (any toggle, slider, or time
picker), because every `onChanged`/`onChangeEnd` handler called
`rescheduleAll()` regardless of which one setting actually changed.
During iterative testing we triggered this dozens of times in under an
hour. Android's alarm-abuse heuristics read that as exactly the
behavior they're designed to throttle, and demoted the app accordingly
— independent of any OEM-specific battery manager.

This is a real product bug, not just a testing artifact: any real user
who tweaks a few reminder settings in one sitting (very plausible —
that's what a first-time setup session looks like) could trigger the
same churn and get the same throttling.

**Fix:** `ReminderScheduler` now exposes per-category methods
(`rescheduleWater`, `rescheduleDhyana`, `rescheduleKneeCheckin`,
`rescheduleWeightCheckin`, `rescheduleDeskBreak(type)`,
`rescheduleAllDeskBreaks()` for the shared active-window fields) instead
of forcing every settings callback through `rescheduleAll()`.
`app/lib/screens/settings/settings_screen.dart` now calls the specific
method for whatever the user just edited — `rescheduleAll()` is called
only from `main.dart` at app startup and from the three Quiet Hours
controls (which legitimately affect every category). Also dropped
`_maxSlotsPerCategory` from 30 to 16 to shrink the absolute alarm count
per category regardless. **Not yet re-verified on-device** — this fix
was written and unit-tested (`flutter analyze`/`flutter test` clean,
debug build compiles) but the live "does a reminder actually fire"
retest after this change hasn't been run yet as of this writing.

**Still open:** no code-level way found to force an app out of the
RESTRICTED bucket once assigned (short of normal continued usage letting
Android's own heuristics re-promote it over time, or the user manually
opening the app periodically). If reminders still misbehave after
retesting Finding 3's fix, check
`adb shell dumpsys usagestats --standby-buckets | grep nirvana` first —
if `bucket=45`/`5` persists despite low alarm churn, that points to
something else keeping it there (worth searching for a
Motorola-specific "adaptive battery" override, since standard Android
`am set-standby-bucket` couldn't clear it in this session).

## Finding 4 — flutter_local_notifications 22.x doesn't bundle its receivers in its own manifest anymore (2026-08-28, ~23:20-23:55 IST)

**Symptom:** on a fresh install (release build, `flutter build apk --release`
+ `flutter install`), with exact-alarm permission confirmed granted and
battery optimization confirmed exempted (Settings > Background reliability
both showed green checks), a scheduled reminder *still* didn't fire.
`adb shell dumpsys alarm` showed the alarm present before the target time
and gone after (fired), and `AlarmManager` stats confirmed exactly one
wake for the app at the target second — but no notification appeared, and
`dumpsys notification --package com.nirvana.nirvana` archive stayed empty.

**Cause, found via `adb shell dumpsys activity broadcasts | grep -A3
nirvana`:** the broadcast targeting
`com.nirvana.nirvana/com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver`
was enqueued at the correct second but its `disp=` (dispatch) timestamp
was epoch zero (`1970-01-01 05:30:00.000`) — i.e. it was never actually
delivered, just immediately marked finished. `adb shell dumpsys package
com.nirvana.nirvana | grep -A3 ScheduledNotificationReceiver` confirmed
why: **the component doesn't exist in the installed package at all.**
`app/android/app/src/main/AndroidManifest.xml` had no `<receiver>` entries
for it, and — unlike older versions — `flutter_local_notifications`
22.3.0's own plugin manifest
(`build/flutter_local_notifications/intermediates/merged_manifest/release/processReleaseManifest/AndroidManifest.xml`)
is minimal (just two `<uses-permission>` tags, no receivers). This plugin
version requires the **app** to manually declare
`ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`, and
`ActionBroadcastReceiver` in its own manifest (confirmed against the
plugin's own `example/android/app/src/main/AndroidManifest.xml` in
`~/.pub-cache`). Without them, AlarmManager fires exactly on schedule but
the broadcast has no component to resolve to and is silently dropped —
no crash, no log line, nothing. This affects **every** reminder category
(water, dhyana, desk breaks, knee check-in, weigh-in), not just one.

**Fix:** added the three missing `<receiver>` blocks to
`app/android/app/src/main/AndroidManifest.xml` inside `<application>`,
copied verbatim from the plugin's example app:

```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
    </intent-filter>
</receiver>
```

Also corrected a stale comment above the `RECEIVE_BOOT_COMPLETED`
permission that claimed the plugin "bundles" its own boot receiver — it
doesn't, as of 22.x. Confirmed the fix via `adb shell dumpsys package
com.nirvana.nirvana | grep -A3 ScheduledNotificationBootReceiver` showing
the component resolvable post-rebuild.

**Note:** this may explain some or all of Findings 1-3 above being harder
to pin down than expected — every retest during those sessions would have
hit this same silent-drop failure mode regardless of alarm-scheduling
correctness, standby bucket, or battery optimization state, since the
receiver was never resolvable in any of those builds either. Re-verify
Finding 3's per-category rescheduling fix now that the actual delivery
path works.

## How to re-run this diagnosis from scratch

```
D=<device-serial>  # adb devices -l

# Is the alarm actually scheduled, and for when?
adb -s $D shell dumpsys alarm | grep -B6 -A6 "com.nirvana.nirvana/com.dexterous"

# Did it fire? (compare pending list before/after target time)
adb -s $D shell dumpsys alarm | grep -c "com.nirvana.nirvana"

# Exact alarm permission granted?
adb -s $D shell dumpsys alarm | grep "exactAllowReason"

# Battery optimization state (should be empty = not on the restricted list)
adb -s $D shell dumpsys deviceidle whitelist | grep nirvana   # should show it (exempted)

# App Standby Bucket — THE ONE THAT'S EASY TO MISS
adb -s $D shell am get-standby-bucket com.nirvana.nirvana
adb -s $D shell dumpsys usagestats --standby-buckets | grep -A1 "package=com.nirvana.nirvana u=0"
# bucket=5/45 (RESTRICTED) or higher throttles background alarm delivery
# even with exact-alarm + battery-optimization both correctly granted.

# Was the notification actually posted?
adb -s $D shell dumpsys notification --noredact | grep -B5 -A20 "pkg=com.nirvana.nirvana"

# Any trace of the receiver running at all?
adb -s $D logcat -d -b all -v time | grep -i "nirvana\|dexterous"

# Is the receiver component even installed? (Finding 4 — check this FIRST,
# before chasing alarm/standby/battery theories again)
adb -s $D shell dumpsys package com.nirvana.nirvana | grep -A3 ScheduledNotificationReceiver
# empty output = the manifest <receiver> entries are missing or got
# stripped from this build; broadcasts will fire and vanish silently

# Did the broadcast actually get dispatched, or just enqueued-and-dropped?
adb -s $D shell dumpsys activity broadcasts | grep -A3 "ScheduledNotificationReceiver"
# disp=1970-01-01 05:30:00.000 (epoch zero) = enqueued but never delivered
```
