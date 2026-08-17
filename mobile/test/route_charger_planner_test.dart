import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltmap/features/discovery/data/official_charger_search_service.dart';
import 'package:voltmap/features/discovery/data/official_charger_station.dart';
import 'package:voltmap/features/trips/data/route_charger_planner.dart';
import 'package:voltmap/features/trips/presentation/trip_planner_screen.dart';
import 'package:voltmap/shared/models/place_suggestion.dart';
import 'package:voltmap/shared/services/place_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('500081 and 500079 resolve to distinct Hyderabad PIN areas', () {
    const service = PlaceSearchService();
    final origin = service.localSuggestions('500081').first;
    final destination = service.localSuggestions('500079').first;

    expect(origin.primaryText, contains('500081'));
    expect(destination.primaryText, contains('500079'));
    expect(origin.latitude, isNot(destination.latitude));
    expect(
        estimatedRoadDistanceKm(origin, destination), inInclusiveRange(10, 30));
  });

  testWidgets(
      '500081 to 500079 uses national chargers inside the route corridor',
      (tester) async {
    const places = PlaceSearchService();
    final origin = places.localSuggestions('500081').first;
    final destination = places.localSuggestions('500079').first;
    final stations = (await tester.runAsync(
      () => const OfficialChargerSearchService().loadAllStations(),
    ))!;
    final distance = estimatedRoadDistanceKm(origin, destination);
    final corridor = routeCorridorKm(distance);
    final chargers = chargersAlongRoute(
      stations: stations,
      origin: origin,
      destination: destination,
      corridorKm: corridor,
    );

    expect(stations, hasLength(29251));
    expect(corridor, 4);
    expect(chargers, hasLength(142));
    expect(
      chargers.every((charger) => charger.distanceFromRouteKm <= corridor),
      isTrue,
    );
    expect(
      chargers.every((charger) => charger.station.sourceLabel.contains('BEE')),
      isTrue,
    );
    for (var index = 1; index < chargers.length; index++) {
      expect(
        chargers[index].routeProgress,
        greaterThanOrEqualTo(chargers[index - 1].routeProgress),
      );
    }
  });

  test('urban routes use a focused corridor instead of a 25 km radius', () {
    expect(routeCorridorKm(18), 4);
    expect(routeCorridorKm(120), 6);
    expect(routeCorridorKm(400), 10);
    expect(routeCorridorKm(900), 15);
  });

  test('user-selected route chargers are preferred for required stops', () {
    final selected = selectChargingStops(
      stopCount: 1,
      routeChargers: const [
        RouteChargerCandidate(
          station: _nearerStation,
          distanceFromRouteKm: 0.2,
          routeProgress: 0.5,
        ),
        RouteChargerCandidate(
          station: _previewStation,
          distanceFromRouteKm: 1.2,
          routeProgress: 0.6,
        ),
      ],
      preferredStationIds: const [_previewStationId],
    );

    expect(selected, const [_previewStationId]);
  });

  testWidgets('typing 50079 automatically shows route data without checkboxes',
      (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: TripPlannerScreen(
            searchService: _LocalPlaceSearchService(),
            chargerDataService: _PreviewChargerSearchService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Destination'),
      '50079',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await _waitForRoutePlan(tester);

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byKey(const Key('routeStationPreview')), findsNothing);
    expect(find.byKey(const Key('locationSuggestions')), findsNothing);
    expect(find.byKey(const Key('routeChargersHeading')), findsOneWidget);
    expect(
      find.textContaining('Karmanghat / Vaishalinagar - 500079'),
      findsOneWidget,
    );
    expect(find.text('Plan route'), findsOneWidget);
  });

  testWidgets('typed PINs plan in-page without selecting a suggestion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: TripPlannerScreen(
            searchService: _LocalPlaceSearchService(),
            chargerDataService: _FastPreviewChargerSearchService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Starting point'),
      '500081',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Destination'),
      '500079',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await _waitForRoutePlan(tester);

    expect(find.text('Chargers along this route (142)'), findsOneWidget);
    expect(find.text('Show all 142 route chargers'), findsOneWidget);
    expect(find.textContaining('within 4 km of the route'), findsOneWidget);
    expect(find.text('Open live directions'), findsOneWidget);

    await Scrollable.ensureVisible(
      tester.element(find.text('Lioncharge - Hyderabad')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lioncharge - Hyderabad'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('officialChargerDetailsScreen')), findsOneWidget);
    expect(find.text('Charger details'), findsOneWidget);
    expect(find.text('Published station · verify status'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Charge & pay'), findsOneWidget);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Verify on Google Maps'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Charge & pay'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chargeOfficialStationButton')));
    await tester.pumpAndSettle();
    expect(
      find.text('Secure charging services are not connected'),
      findsOneWidget,
    );
    expect(
      find.textContaining('No OTP, payment, or receipt delivery was attempted'),
      findsOneWidget,
    );
  });
}

