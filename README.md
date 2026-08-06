# VoltMap

VoltMap is a responsive Flutter web demo for discovering EV chargers, reviewing station details, saving favorites, planning range-aware trips, and managing a local driver profile.

## Working in the browser

- Search and filter the bundled charger network by station, area, connector, or PIN code.
- Open charger details, directions, amenities, pricing, and connector data.
- Use the interactive offline map without a Google Maps key.
- Save favorites, trips, vehicle information, and preferences in browser storage.
- Switch between light and dark themes.

The bundled locations and route calculations are demonstration data. Live charger availability, real road routing, authentication, charging payments, OCPP/OCPI, and provider roaming require production credentials and backend services.

## Development

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

GitHub Pages builds use `flutter build web --release --base-href "/Voltmap/"`.
