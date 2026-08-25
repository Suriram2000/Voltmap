import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltmap/core/config/app_environment.dart';
import 'package:voltmap/features/discovery/data/official_charger_search_service.dart';
import 'package:voltmap/features/discovery/data/official_charger_station.dart';
import 'package:voltmap/features/map/presentation/map_screen.dart';
import 'package:voltmap/shared/models/place_suggestion.dart';
import 'package:voltmap/shared/services/place_search_service.dart';

void main() {
  test('Map app-settings action is disabled on web', () {
    expect(
      canOpenMapAppSettings(
        isWeb: true,
        permissionFailure: true,
        blocked: true,
      ),
      isFalse,
    );
    expect(
      canOpenMapAppSettings(
        isWeb: false,
        permissionFailure: true,
        blocked: true,
      ),
      isTrue,
    );
  });

  testWidgets('Map locates on open and immediately shows every nearby charger',
      (
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

    final locationToggle = find.byKey(const Key('mapLocationToggle'));
    expect(locationRequests, 1);
    expect(tester.widget<SwitchListTile>(locationToggle).value, isTrue);
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

    await tester.tap(find.text('Alpha Charge - Hyderabad'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('officialChargerDetailsScreen')),
      findsOneWidget,
    );
    expect(
      find.text('Charge & pay'),
      AppRuntimeConfig.canOfferChargingPayment ? findsOneWidget : findsNothing,
    );
  });

  testWidgets('Map location can be disabled and re-enabled in place', (
    tester,
  ) async {
    var locationRequests = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          autoLocateOnOpen: false,
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
    expect(locationRequests, 0);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(locationRequests, 1);
    expect(find.byKey(const Key('nearbyChargerMap')), findsOneWidget);

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

  for (final size in const [
    Size(320, 568),
    Size(375, 667),
    Size(393, 852),
    Size(430, 932),
    Size(440, 956),
    Size(568, 320),
    Size(852, 393),
  ]) {
    testWidgets(
        'iPhone Map uses a synchronized charger sheet at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      _useViewport(tester, size);

      await tester.pumpWidget(
        const MaterialApp(
          home: MapScreen(
            autoLocateOnOpen: false,
            locationLoader: _fakeLocation,
            placeSearchService: _FakePlaceSearchService(),
            chargerSearchService: _FakeChargerSearchService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mapLocationToggle')));
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
  }

  testWidgets('Map filters markers and nearby list together', (tester) async {
    _useViewport(tester, const Size(1200, 900));

    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(
          autoLocateOnOpen: false,
          locationLoader: _fakeLocation,
          placeSearchService: _FakePlaceSearchService(),
          chargerSearchService: _FakeChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mapLocationToggle')));
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
          autoLocateOnOpen: false,
          locationLoader: () async => throw Exception('location unavailable'),
          placeSearchService: const _FakePlaceSearchService(),
          chargerSearchService: const _FakeChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mapLocationToggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nearbyChargerError')), findsOneWidget);
    expect(find.text('Charger service is unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const Key('mapLocationSearch')), findsOneWidget);
  });

  testWidgets('Denied location resets the switch and explains permission', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          autoLocateOnOpen: false,
          locationLoader: () async =>
              throw const MapLocationPermissionException(
            'Location is blocked for this test.',
            blocked: true,
          ),
          placeSearchService: const _ManualPlaceSearchService(),
          chargerSearchService: const _FakeChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('mapLocationToggle'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(find.text('Location permission required'), findsWidgets);
    expect(find.byKey(const Key('nearbyChargerError')), findsOneWidget);
    expect(find.text('Try location again'), findsOneWidget);

    final searchField = find.byKey(
      const ValueKey('locationField_Search chargers by area or PIN'),
    );
    await tester.enterText(searchField, '500079');
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('locationSuggestions')), findsNothing);
    expect(find.byKey(const Key('nearbyChargerMap')), findsOneWidget);
    expect(find.byKey(const Key('nearbyChargerPanel')), findsOneWidget);
    expect(find.text('Alpha Charge - Hyderabad'), findsOneWidget);
  });

  testWidgets('Mobile location-permission UI stays compact and actionable', (
    tester,
  ) async {
    _useViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          autoLocateOnOpen: false,
          locationLoader: () async =>
              throw const MapLocationPermissionException(
            'Location is blocked for this test.',
            blocked: true,
          ),
          placeSearchService: const _FakePlaceSearchService(),
          chargerSearchService: const _FakeChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mapLocationToggle')));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('mapLocationControlSurface'))).height,
      lessThanOrEqualTo(58),
    );
    expect(find.byKey(const Key('compactMapStatusContent')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('mapStatusCardSurface'))).width,
      greaterThanOrEqualTo(300),
    );
    expect(
      tester.getSize(find.byKey(const Key('compactMapStatusTitle'))).height,
      lessThanOrEqualTo(35),
    );
    expect(
      tester.getSize(find.byKey(const Key('compactMapStatusMessage'))).height,
      lessThanOrEqualTo(50),
    );
    expect(
      tester.getSize(find.byKey(const Key('compactMapStatusSummary'))).height,
      lessThanOrEqualTo(80),
    );
    expect(
      tester.getSize(find.byKey(const Key('compactMapStatusActions'))).height,
      lessThanOrEqualTo(60),
    );
    expect(
      tester.getSize(find.byKey(const Key('mapStatusCardSurface'))).height,
      lessThanOrEqualTo(170),
    );
    expect(find.text('Try location again'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Map PIN search auto-loads when device location is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          autoLocateOnOpen: false,
          locationLoader: () async => throw Exception('must not be requested'),
          placeSearchService: const _ManualPlaceSearchService(),
          chargerSearchService: const _FakeChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nearbyChargerLocationOff')), findsOneWidget);
    final searchField = find.byKey(
      const ValueKey('locationField_Search chargers by area or PIN'),
    );
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, '500079');
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nearbyChargerMap')), findsOneWidget);
    expect(find.byKey(const Key('nearbyChargerPanel')), findsOneWidget);
    expect(find.text('Alpha Charge - Hyderabad'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('mapLocationToggle')),
          )
          .value,
      isFalse,
    );
    expect(
        find.textContaining('without using device location'), findsOneWidget);
  });

  testWidgets('Map search keeps keyboard focus as the mobile viewport shrinks',
      (
    tester,
  ) async {
    _useViewport(tester, const Size(390, 650));
    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(
          autoLocateOnOpen: false,
          locationLoader: _fakeLocation,
          placeSearchService: _ManualPlaceSearchService(),
          chargerSearchService: _FakeChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchField = find.byKey(
      const ValueKey('locationField_Search chargers by area or PIN'),
    );
    await tester.tap(searchField);
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.widget<TextField>(searchField).focusNode?.hasFocus, isTrue);

    // Mobile browsers reduce the app viewport when the software keyboard
    // appears. The focused field must not be replaced by a different layout.
    tester.view.physicalSize = const Size(390, 260);
    await tester.pump();

    expect(find.byKey(const Key('mapSearchableStatus')), findsOneWidget);
    expect(searchField, findsOneWidget);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.widget<TextField>(searchField).focusNode?.hasFocus, isTrue);

    await tester.enterText(searchField, '500079');
    await tester.pump(const Duration(milliseconds: 240));
    tester.view.physicalSize = const Size(390, 650);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nearbyChargerMap')), findsOneWidget);
    expect(find.text('Alpha Charge - Hyderabad'), findsOneWidget);
  });

  testWidgets('Map keeps location enabled while searching another PIN in place',
      (
    tester,
  ) async {
    _useViewport(tester, const Size(1200, 900));
    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(
          autoLocateOnOpen: false,
          locationLoader: _fakeLocation,
          placeSearchService: _ManualPlaceSearchService(),
          chargerSearchService: _FakeChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('mapLocationToggle'));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    final searchField = find.byKey(
      const ValueKey('locationField_Search map'),
    );
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, '500079');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(find.byKey(const Key('mapLocationSearch')), findsOneWidget);
    expect(find.byKey(const Key('nearbyChargerMap')), findsOneWidget);
    expect(find.byKey(const Key('nearbyChargerPanel')), findsOneWidget);
    expect(find.textContaining('showing chargers near'), findsOneWidget);
    expect(find.text('Alpha Charge - Hyderabad'), findsOneWidget);
  });

  testWidgets('Map explains a valid empty nearby result', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MapScreen(
          autoLocateOnOpen: false,
          locationLoader: _fakeLocation,
          placeSearchService: _FakePlaceSearchService(),
          chargerSearchService: _EmptyChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mapLocationToggle')));
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

class _ManualPlaceSearchService extends _FakePlaceSearchService {
  const _ManualPlaceSearchService();

  @override
  Future<List<PlaceSuggestion>> searchIndia(String rawQuery) async => const [
        PlaceSuggestion(
          primaryText: 'Karmanghat / Vaishalinagar - 500079',
          secondaryText: 'Saroornagar, Hyderabad, Telangana, India',
          latitude: 17.3366,
          longitude: 78.5349,
          type: 'postcode',
        ),
      ];
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
