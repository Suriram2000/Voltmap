# VoltMap

VoltMap is a polished, responsive Flutter web demo for discovering EV chargers, reviewing station details, saving favorites, planning range-aware trips, and managing a local driver account.

## Working in the browser

- Create a local Login/Signup account with a salted password hash, persisted session, and logout flow, or enter with the one-click demo account.
- See the Government of India’s official total of 29,277 public charging stations (1 August 2025) with the complete state/UT breakdown.
- Search the 45 detailed VoltMap demo locations by station, locality, city, state, connector, or PIN code, including formatted PINs such as `500-081`.
- Launch a live Google Maps charger search for any Indian PIN code or area, or open the official BEE EV Yatra directory.
- Open charger details, directions, amenities, pricing, and connector data.
- Validate a sandbox UPI ID, credit/debit card, or VoltMap wallet before charging, meter the demo session by actual kWh, and capture the final amount only after charging stops.
- Use a premium responsive interface with adaptive mobile navigation, a two-column desktop charger grid, and light or dark appearance.
- Use the interactive offline map without a Google Maps key.
- Save favorites, trips, vehicle information, and preferences in browser storage.
- Switch between light and dark themes.

The 29,277 figure and state totals are official aggregate data, while the 45 bundled locations, availability, pricing, route calculations, metered sessions, and postpaid checkout are representative demonstration data rather than a complete live charger inventory. Live PIN/area search opens current Google Maps results because BEE’s complete station database is not exposed as an open client API. Only documented sandbox payment credentials are accepted; validation happens in the browser, no real money is charged, and sensitive test details are not saved. Local Login/Signup is browser-only. Real multi-device authentication, UPI/card verification, authorization and capture, live charger telemetry, road routing, OCPP/OCPI, and provider roaming require production credentials and backend services.

Official coverage sources: [Government of India state totals](https://sansad.in/getFile/annex/268/AU1521_5sMm07.pdf?source=pqars) and [BEE EV Yatra](https://evyatra.beeindia.gov.in/).

## Development

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

GitHub Pages builds use `flutter build web --release --base-href "/Voltmap/"`.
