# VoltMapEV Apple App Review response package

Prepared for submission `558a4224-2f0a-4e68-b74d-11a3ceaa8440`, which Apple
rejected under Guideline 2.1 on 15 August 2026 because additional review
information was required. The rejected item was version 1.12.0 build 15.

The next review build is version 1.13.3 build 22. It exposes a clearly labeled
local demo account so App Review can inspect favorites, saved trips, profile
controls, and account deletion without relying on an unconfigured SMS service.
The demo does not send SMS, move money, or use private account data.

## Owner-supplied evidence still required

Do not submit until both placeholders below have been replaced with facts:

- Physical-device video URL: `[ADD REVIEWER-ACCESSIBLE VIDEO URL]`
- Physical test matrix: `[ADD EACH IPHONE/IPAD MODEL AND EXACT IOS/IPADOS VERSION]`

Apple explicitly requires a recording from a physical device running the
latest operating system. Automated tests, a simulator recording, screenshots,
or a generated mockup do not satisfy that request.

## Physical-device recording script

Record one continuous video with no edits and no personal notifications shown:

1. Show the device model and iOS/iPadOS version in Settings, then launch
   VoltMapEV from the Home Screen.
2. Show the launch screen and Discover. Search for `500079`, open a charging
   station, inspect source/connector details, and return to results.
3. Open Map. Turn location sharing on, show the iOS permission prompt, choose
   **Allow While Using App**, and show the centered map plus synchronized nearby
   list. Also demonstrate that manual area/PIN search remains available.
4. Open Trips. Plan `500081` to `500079`, open a route charger, and return to
   the route.
5. Save the trip. On **Verify phone**, choose **Explore with demo account**.
   Show that the trip is saved without SMS or private data.
6. Favorite a station and open Profile. Show the **DEMO DRIVER PROFILE**, saved
   counts, privacy policy, terms, and account-deletion control.
7. Open Addstation, show the required fields, and explain that a completed
   report is stored locally unless the user chooses the private-email action.
8. Open a station's **Charge & Pay** action and show the production safety
   message. No live payment, in-app purchase, subscription, or charging-network
   session is available in this build.
9. Finish by returning to Discover.

## Reply to App Review

Replace the bracketed video and device fields, then paste this response into
the Resolution Center reply and the App Review Information **Notes** field:

---

Hello App Review,

Thank you for the Guideline 2.1 request. The requested information for
VoltMapEV is below.

1. **Physical-device screen recording**

Video: [ADD REVIEWER-ACCESSIBLE VIDEO URL]

The recording begins with a fresh launch on a physical device running the
latest operating system and demonstrates charger search, station details,
optional location permission, the nearby map/list, route planning, the local
review demo, favorites, saved trips, account deletion, Addstation, and the
production payment-unavailable state.

2. **Devices and operating systems tested**

- [DEVICE MODEL] — [EXACT IOS/IPADOS VERSION] — physical device
- [ADD EVERY OTHER PHYSICAL DEVICE AND OS ACTUALLY TESTED]
- CI also runs Flutter analysis, the complete automated test suite, an unsigned
  iOS release build, and a signed App Store package build with Xcode 26 and the
  iOS 26 SDK. CI is supplemental and is not represented as physical testing.

3. **Functions, audience, problem, and value**

VoltMapEV is an India-focused EV charger-discovery and trip-planning app for EV
drivers. It helps users search dated public charging-station records by PIN,
area, city, or state; inspect source, address, operator, connector, and power
information; view nearby results with optional foreground location; plan
range-aware routes; open external navigation; save favorites and trips; and
submit charger corrections for private review. The app labels dated inventory
and does not claim that a station's current availability or tariff is live when
the source does not provide those facts.

4. **Setup, access, and main-feature instructions**

- Charger search, station details, the Map, route planning, navigation, and
  Addstation do not require an account.
- Search example: open Discover, enter `500079`, and select a result.
- Route example: open Trips and plan from `500081` to `500079`.
- Location: open Map and enable the location-sharing switch. The app requests
  foreground access only. If access is denied, use the area/PIN search.
- Saved-feature review: attempt to save a trip or favorite, then tap
  **Explore with demo account** on the Verify phone screen. No username,
  password, SMS, or private data is required. The demo identity is displayed as
  `demo@voltmapev.com`.
- Account deletion: while using the demo, open Profile and choose the account
  and local-data deletion control.
- The submitted production build has no live payment, in-app purchase,
  subscription, or real charging-session purchase. Secure charging remains
  unavailable unless verified server-side identity, payment-provider webhook,
  and charger-meter services are configured. Reviewers should not enter real
  payment credentials.

5. **External services and data sources**

- Bureau of Energy Efficiency / EV Yatra: dated public charging-station
  inventory bundled with the app and labeled with its source date.
- Photon by Komoot, using OpenStreetMap place data: India place autocomplete
  and reverse geocoding.
- Google Maps: opened externally only after the user chooses directions or
  verification.
- The device's configured email application: opened only when the user chooses
  to privately email a charger correction to VoltMapEV support. VoltMapEV does
  not automatically transmit the report.
- VoltMapEV HTTPS identity, charging, and real-time operator endpoints are
  supported by the code but are not configured in this review build. Their
  dependent production features fail closed.
- No advertising SDK, analytics SDK, AI service, or third-party payment SDK is
  active in this review build.

6. **Regional behavior**

VoltMapEV is designed for India. Charger inventory, PIN-code search, the `+91`
phone format, rupee display, and route examples are India-specific. The same
build can launch outside India, but it continues to show India-focused data;
manual India area/PIN search works without granting location. There are no
region-specific paid features or alternate content catalogs.

7. **Regulation and third-party material**

This build is an information and route-planning product. VoltMapEV does not
sell electricity, operate charging equipment, transfer money, provide a
financial service, or offer a live charging-network session. Public station
records are attributed to the Government of India/Bureau of Energy Efficiency,
and third-party names identify station operators or data providers. The build
does not include protected media requiring a content license.

Support contact: skotla100@gmail.com, +91 93927 88714
Privacy policy: https://voltmapev.com/privacy-policy.html
Account deletion: https://voltmapev.com/account-deletion.html
Terms: https://voltmapev.com/terms.html

Thank you.

---

## Submission checklist

- [ ] Install build 22 through TestFlight on each declared physical device.
- [ ] Test with location not determined, allowed while using, denied, and
      denied permanently.
- [ ] Test `500079` Discover search and `500081` to `500079` route planning.
- [ ] Verify the demo path can save a trip/favorite and can delete local data.
- [ ] Confirm production Charge & Pay remains fail-closed and requests no real
      payment data.
- [ ] Record the exact physical-device flow above on the latest OS.
- [ ] Upload the video to a reviewer-accessible URL that does not require an
      invitation, expiring login, or download permission request.
- [ ] Replace both placeholders in the reply.
- [ ] Put the same facts in App Review Information > Notes.
- [ ] Reply in Resolution Center, select the corrected build, and resubmit.
