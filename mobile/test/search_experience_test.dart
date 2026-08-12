import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/app/voltmap_app.dart';
import 'package:voltmap/features/discovery/data/official_charger_search_service.dart';
import 'package:voltmap/features/discovery/data/official_charger_station.dart';
import 'package:voltmap/features/discovery/data/sample_stations.dart';
import 'package:voltmap/features/discovery/presentation/discovery_screen.dart';
import 'package:voltmap/features/discovery/presentation/live_charger_map_screen.dart';
import 'package:voltmap/features/discovery/presentation/station_card.dart';
import 'package:voltmap/shared/models/place_suggestion.dart';
import 'package:voltmap/shared/services/place_search_service.dart';
import 'package:voltmap/shared/widgets/location_autocomplete_field.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('live charger map centers the 500079 PIN accurately', () {
    final place = const PlaceSearchService().localSuggestions('500079').first;
    final uri = buildLiveChargerMapUri(center: place);

    expect(uri.host, 'map.openchargemap.io');
    expect(uri.queryParameters['mode'], 'embedded');
    expect(uri.queryParameters['latitude'], '17.336600');
    expect(uri.queryParameters['longitude'], '78.534900');
    expect(uri.queryParameters['zoom'], '13');
  });

  test('official charger search keeps exact PIN matches first', () {
    final center = const PlaceSearchService().localSuggestions('500079').first;
    final exact = _officialStation(
      operatorName: 'Exact Energy',
      latitude: 17.348941,
      longitude: 78.513976,
      postcode: '500079',
    );
    final nearby = _officialStation(
      operatorName: 'Nearby Energy',
      latitude: 17.34,
      longitude: 78.55,
      postcode: '500035',
    );
    final farAway = _officialStation(
      operatorName: 'Far Energy',
      latitude: 18.5,
      longitude: 79.5,
      postcode: '500001',
    );

    final result = searchOfficialChargers(
      index: OfficialChargerIndex(
        source: 'BEE',
        sourceUrl: 'https://example.com',
        asOf: DateTime(2025, 10, 26),
        totalStationCount: 3,
        stations: [nearby, farAway, exact],
      ),
      query: '500079',
      center: center,
    );

    expect(result.matches.map((match) => match.station.operatorName), [
      'Exact Energy',
      'Nearby Energy',
    ]);
    expect(result.exactPostcodeCount, 1);
  });

  testWidgets('bundled BEE data returns in-app 500079 results', (tester) async {
    final center = const PlaceSearchService().localSuggestions('500079').first;
    final result = (await tester.runAsync(
      () => const OfficialChargerSearchService().search(
        query: '500079',
        center: center,
      ),
    ))!;

    expect(result.exactPostcodeCount, 2);
    expect(result.matches, hasLength(235));
    expect(result.matches.first.exactPostcode, isTrue);
    expect(result.totalStationCount, 29251);
  });

  testWidgets('selecting a PIN opens live charger results immediately', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DiscoveryScreen())),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('locationField_Search across India')),
      '500079',
    );
    await tester.pump();
    await tester.tap(find.text('Karmanghat / Vaishalinagar - 500079'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Chargers near Karmanghat / Vaishalinagar - 500079'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('officialChargerListTab')), findsOneWidget);
    expect(find.byKey(const Key('communityChargerMapTab')), findsOneWidget);
    expect(
        find.byKey(const Key('verifyLiveResultsOnGoogleButton')), findsNothing);

    await tester.tap(find.byKey(const Key('communityChargerMapTab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LIVE COMMUNITY MAP'), findsOneWidget);
    expect(find.byKey(const Key('liveChargerPlatformView')), findsOneWidget);
  });

  testWidgets('the visible Search action opens live PIN charger results', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DiscoveryScreen())),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('locationField_Search across India')),
      '500079',
    );
    await tester.pump();
    expect(
      find.byKey(const Key('submitLiveChargerSearchButton')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('submitLiveChargerSearchButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Chargers near Karmanghat / Vaishalinagar - 500079'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('officialChargerListTab')), findsOneWidget);
  });

  testWidgets('discovery lazily builds cards and dismisses input on drag', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DiscoveryScreen())),
    );
    await tester.pump();

    final scrollView = tester.widget<CustomScrollView>(
      find.byKey(const PageStorageKey('discoveryScrollView')),
    );
    expect(
      scrollView.keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
    await tester.drag(
      find.byKey(const PageStorageKey('discoveryScrollView')),
      const Offset(0, -1050),
    );
    await tester.pump();
    final builtCards = find.byType(StationCard).evaluate().length;
    expect(builtCards, greaterThan(0));
    expect(builtCards, lessThan(sampleStations.length));
  });

  testWidgets('long location options scroll smoothly and remain selectable', (
    tester,
  ) async {
    PlaceSuggestion? selected;
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationAutocompleteField(
            controller: controller,
            label: 'Area',
            hint: 'Search',
            prefixIcon: Icons.search,
            searchService: const _ManyPlacesService(),
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'aa');
    await tester.pump();
    final listFinder = find.byKey(const Key('locationSuggestionsList'));
    expect(listFinder, findsOneWidget);
    expect(
      tester.widget<ListView>(listFinder).keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );

    await tester.drag(listFinder, const Offset(0, -300));
    await tester.pump();
    await tester.tap(find.text('Area 6'));
    await tester.pump();
    expect(selected?.primaryText, 'Area 6');
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS uses native-feeling bounce scroll physics', (tester) async {
    ScrollPhysics? physics;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        scrollBehavior: const VoltMapScrollBehavior(),
        home: Builder(
          builder: (context) {
            physics = const VoltMapScrollBehavior().getScrollPhysics(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(physics, isA<BouncingScrollPhysics>());
    expect(
      const VoltMapScrollBehavior().dragDevices,
      containsAll(<PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
      }),
    );
  });
}

OfficialChargerStation _officialStation({
  required String operatorName,
  required double latitude,
  required double longitude,
  required String postcode,
}) {
  return OfficialChargerStation(
    operatorName: operatorName,
    ownership: 'Private',
    state: 'Telangana',
    district: 'Hyderabad',
    city: 'Hyderabad',
    address: 'Station address $postcode',
    latitude: latitude,
    longitude: longitude,
    postcodes: [postcode],
    connectors: const [
      OfficialChargerConnector(type: 'CCS-II', ratingKw: 50, count: 1),
    ],
  );
}

class _ManyPlacesService extends PlaceSearchService {
  const _ManyPlacesService();

  @override
  List<PlaceSuggestion> localSuggestions(String rawQuery) {
    return List.generate(
      20,
      (index) => PlaceSuggestion(
        primaryText: 'Area $index',
        secondaryText: 'Hyderabad, Telangana, India',
        latitude: 17.3 + index / 1000,
        longitude: 78.5 + index / 1000,
        type: 'locality',
      ),
    );
  }
}

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
