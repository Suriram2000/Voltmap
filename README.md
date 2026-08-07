# VoltMap

VoltMap is a polished, responsive Flutter web demo for discovering EV chargers, reviewing station details, saving favorites, planning range-aware trips, and managing a local driver profile.

## Working in the browser

- Search a representative India-wide charger catalog by station, locality, city, state, connector, or PIN code, including formatted PINs such as `500-081`.
- Open charger details, directions, amenities, pricing, and connector data.
- Complete a sandbox charging checkout with UPI, credit/debit card, or VoltMap wallet, then review locally saved receipts.
- Use a premium responsive interface with adaptive mobile navigation, a two-column desktop charger grid, and light or dark appearance.
- Use the interactive offline map without a Google Maps key.
- Save favorites, trips, vehicle information, and preferences in browser storage.
- Switch between light and dark themes.

The bundled nationwide locations, availability, pricing, route calculations, and payment checkout are representative demonstration data rather than a complete live charger inventory. Payment details are validated only in the browser, no real money is charged, and sensitive test details are not saved. Live charger availability, real road routing, authentication, production payments, OCPP/OCPI, and provider roaming require provider APIs, production credentials, and backend services.

## Development

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

GitHub Pages builds use `flutter build web --release --base-href "/Voltmap/"`.
