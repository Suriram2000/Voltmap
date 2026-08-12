# VoltMap Project Handoff

Use this document on the other computer to continue the same project.

## Project links

- GitHub repository: https://github.com/Suriram2000/Voltmap
- Production site: https://voltmapev.com/
- Legacy GitHub Pages URL: https://suriram2000.github.io/Voltmap/
- Latest merged work: https://github.com/Suriram2000/Voltmap/pull/10
- Default branch: `main`
- GitHub account: `Suriram2000`

## Prompt and work history

This section preserves the user requests that drove the project and the work completed in response. Original wording is retained where it was available in the Codex task history. Older compacted turns are summarized rather than presented as an exact transcript.

### Project publishing and continuation requests

1. **Prompt:** â€œvoltmap checkin alcode and give me U readyâ€
   - Identified the connected GitHub account as `Suriram2000`.
   - Located `Suriram2000/Voltmap`, created a dedicated Codex task, and established the repository as the source of truth.

2. **Prompt:** â€œcheck and give publish url for testingâ€
   - Added Flutter web hosting support and a GitHub Pages deployment workflow.
   - Published the original permanent test site at https://suriram2000.github.io/Voltmap/ and later moved production to https://voltmapev.com/.
   - Verified the public site in a browser.

3. **Prompt:** â€œwhy i'm not able to see projects for same account in other systemâ€
   - Explained that GitHub repositories are account-accessible, while local Codex project folders must be cloned or opened separately on each computer.

4. **Prompt:** â€œdocument i need this in other system so that other system contuniues from hereâ€
   - Created this handoff document with setup steps and a continuation prompt.

5. **Prompt:** â€œcheck inâ€
   - Added the handoff document on branch `codex/add-handoff-document` in draft PR #11.

6. **Prompt:** â€œalso include all my prompts work done by chatgptâ€
   - Expanded the handoff with this prompt/work history for continuation on another computer.

### Product and UI requests

1. **Prompt:** â€œhow to test UI?â€
   - Documented Flutter browser and Android test commands.
   - Identified that the initial repository lacked generated web, Android, and iOS host projects.
   - Later added the missing platform projects and automated build validation.

2. **Summarized prompt:** Build a functional VoltMap application instead of placeholder screens.
   - Added charger discovery, favorites, a custom interactive map, range-aware trip planning, saved trips, editable vehicle/profile settings, theme persistence, and an offline Hyderabad charger dataset.
   - Added GitHub Pages build and deployment automation.
   - Delivered this work through PR #1.

3. **Summarized prompt:** Search chargers by PIN code and show postal codes.
   - Added normalized PIN matching for forms such as `500081`, `500 081`, and `500-081`.
   - Displayed PIN codes on charger cards and details.
   - Added regression coverage and public browser validation.
   - Delivered this work through PR #2.

4. **Summarized prompt:** Improve the applicationâ€™s overall visual design and responsiveness.
   - Added a premium EV-green design system, branded desktop navigation, polished mobile navigation, responsive discovery layouts, richer charger cards, and coordinated light/dark themes.
   - Improved profile, trip, details, checkout, receipt, and favorites layouts.
   - Verified desktop and 390Ã—844 mobile layouts with no browser console errors.
   - Delivered this work through merged PR #5.

5. **Original consolidated usability prompt:**

   > â€œ1. ADD Small TAB for adding new charger or missing charger from public 2.login and signup for trips saving bills favorites best possible 3. non working charges clearly say in red not working or unavailable 4. zip or area should be correct when search 500079 which is south Hyderabad it looks for usa avoid also and depending on location tracking load zip or area automatically automatically 5. make it work flawless in android and apple and any browser and best improvement you like to add app can be user friendly and 6. when i type ben like google it shd get all areas in search dropdown like like googleâ€

   Work completed:

   - Added a compact **Add Charger** tab with validation, device-local pending history, and moderated GitHub submission.
   - Kept public charger additions subject to review so unverified reports do not silently become official station data.
   - Corrected India-only place behavior and mapped PIN `500079` to Karmanghat/Vaishalinagar in southeast Hyderabad.
   - Added partial-area suggestions for searches such as `ben`, including Bengaluru-area results and live India-only Photon results.
   - Added foreground, permission-controlled current-location detection using Geolocator; no background tracking was added.
   - Added prominent red **NOT WORKING / UNAVAILABLE** states and blocked charging actions for unavailable stations.
   - Expanded the profile workspace summary for favorites, trips, bills, and charger reports.
   - Added complete Android and iOS host projects and mobile CI.
   - Hardened all six tabs for phone-sized screens.
   - Added or updated automated tests, reaching 13 passing tests.
   - Built web, Android APK, and unsigned iOS release outputs successfully.
   - Deployed and browser-tested the final result through merged PR #10.

### Delivery timeline

- PR #1: integrated functional offline-first application and initial Pages deployment.
- PR #2: normalized PIN-code charger search.
- PR #5: premium responsive UI redesign.
- PR #10: charger reporting, India location intelligence, unavailable-state safety, geolocation, and Android/iOS hardening.
- PR #11: this cross-system handoff document and prompt/work record.

