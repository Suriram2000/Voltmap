# VoltMapEV App Review response — version 1.15.4 build 34

Prepared for the next submission after the 23 August 2026 Guideline 2.1
rejection of version 1.15.2 build 30. The reviewer could not use the
credentials previously entered in App Store Connect.

## Corrections

### Guideline 2.3.10 — Accurate Metadata

- Removed third-party mobile-platform references from the iPhone and iPad user
  experience, including Profile and the Apple installation disclosure.
- The Apple installation screen shows only the official Apple App Store action.
- Removed the charging-payment screenshot and payment claims from the App Store
  product page because this release does not offer charging payments.

### Guideline 2.1 — Review access

- The App Store build no longer presents a username or password form.
- Profile and every saved-feature access screen present one clear
  **Continue on this device** action.
- This creates a private local profile and provides access to Favorites, saved
  Trips, Profile, settings, and **Delete account & local data**.
- No username, password, phone number, OTP, payment, or private account data is
  required.

### Guideline 2.2 — App completeness

- Removed the unavailable WhatsApp verification flow from the App Store build.
- Removed Charge & Pay and payment-history controls when verified production
  identity, payment, and charger-meter services are not configured.
- Removed beta/demo network labels from the production user experience.
- Charger search, Map, station details, route planning, navigation, favorites,
  saved trips, local-profile deletion, Addstation, and private station feedback
  remain fully usable.

## Reviewer steps

1. Search Discover for `500079`.
2. Open any station to review its source, address, connector, and power details.
3. Open Map. Location is optional; area/PIN search works when permission is
   denied. When permission is granted, the map centers on the device and loads
   nearby chargers immediately.
4. Open Trips and plan from `500081` to `500079`.
5. Open Profile, or save a favorite or trip, and choose
   **Continue on this device**. Do not enter credentials; none are required.
6. Open Profile to inspect the local profile and **Delete account & local data**.

## Reply to App Review

Hello App Review,

Thank you for identifying the review-access issue in version 1.15.2 build 30.
We corrected it in version 1.15.4 build 34.

For Guideline 2.3.10, the iPhone and iPad experience no longer displays
third-party mobile-platform references. The Apple installation screen contains
only the official Apple App Store action. We also removed payment imagery and
claims because charging payments are not offered in this release.

For Guideline 2.1, no credentials are required. The App Store build no longer
shows the ordinary username/password form. Open Profile, or save a favorite or
trip, and tap **Continue on this device**. This local profile provides access
to Favorites, saved Trips, Profile, settings, and account/local data deletion
without a username, password, phone number, OTP, payment, or private data.

For Guideline 2.2, unavailable WhatsApp verification and charging-payment
controls are not shown in the App Store build. The remaining public and saved
features are complete and usable.

Suggested checks: Discover search `500079`; Trips route `500081` to `500079`;
Map with location allowed or denied; save a favorite; then Profile → Delete
account & local data.

Thank you.
