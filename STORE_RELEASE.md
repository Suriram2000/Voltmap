# VoltMapEV App Store and Google Play release

Prepared: 17 August 2026

## Package identity

- App name: VoltMapEV
- Android application ID: `in.voltmap.voltmap`
- Apple bundle ID: `in.voltmap.voltmap`
- Minimum iOS version: `15.0`
- Version: `1.15.2` (`31`)
- Website: `https://voltmapev.com/`
- Support: `skotla100@gmail.com`, `+91 93927 88714`
- Privacy: `https://voltmapev.com/privacy-policy.html`
- Privacy choices/deletion: `https://voltmapev.com/account-deletion.html`
- Terms: `https://voltmapev.com/terms.html`
- Refund policy: `https://voltmapev.com/refund-policy.html`

## Store listing draft

**Name:** VoltMapEV

**Apple subtitle:** EV chargers & trip planner

**Apple keywords:** EV charging,charging stations,EV route planner,nearby chargers,electric vehicle,India

**Apple promotional text:** Find dated public EV charger records across India, compare connector and power details, and plan route-relevant charging stops with clear data-source labels.

**Google Play short description:** Find EV chargers across India and plan trips with route-relevant stops.

**Description:**

VoltMapEV helps EV drivers search public charging-station records across India
by PIN code, area, city, or state. Plan a route and inspect charging options
near the journey instead of browsing an unrelated nationwide list.

- Search thousands of dated public charging-station inventory records
- View connector types, charging power, operator, address, and source details
- Plan range-aware trips with route-relevant charging stops
- Use current location only when you choose
- Verify important stations and directions before travel
- Save favorites and trips in a private local profile
- Submit charger corrections or additions for review

Station availability, tariffs, connector status, and route estimates can
change. Confirm important charging stops with the station operator before
travel. VoltMapEV does not sell electricity or process charging payments in
this release.

### Version 1.15.2 release notes

- Map requests location on open and immediately centers on the device and shows
  nearby chargers after permission is granted
- Saved features can be reviewed through a private local profile without a
  phone number, password, OTP, or external account
- Removed third-party platform references from the iPhone and iPad experience
- Removed unavailable charging-payment controls from the App Store build
- Map search retains keyboard focus when the iOS software keyboard changes the
  available viewport height
- Map markers and the nearby list can consume timestamped operator
  availability and tariffs, with an explicit dated-inventory fallback
- Clearer location permission explanations and nearby-map error states
- Data-source, freshness, availability, and estimated-price labels
- Easier reporting of incorrect station information to VoltMapEV support
- Platform-correct Apple App Store installation links
- Reliability and performance improvements across charger search and maps

### Ethical discoverability plan

No store position can be guaranteed or purchased through metadata. Improve
organic conversion and retention with accurate screenshots, localized India
search terms, a short onboarding path, responsive support, review prompts only
after a successful user outcome, release-note discipline, crash-free sessions,
and honest pricing/data freshness. Never use keyword stuffing, fake ratings,
incentivized reviews, or claims of live/complete data that the app cannot prove.

## Google Play owner actions

1. Create and verify a Google Play Console developer account.
2. Reserve the package `in.voltmap.voltmap`; it cannot be changed after the
   first production upload.
3. Create a dedicated upload keystore and enroll in Play App Signing.
4. Add the four Android signing values documented in the release workflow as
   encrypted GitHub Actions secrets.
5. Complete App access, Ads, Content rating, Target audience, Data safety,
   Account deletion, News, Health, Financial features, and Government-app
   declarations accurately.
6. Upload the signed `.aab` first to Internal testing. Test installation,
   permissions, search, routes, login, account deletion, and all external
   links on real devices before a production rollout.
7. Add phone and tablet screenshots, a 512 px icon, and a 1024×500 feature
   graphic. Do not claim complete/live charger data or real payments.

Current Flutter targets Android API 36, meeting the announced Google Play
requirement for new apps and updates from 31 August 2026.

Android release builds never fall back to the debug signing key. The app also
limits manifest permissions to internet and foreground location, disables
cleartext HTTP, and excludes local app files, preferences, and databases from
Android backup and device transfer. Automated configuration tests protect
these release requirements.

## Apple owner actions

App Store uploads now require Xcode 26 or later and the iOS 26 SDK. The release
workflow verifies both before signing so an outdated runner cannot produce an
upload that Apple will reject.

1. Enroll in the Apple Developer Program and complete identity verification,
   agreements, tax, banking, and trader-status declarations that apply.
2. Register `in.voltmap.voltmap` and create the App Store Connect app record.
3. Create an Apple Distribution certificate, App Store provisioning profile,
   and App Store Connect API key. Store them only as encrypted Actions secrets.
4. Complete App Privacy using the real release behavior and third-party
   services. Use the privacy and deletion URLs above.
5. Upload to TestFlight, test on iPhone and iPad, then provide screenshots,
   review notes, contact details, category, age rating, export-compliance
   answers, and any demo credentials required by App Review.
6. The Account Holder must select the processed build and submit it for review.

### Apple delivery warning resolved for build 15

Apple accepted version 1.11.0 build 14 but reported ITMS-90683. Build 15 adds
`NSLocationAlwaysAndWhenInUseUsageDescription` alongside
`NSLocationWhenInUseUsageDescription`, with a specific explanation of map
centering, nearby stations, distance calculation, and no background tracking.
The automated iOS privacy configuration test prevents either purpose string
from being removed in a future release.

## Encrypted GitHub Actions secrets

Android:

- `ANDROID_UPLOAD_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

iOS:

- `IOS_DISTRIBUTION_CERTIFICATE_BASE64`
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_PROVISIONING_PROFILE_NAME`
- `IOS_KEYCHAIN_PASSWORD`
- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`

Never commit signing files, passwords, API keys, service-account JSON, KYC
documents, or banking information.

## Public GitHub Actions variables

Set these only to deployed HTTPS VoltMapEV server endpoints. They contain no
provider secret, but release builds stay fail-closed when they are absent:

- `VOLTMAP_PAYMENT_API_BASE_URL`
- `VOLTMAP_IDENTITY_API_BASE_URL`
- `VOLTMAP_REALTIME_CHARGER_API_BASE_URL`