The Git history and pull requests remain the authoritative detailed record of exact file changes, commits, reviews, and CI runs.

## Current status

VoltMapEV is a Flutter EV-charging application published at https://voltmapev.com/. The latest deployed search release was implemented through pull request #24 and validated with GitHub Actions before deployment.

Completed functionality includes:

- Responsive web, Android, and iOS project support.
- Six navigation tabs hardened for phone-sized screens.
- Public **Addstation** tab with validation and no VoltMapEV signup gate.
- Charger reports saved locally first without signup; sending the prefilled report through the moderated GitHub issue flow is optional.
- India-only place and PIN-code search.
- PIN `500079` resolves to the Karmanghat/Vaishalinagar area of southeast Hyderabad.
- Partial searches such as `ben` offer Bengaluru-area suggestions and live Photon results.
- Permission-controlled automatic location detection using Geolocator.
- Non-working chargers display a red **NOT WORKING / UNAVAILABLE** warning and cannot begin charging.
- Profile summarizes saved favorites, trips, bills, and charger reports.
- Premium responsive interface with coordinated light and dark themes.
- Customer-facing website branding and metadata use **VoltMapEV**.
- Charger lookup, map browsing, charger details, and trip planning are public without signup.
- Email-or-phone signup is requested only for favorites, saved trips, payments, and personal history.
- An About & Contact page publishes `skotla100@gmail.com` and `+919392788714`, with a persistent 2026 copyright footer.
- `skotla100@gmail.com` alone receives the admin dashboard for browser-local account, activity, charger-report, and demo-payment summaries. Credential hashes and payment credentials are never displayed.

### Search and launch release (PR #24, 11 August 2026)

The deployed release adds:

- smoother iOS/macOS bounce physics and touch, trackpad, stylus, and mouse drag support;
- lazy rendering for the unfiltered 45-card discovery grid, avoiding a full card rebuild during search;
- a bounded lazy location-suggestions list with drag-to-dismiss keyboard behavior;
- same-tab live charger results using Open Charge Map on web, Android, and iOS;
- exact offline centering for PIN `500079` at Karmanghat/Vaishalinagar (`17.3366, 78.5349`);
- visible Open Charge Map/OpenStreetMap attribution, a community-data warning, and a separate Google Maps verification action;
- release Android internet permission and consistent VoltMapEV Android/iOS display names;
- search-engine metadata and crawler files, expanded sandbox payment validation, launch-readiness guidance, and an hourly read-only quality script.

Validation for this release included clean Flutter analysis, 39 passing automated tests, a successful production web build, Android and unsigned iOS GitHub Actions builds, and an iPhone-sized live-browser walkthrough. The walkthrough confirmed that `500079` stays inside VoltMapEV and the embedded map exposes 11 community charger markers in the tested viewport.

### Inline official charger list (12 August 2026)

The charger search no longer navigates to a separate results screen or offers a community/live map. PIN and area searches render the **Official BEE station list** directly below the Discover search field. The list loads 25 cards at a time for smooth mobile scrolling while keeping every result available through **Show more chargers**. An explicit **Verify on Google Maps** button remains available in the results header and opens Google only when tapped; normal search never redirects. The list is generated reproducibly from BEE's station-level publication dated 26 October 2025, split into state assets for fast loading, and presents exact PIN matches first followed by all official stations within the displayed search radius. For PIN `500079`, the generated data contains 2 exact-address matches and 235 official stations within 15 km of the selected center. The BEE source is a dated inventory and does not claim live working status, access, or price.

## Validation completed

- `flutter analyze` passed.
- 39 automated tests passed for PR #24; later releases must meet or exceed this baseline.
- Flutter production web build passed.
- Android APK build passed in GitHub Actions.
- Unsigned iOS release build passed in GitHub Actions.
- GitHub Pages deployment passed.
- Live browser checks passed for `500079`, `ben`, Add Charger, unavailable charger behavior, desktop layout, and mobile layout.

## Important limitation

Login and user data are currently stored only on the device. Favorites, saved trips, bills, charger reports, accounts, and the admin dashboard do not synchronize between devices. The admin dashboard therefore reports only the current browser. Cross-device accounts and a global admin user list require a hosted authentication and database backend such as Firebase or Supabase.

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
Continue development of VoltMapEV from the current main branch of
https://github.com/Suriram2000/Voltmap.

First read VOLTMAP_HANDOFF.md, inspect the repository and Git history, run
git status, confirm the latest merged PR is #16, and verify the live site at
https://voltmapev.com/. Preserve all existing functionality.

Before changing code, run Flutter analysis and tests. Make new work on a
separate codex/ branch, test web and applicable mobile builds, open a pull
request, merge only after checks pass, deploy GitHub Pages, and verify the
live URL. Do not overwrite unrelated changes. Clearly report any credentials,
backend setup, or user decisions needed.
```

## Recommended next milestone

Implement a hosted authentication and database backend so accounts, favorites, trips, bills, and charger submissions synchronize securely across devices. This requires choosing a backend and configuring its credentials; do not commit secrets to GitHub.

