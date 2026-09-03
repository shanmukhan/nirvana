# Privacy Policy Hosting

Log of how and where Nirvana's privacy policy is hosted, for Play Console's
required privacy policy URL field.

## Where it lives

- **Source of truth:** [`privacy-policy.html`](../privacy-policy.html) at the
  repo root (note: the Flutter app itself lives in `app/`, not the repo
  root — the policy page is intentionally kept separate since it has nothing
  to do with the app build) — a single self-contained static HTML file, no
  build step.
- **Hosted at:** `https://nirvana.shanmukhan.com/privacy-policy` (deliberately
  not the site root — leaves the root free for a real site later), served by
  Apache on the same Raspberry Pi that hosts `shanmukhan.com`/sparkcards,
  `ellieeats.in`, and `vaultzero.in`. Provisioning lives in
  `~/Developer/repo/rpi-setup`, not this repo —
  `scripts/configure-nirvana.sh` +
  `scripts/apache-templates/nirvana.shanmukhan.com.conf.tmpl` own the vhost
  (a `deploy/apache-nirvana.conf` briefly existed in this repo as a
  throwaway first draft, before `rpi-setup` was found/reused — removed).
  Deliberately its own subdomain + cert rather than a path under
  `shanmukhan.com`, so it's managed independently of sparkcards. DocumentRoot
  on the Pi: `/var/www/nirvana`.
- **Play Console privacy policy URL:** `https://nirvana.shanmukhan.com/privacy-policy`
  (confirmed live: `curl -I https://nirvana.shanmukhan.com/privacy-policy` →
  `200`; the earlier root URL no longer serves this content as of 2026-09-03).

## Content basis

The policy text was written from an actual code audit (not boilerplate):

- No analytics/crash/ads SDKs in `pubspec.yaml`.
- No backend, no `http`/`dio` dependency, no HTTP client import anywhere in
  `lib/` — confirmed the app makes zero network requests. All data (weight,
  pain/knee logs, meals, sleep, meditation sessions, habits) lives in a local
  SQLite database (`sqflite`) only.
- The one permission worth explicitly calling out even though nothing is
  transmitted: `PACKAGE_USAGE_STATS`, used by
  `lib/services/phone_usage_service.dart` to read screen on/off event timing
  (not per-app usage) for the continuous-phone-use nudge feature — processed
  entirely on-device.
- The data-export feature (`_BackupCard` in `settings_screen.dart`) shares a
  JSON file via the OS share sheet at the user's explicit action — the app
  itself never uploads it anywhere.

## DNS

`nirvana.shanmukhan.com` — an `A` record already existed pointing at
`122.175.61.81` (this Pi's public IP) as of 2026-09-03, so no DNS change was
needed before setting up the vhost/cert.

## Deploying an update to the policy text

```bash
scp privacy-policy.html lipi@192.168.1.13:/tmp/
ssh lipi@192.168.1.13 'sudo cp /tmp/privacy-policy.html /var/www/nirvana/privacy-policy.html'
```

No Apache reload needed for a content-only change — same static file, same
path (served via an `Alias /privacy-policy` in the vhost, not as the
DocumentRoot's index).
