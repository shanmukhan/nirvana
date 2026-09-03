# Nirvana Site Hosting

Log of how and where Nirvana's public site (home page + privacy policy) is
hosted. The privacy policy URL is also what's registered in Play Console's
required privacy policy URL field.

## Where it lives

- **Home page source of truth:** [`site/index.html`](../site/index.html) +
  [`site/img/`](../site/img) at the repo root — a single self-contained
  static HTML file (icon + a handful of resized screenshots as local
  images), no build step, no JS framework.
- **Privacy policy source of truth:** [`privacy-policy.html`](../privacy-policy.html)
  at the repo root (note: the Flutter app itself lives in `app/`, not the
  repo root — both site files are intentionally kept separate since they
  have nothing to do with the app build).
- **Hosted at:** `https://nirvana.shanmukhan.com/` (home page, site root) and
  `https://nirvana.shanmukhan.com/privacy-policy`, served by Apache on the
  same Raspberry Pi that hosts `shanmukhan.com`/sparkcards, `ellieeats.in`,
  and `vaultzero.in`. Provisioning lives in `~/Developer/repo/rpi-setup`, not
  this repo — `scripts/configure-nirvana.sh` +
  `scripts/apache-templates/nirvana.shanmukhan.com.conf.tmpl` own the vhost
  (a `deploy/apache-nirvana.conf` briefly existed in this repo as a
  throwaway first draft, before `rpi-setup` was found/reused — removed).
  Deliberately its own subdomain + cert rather than a path under
  `shanmukhan.com`, so it's managed independently of sparkcards. DocumentRoot
  on the Pi: `/var/www/nirvana`. `deploy-to-pi.sh` stages `site/index.html` +
  `site/img/` into `rpi-setup/scripts/site-content/nirvana/` and
  `configure-nirvana.sh` installs them into the docroot alongside
  `privacy-policy.html`.
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

## Deploying an update to the policy text or home page

Easiest: re-run the deploy script from `rpi-setup`, which re-stages and
reinstalls both:

```bash
cd ~/Developer/repo/rpi-setup/scripts
./deploy-to-pi.sh lipi@192.168.1.13 Nirvana
```

Or by hand, for a content-only change (no Apache reload needed either way —
same static files, same paths):

```bash
scp privacy-policy.html lipi@192.168.1.13:/tmp/
scp site/index.html lipi@192.168.1.13:/tmp/
scp -r site/img lipi@192.168.1.13:/tmp/
ssh lipi@192.168.1.13 '
  sudo cp /tmp/privacy-policy.html /var/www/nirvana/privacy-policy.html &&
  sudo cp /tmp/index.html /var/www/nirvana/index.html &&
  sudo cp -r /tmp/img/. /var/www/nirvana/img/ &&
  sudo chown -R www-data:www-data /var/www/nirvana
'
```
