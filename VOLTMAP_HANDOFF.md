# VoltMap Project Handoff

Use this document on the other computer to continue the same project.

## Project links

- GitHub repository: https://github.com/Suriram2000/Voltmap
- Live test site: https://suriram2000.github.io/Voltmap/
- Latest merged work: https://github.com/Suriram2000/Voltmap/pull/10
- Default branch: `main`
- GitHub account: `Suriram2000`

## Current status

VoltMap is a Flutter EV-charging application. The latest changes were implemented, reviewed, merged, deployed to GitHub Pages, and tested in a live browser.

Completed functionality includes:

- Responsive web, Android, and iOS project support.
- Six navigation tabs hardened for phone-sized screens.
- Compact **Add Charger** tab with validation.
- Charger reports saved locally as pending and submitted through a moderated GitHub issue flow.
- India-only place and PIN-code search.
- PIN `500079` resolves to the Karmanghat/Vaishalinagar area of southeast Hyderabad.
- Partial searches such as `ben` offer Bengaluru-area suggestions and live Photon results.
- Permission-controlled automatic location detection using Geolocator.
- Non-working chargers display a red **NOT WORKING / UNAVAILABLE** warning and cannot begin charging.
- Profile summarizes saved favorites, trips, bills, and charger reports.
- Premium responsive interface with coordinated light and dark themes.

## Validation completed

- `flutter analyze` passed.
- 13 automated tests passed.
- Flutter production web build passed.
- Android APK build passed in GitHub Actions.
- Unsigned iOS release build passed in GitHub Actions.
- GitHub Pages deployment passed.
- Live browser checks passed for `500079`, `ben`, Add Charger, unavailable charger behavior, desktop layout, and mobile layout.

## Important limitation

Login and user data are currently stored only on the device. Favorites, saved trips, bills, charger reports, and accounts do not synchronize between devices. Cross-device accounts require a hosted authentication and database backend such as Firebase or Supabase.

## Set up on the other computer

1. Sign into GitHub as `Suriram2000`.
2. Install Git, Codex, Flutter, and the required Android/iOS development tools.
3. Clone the repository:

   ```powershell
   git clone https://github.com/Suriram2000/Voltmap.git
   cd Voltmap
   git checkout main
   git pull origin main
   ```

4. Open the cloned `Voltmap` folder as a project in Codex.
5. Give Codex the continuation prompt below.

## Continuation prompt for Codex

```text
Continue development of VoltMap from the current main branch of
https://github.com/Suriram2000/Voltmap.

First read VOLTMAP_HANDOFF.md, inspect the repository and Git history, run
git status, confirm the latest merged PR is #10, and verify the live site at
https://suriram2000.github.io/Voltmap/. Preserve all existing functionality.

Before changing code, run Flutter analysis and tests. Make new work on a
separate codex/ branch, test web and applicable mobile builds, open a pull
request, merge only after checks pass, deploy GitHub Pages, and verify the
live URL. Do not overwrite unrelated changes. Clearly report any credentials,
backend setup, or user decisions needed.
```

## Recommended next milestone

Implement a hosted authentication and database backend so accounts, favorites, trips, bills, and charger submissions synchronize securely across devices. This requires choosing a backend and configuring its credentials; do not commit secrets to GitHub.

