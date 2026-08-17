# VoltMapEV

VoltMapEV is a polished, responsive Flutter web demo for discovering EV chargers, reviewing station details, saving favorites, planning range-aware trips, and managing a local driver account.

Production site: [https://voltmapev.com](https://voltmapev.com)

## Working in the browser

- Create a local Login/Signup account with a salted password hash, persisted session, and logout flow, or use the clearly labeled one-click demo account for App Review and feature evaluation.
- See the Government of India’s official total of 29,277 public charging stations (1 August 2025) with the complete state/UT breakdown.
- Search the 45 detailed VoltMapEV demo locations by station, locality, city, state, connector, or PIN code, including formatted PINs such as `500-081`.
- Search an inline BEE Government of India station list for an Indian PIN code or area without leaving Discover, with exact-PIN matches followed by all official records within the displayed radius and an optional Google Maps verification link.
- Search-as-you-type for Trip starting points and destinations across India using OpenStreetMap/Photon place, locality, address, and PIN data, with major-city aliases available offline.
- Select suggested places for coordinate-based distance and energy estimates, then open the journey in Google Maps for live road directions.
- Open charger details, directions, amenities, pricing, and connector data.
- Validate a sandbox UPI ID, credit/debit card, or VoltMapEV wallet before charging, meter the demo session by actual kWh, and capture the final amount only after charging stops.
- Use a premium responsive interface with adaptive mobile navigation, lazy station-card rendering, a smooth bounded location-options list, native-feeling iOS scroll physics, and light or dark appearance.
- Use the interactive offline map without a Google Maps key.
- Search chargers, plan trips, open the sandbox checkout, and save a missing-station report without signing in. Favorites and saved trips use a streamlined `+91` phone-and-OTP preview instead of the old signup dialog; optionally open a private email addressed to the VoltMapEV administrator for review of a saved station report.
- Save favorites, trips, vehicle information, and preferences in browser storage.
- Open About and Contact information from the site footer. The private admin dashboard is visible only to `skotla100@gmail.com` and reports browser-local users and demo activity without exposing credential hashes or payment credentials.
- Switch between light and dark themes.

The 29,277 figure and state totals are official aggregate data. PIN/area results load BEE's station-level publication dated 26 October 2025 directly below Discover search, split by state for fast loading and consolidated into 29,251 unique locations from 39,641 charger/connector rows. The inline list is a dated government inventory rather than live availability. The 45 bundled locations, availability, pricing, charging-stop suggestions, metered sessions, and postpaid checkout remain representative demonstration data. Trip autocomplete uses the fair-use Photon public demo API with an offline major-city fallback; selected-place distance is a coordinate-based estimate, while the live trip-directions button opens Google Maps. Only documented sandbox payment credentials are accepted; validation happens in the browser, no real money is charged, and sensitive test details are not saved. The phone OTP screen is a transparent local preview and displays its preview code because the static site cannot send SMS. Real SMS verification, receipt delivery, multi-device authentication, UPI/card verification, authorization and capture, live charger telemetry, first-party road routing, OCPP/OCPI, and provider roaming require production credentials and backend services.

Official coverage sources: [Government of India state totals](https://sansad.in/getFile/annex/268/AU1521_5sMm07.pdf?source=pqars) and [BEE EV Yatra](https://evyatra.beeindia.gov.in/).

Search, payment, data, advertising, and operational requirements are tracked in [LAUNCH_READINESS.md](LAUNCH_READINESS.md). The web build includes crawler metadata, structured data, `robots.txt`, an XML sitemap, `llms.txt`, and a crawlable India EV charging guide. These improve discoverability but do not guarantee a particular search ranking.

## Development

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

GitHub Pages builds use `flutter build web --release --base-href "/"` for the custom domain.

The local hourly quality suite runs static analysis, all tests with coverage, and a release web build:

```powershell
powershell -ExecutionPolicy Bypass -File tool/hourly_quality.ps1
```
