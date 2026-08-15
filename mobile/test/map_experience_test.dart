import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltmap/features/discovery/data/official_charger_search_service.dart';
import 'package:voltmap/features/discovery/data/official_charger_station.dart';
import 'package:voltmap/features/map/presentation/map_screen.dart';
import 'package:voltmap/shared/models/place_suggestion.dart';
import 'package:voltmap/shared/services/place_search_service.dart';

void main() {
  testWidgets('Map automatically loads location and every nearby charger', (
    tester,
  ) async {
    _useViewport(tester, const Size(1200, 900));
    var locationRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          locationLoader: () async {
            locationRequests++;
            return const MapUserLocation(
              latitude: 17.385,
              longitude: 78.4867,
            );
          },
          placeSearchService: const _FakePlaceSearchService(),
          chargerSearchService: const _FakeChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(locationRequests, 1);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('mapLocationToggle')),
          )
          .value,
      isTrue,
    );
    expect(find.byKey(const Key('nearbyChargerMap')), findsOneWidget);
    expect(find.byKey(const Key('nearbyChargerSidebar')), findsOneWidget);
    expect(find.text('Location sharing enabled'), findsOneWidget);
    expect(find.byKey(const Key('mapLocationSearch')), findsOneWidget);
    expect(find.byKey(const Key('mapFilterButton')), findsOneWidget);
    expect(find.byKey(const Key('mapRecenterButton')), findsOneWidget);
    expect(find.text('Nearby Chargers'), findsOneWidget);
    expect(find.text('2 shown'), findsOneWidget);
    expect(find.text('Alpha Charge - Hyderabad'), findsOneWidget);
    expect(find.text('Beta Charge - Hyderabad'), findsOneWidget);
    expect(find.textContaining('Official BEE inventory'), findsOneWidget);
    expect(
      find.text('Availability: Not published • Price: Not published'),
      findsNWidgets(2),
    );
    expect(find.text('Charging speed: up to 60 kW'), findsOneWidget);
    expect(find.text('Charging speed: up to 22 kW'), findsOneWidget);
    expect(find.byTooltip('Directions in Google Maps'), findsNWidgets(2));
  });

  testWidgets('Map location can be disabled and re-enabled in place', (
    tester,
  ) async {
    var locationRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          locationLoader: () async {
            locationRequests++;
            return _fakeLocation();
          },
          placeSearchService: const _FakePlaceSearchService(),
          chargerSearchService: const _FakeChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('mapLocationToggle'));
    expect(locationRequests, 1);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(find.byKey(const Key('nearbyChargerLocationOff')), findsOneWidget);
    expect(find.byKey(const Key('nearbyChargerMap')), findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(locationRequests, 2);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(find.byKey(const Key('nearbyChargerMap')), findsOneWidget);
  });

  testWidgets('iPhone Map uses a draggable nearby-charger panel', (
    tester,
  ) async {
    _useViewport(tester, const Size(390, 844));

    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(
          locationLoader: _fakeLocation,
          placeSearchService: _FakePlaceSearchService(),
          chargerSearchService: _FakeChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('nearbyChargerBottomSheet')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('nearbyChargerPanel')), findsOneWidget);
    expect(find.text('Nearby Chargers'), findsOneWidget);
    expect(find.text('2 shown'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Map filters markers and nearby list together', (tester) async {
    _useViewport(tester, const Size(1200, 900));

    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(
          locationLoader: _fakeLocation,
          placeSearchService: _FakePlaceSearchService(),
          chargerSearchService: _FakeChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mapFilterButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mapFilter_Fast 50+ kW')));
    await tester.pumpAndSettle();

    expect(find.text('1 shown'), findsOneWidget);
    expect(find.text('Alpha Charge - Hyderabad'), findsOneWidget);
    expect(find.text('Beta Charge - Hyderabad'), findsNothing);
    expect(find.byTooltip('Filter: Fast 50+ kW'), findsOneWidget);
  });

  testWidgets('Map explains location failures and offers retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          locationLoader: () async => throw Exception('location unavailable'),
          placeSearchService: const _FakePlaceSearchService(),
          chargerSearchService: const _FakeChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nearbyChargerError')), findsOneWidget);
    expect(find.text('Charger service is unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Map explains a valid empty nearby result', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(
          locationLoader: _fakeLocation,
          placeSearchService: _FakePlaceSearchService(),
          chargerSearchService: _EmptyChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nearbyChargerNoResults')), findsOneWidget);
    expect(find.text('No nearby chargers found'), findsOneWidget);
    expect(find.byKey(const Key('nearbyChargerMap')), findsNothing);
  });
}

Future<MapUserLocation> _fakeLocation() async => const MapUserLocation(
      latitude: 17.385,
      longitude: 78.4867,
    );

class _FakePlaceSearchService extends PlaceSearchService {
  const _FakePlaceSearchService();

  @override
  Future<PlaceSuggestion?> reverseIndia({
    required double latitude,
    required double longitude,
  }) async {
    return const PlaceSuggestion(
      primaryText: 'Hyderabad',
      secondaryText: 'Telangana, India',
      latitude: 17.385,
      longitude: 78.4867,
      type: 'city',
    );
  }
}

class _FakeChargerSearchService extends OfficialChargerSearchService {
  const _FakeChargerSearchService();

  @override
  Future<OfficialChargerSearchResult> search({
    required String query,
    PlaceSuggestion? center,
  }) async {
    return OfficialChargerSearchResult(
      source: 'BEE',
      sourceUrl: 'https://example.com',
      asOf: DateTime.utc(2026, 8, 1),
      totalStationCount: 2,
      radiusKm: 25,
      matches: const [
        OfficialChargerMatch(
          station: OfficialChargerStation(
            operatorName: 'Alpha Charge',
            ownership: 'Private',
            state: 'Telangana',
            district: 'Hyderabad',
            city: 'Hyderabad',
            address: 'Alpha Road, Hyderabad 500001',
            latitude: 17.39,
            longitude: 78.49,
            postcodes: ['500001'],
            connectors: [
              OfficialChargerConnector(
                type: 'CCS-II',
                ratingKw: 60,
                count: 2,
              ),
            ],
          ),
          distanceKm: 1.2,
          exactPostcode: false,
        ),
        OfficialChargerMatch(
          station: OfficialChargerStation(
            operatorName: 'Beta Charge',
            ownership: 'Private',
            state: 'Telangana',
            district: 'Hyderabad',
            city: 'Hyderabad',
            address: 'Beta Road, Hyderabad 500002',
            latitude: 17.4,
            longitude: 78.5,
            postcodes: ['500002'],
            connectors: [
              OfficialChargerConnector(
                type: 'Type-II AC',
                ratingKw: 22,
                count: 1,
              ),
            ],
          ),
          distanceKm: 2.4,
          exactPostcode: false,
        ),
      ],
    );
  }
}

class _EmptyChargerSearchService extends OfficialChargerSearchService {
  const _EmptyChargerSearchService();

  @override
  Future<OfficialChargerSearchResult> search({
    required String query,
    PlaceSuggestion? center,
  }) async =>
      OfficialChargerSearchResult(
        source: 'BEE',
        sourceUrl: 'https://example.com',
        asOf: DateTime.utc(2026, 8, 1),
        totalStationCount: 0,
        radiusKm: 25,
        matches: const [],
      );
}

void _useViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
