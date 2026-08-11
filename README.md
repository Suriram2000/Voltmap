# VoltMapEV

VoltMapEV is a polished, responsive Flutter web demo for discovering EV chargers, reviewing station details, saving favorites, planning range-aware trips, and managing a local driver account.

Production site: [https://voltmapev.com](https://voltmapev.com)

## Working in the browser

- Create a local Login/Signup account with a salted password hash, persisted session, and logout flow, or enter with the one-click demo account.
- See the Government of India’s official total of 29,277 public charging stations (1 August 2025) with the complete state/UT breakdown.
- Search the 45 detailed VoltMapEV demo locations by station, locality, city, state, connector, or PIN code, including formatted PINs such as `500-081`.
- Launch a live Google Maps charger search for any Indian PIN code or area, or open the official BEE EV Yatra directory.
- Search-as-you-type for Trip starting points and destinations across India using OpenStreetMap/Photon place, locality, address, and PIN data, with major-city aliases available offline.
- Select suggested places for coordinate-based distance and energy estimates, then open the journey in Google Maps for live road directions.
- Open charger details, directions, amenities, pricing, and connector data.
- Validate a sandbox UPI ID, credit/debit card, or VoltMapEV wallet before charging, meter the demo session by actual kWh, and capture the final amount only after charging stops.
- Use a premium responsive interface with adaptive mobile navigation, a two-column desktop charger grid, and light or dark appearance.
- Use the interactive offline map without a Google Maps key.
- Search chargers and plan trips without signing in. Signup with an email address or phone number is required only for favorites, saved trips, charger reports, payments, and personal history.
- Save favorites, trips, vehicle information, and preferences in browser storage.
- Open About and Contact information from the site footer. The private admin dashboard is visible only to `skotla100@gmail.com` and reports browser-local users and demo activity without exposing credential hashes or payment credentials.
- Switch between light and dark themes.

The 29,277 figure and state totals are official aggregate data, while the 45 bundled locations, availability, pricing, charging-stop suggestions, metered sessions, and postpaid checkout are representative demonstration data rather than a complete live charger inventory. Trip autocomplete uses the fair-use Photon public demo API with an offline major-city fallback; selected-place distance is a coordinate-based estimate, while the live directions button opens Google Maps. Live charger PIN/area search opens current Google Maps results because BEE’s complete station database is not exposed as an open client API. Only documented sandbox payment credentials are accepted; validation happens in the browser, no real money is charged, and sensitive test details are not saved. Local Login/Signup is browser-only. Real multi-device authentication, UPI/card verification, authorization and capture, live charger telemetry, first-party road routing, OCPP/OCPI, and provider roaming require production credentials and backend services.

Official coverage sources: [Government of India state totals](https://sansad.in/getFile/annex/268/AU1521_5sMm07.pdf?source=pqars) and [BEE EV Yatra](https://evyatra.beeindia.gov.in/).

## Development

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

GitHub Pages builds use `flutter build web --release --base-href "/"` for the custom domain.