class _LocalPlaceSearchService extends PlaceSearchService {
  const _LocalPlaceSearchService();

  @override
  Future<List<PlaceSuggestion>> searchIndia(String rawQuery) async {
    return localSuggestions(rawQuery);
  }
}

class _PreviewChargerSearchService extends OfficialChargerSearchService {
  const _PreviewChargerSearchService();

  @override
  Future<OfficialChargerSearchResult> search({
    required String query,
    PlaceSuggestion? center,
  }) async =>
      OfficialChargerSearchResult(
        source: 'BEE test inventory',
        sourceUrl: 'https://example.test/chargers',
        asOf: DateTime.utc(2026, 8, 16),
        totalStationCount: 2,
        radiusKm: 15,
        matches: const [
          OfficialChargerMatch(
            station: _previewStation,
            distanceKm: 1.2,
            exactPostcode: true,
          ),
          OfficialChargerMatch(
            station: _nearerStation,
            distanceKm: 2.1,
            exactPostcode: false,
          ),
        ],
      );

  @override
  Future<List<OfficialChargerStation>> loadAllStations() async => const [
        _previewStation,
        _nearerStation,
      ];
}

class _FastPreviewChargerSearchService extends OfficialChargerSearchService {
  const _FastPreviewChargerSearchService();

  @override
  Future<OfficialChargerSearchResult> search({
    required String query,
    PlaceSuggestion? center,
  }) async =>
      OfficialChargerSearchResult(
        source: 'BEE test inventory',
        sourceUrl: 'https://example.test/chargers',
        asOf: DateTime.utc(2026, 8, 16),
        totalStationCount: 29251,
        radiusKm: 15,
        matches: const [],
      );
}

const _previewStationId = 'preview-500079';
const _previewStation = OfficialChargerStation(
  operatorName: 'PIN Charge',
  ownership: 'Private',
  state: 'Telangana',
  district: 'Hyderabad',
  city: 'Hyderabad',
  address: 'Karmanghat, Hyderabad 500079',
  latitude: 17.3366,
  longitude: 78.5349,
  postcodes: ['500079'],
  connectors: [
    OfficialChargerConnector(type: 'CCS-II', ratingKw: 60, count: 2),
  ],
  providerStationId: _previewStationId,
  sourceNames: ['BEE test inventory'],
);

const _nearerStation = OfficialChargerStation(
  operatorName: 'Nearby Charge',
  ownership: 'Private',
  state: 'Telangana',
  district: 'Hyderabad',
  city: 'Hyderabad',
  address: 'Hyderabad 500035',
  latitude: 17.35,
  longitude: 78.52,
  postcodes: ['500035'],
  connectors: [
    OfficialChargerConnector(type: 'Type-II AC', ratingKw: 22, count: 1),
  ],
  providerStationId: 'nearer-500035',
  sourceNames: ['BEE test inventory'],
);

Future<void> _waitForRoutePlan(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (find.text('Finding route chargers…').evaluate().isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Route planning did not finish within 2.5 seconds.');
}
