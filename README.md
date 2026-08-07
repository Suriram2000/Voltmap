# VoltMap

VoltMap is a responsive Flutter web demo for discovering EV chargers, reviewing station details, saving favorites, planning range-aware trips, and managing a local driver profile.

## Working in the browser

- Search and filter the bundled charger network by station, area, connector, or PIN code.
- Open charger details, directions, amenities, pricing, and connector data.
- Complete a sandbox charging checkout with UPI, credit/debit card, or VoltMap wallet, then review locally saved receipts.
- Use the interactive offline map without a Google Maps key.
- Save favorites, trips, vehicle information, and preferences in browser storage.
- Switch between light and dark themes.

The bundled locations, route calculations, and payment checkout are demonstration data. Payment details are validated only in the browser, no real money is charged, and sensitive test details are not saved. Live charger availability, real road routing, authentication, production payments, OCPP/OCPI, and provider roaming require a payment-gateway account, production credentials, and backend services.

## Development

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

GitHub Pages builds use `flutter build web --release --base-href "/Voltmap/"`.
