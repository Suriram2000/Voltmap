import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/features/discovery/presentation/station_details_screen.dart';
import 'package:voltmap/shared/models/charging_station.dart';

void main() {
  for (final live in [false, true]) {
    testWidgets('zero connectors with live=$live preserves availability safeguards', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ProviderScope(child: MaterialApp(
        home: StationDetailsScreen(station: ChargingStation(
          id: 'station-zero', name: 'Station with zero reported ports',
          network: 'Operator', address: 'Road 36', city: 'Hyderabad',
          state: 'Telangana', postalCode: '500033', distanceKm: 1,
          powerKw: 60, availableConnectors: 0, totalConnectors: 2,
          latitude: 17.43, longitude: 78.40, connectorTypes: const ['CCS2'],
          pricePerKwh: 20, rating: 4, amenities: const [],
          availabilityIsLive: live,
        )),
      )));
      await tester.pumpAndSettle();
      final action = find.byKey(const Key('openCheckoutButton'));
      final button = tester.widget<FilledButton>(action);
      if (live) {
        expect(button.onPressed, isNull);
        expect(find.text('Unavailable'), findsWidgets);
        expect(find.byKey(const Key('unavailableStationBanner')), findsOneWidget);
      } else {
        expect(button.onPressed, isNotNull);
        expect(find.byKey(const Key('unavailableStationBanner')), findsNothing);
        expect(find.text('Listed • verify status'), findsOneWidget);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.text('Charge at this station'), findsOneWidget);
        expect(find.text('₹20.00 per unit'), findsOneWidget);
        expect(find.textContaining('has not started a session or taken payment'), findsOneWidget);
        expect(find.byKey(const Key('productionCheckoutButton')), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
