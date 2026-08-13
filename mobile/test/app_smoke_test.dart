import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/app/voltmap_app.dart';
import 'package:voltmap/features/discovery/data/sample_stations.dart';
import 'package:voltmap/features/discovery/data/national_charger_data.dart';
import 'package:voltmap/features/discovery/presentation/add_charger_screen.dart';
import 'package:voltmap/features/discovery/presentation/station_details_screen.dart';
import 'package:voltmap/features/payments/presentation/charging_checkout_screen.dart';
import 'package:voltmap/features/trips/presentation/trip_planner_screen.dart';
import 'package:voltmap/shared/models/place_suggestion.dart';
import 'package:voltmap/shared/services/place_search_service.dart';
import 'package:voltmap/shared/state/app_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'voltmap_signed_in': true,
      'voltmap_profile_name': 'Test Driver',
      'voltmap_profile_email': 'driver@voltmap.in',
      'voltmap_account_salt': 'test-salt',
      'voltmap_account_password_hash': 'test-hash',
    });
  });

  testWidgets('local signup, logout, and login persist on this browser', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _useDesktopViewport(tester);

    await tester.pumpWidget(const ProviderScope(child: VoltMapApp()));
    await tester.pumpAndSettle();
    expect(find.text('Find the right charger, faster.'), findsOneWidget);
    expect(find.byKey(const Key('homeInstallAppButton')), findsOneWidget);
    expect(find.textContaining('© 2026 VoltMapEV'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileSignUpButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('authNameField')),
      'Priya Sharma',
    );
    await tester.enterText(
      find.byKey(const Key('authIdentifierField')),
      'priya@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('authPasswordField')),
      'VoltMap123',
    );
    await tester.enterText(
      find.byKey(const Key('authConfirmField')),
      'VoltMap123',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pumpAndSettle();
    expect(find.text('Priya Sharma'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('signOutTile')),
      260,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('signOutTile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmSignOutButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileSignInButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profileSignInButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('authIdentifierField')),
      'priya@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('authPasswordField')),
      'VoltMap123',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pumpAndSettle();
    expect(find.text('Priya Sharma'), findsOneWidget);
  });

  test('account identifiers accept email and Indian phone formats', () {
    expect(
      AppState.normalizeAccountIdentifier('Driver@Example.com'),
      'driver@example.com',
    );
    expect(
      AppState.normalizeAccountIdentifier('93927 88714'),
      '+919392788714',
    );
    expect(
      AppState.normalizeAccountIdentifier('+91-93927-88714'),
      '+919392788714',
    );
    expect(AppState.normalizeAccountIdentifier('12345'), isNull);
  });

  test('only the configured email receives local admin access', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();
    final error = await state.signUp(
      name: 'VoltMapEV Admin',
      identifier: 'skotla100@gmail.com',
      password: 'VoltMapEV123',
    );

    expect(error, isNull);
    expect(state.isAdminAccount, isTrue);
    expect(state.localAccountSummaries, hasLength(1));
    expect(
      state.localAccountSummaries.single.identifier,
      AppState.adminIdentifier,
    );
  });

  test('official state totals add up to the published national count', () {
    final total = stateChargerCoverage.fold<int>(
      0,
      (sum, coverage) => sum + coverage.stationCount,
    );
    expect(total, officialStationTotal);
    expect(stateChargerCoverage, hasLength(36));
  });

  testWidgets('guests can plan trips and are asked to sign up only to save', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _useDesktopViewport(tester);

    await tester.pumpWidget(const ProviderScope(child: VoltMapApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('signupRequiredDialog')), findsNothing);
    expect(find.byKey(const Key('publicTripPlannerNotice')), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Destination'),
      'Bengaluru',
    );
    await tester.ensureVisible(find.text('Plan route'));
    await tester.tap(find.text('Plan route'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save trip'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('signupRequiredDialog')), findsOneWidget);
    expect(find.text('Sign up to use Saved trips'), findsOneWidget);
    await tester.tap(find.byKey(const Key('goToSignupButton')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });

  testWidgets('guests can open Addstation without a signup gate', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _useDesktopViewport(tester);

    await tester.pumpWidget(const ProviderScope(child: VoltMapApp()));
    await tester.pumpAndSettle();
    expect(find.text('Addstation'), findsOneWidget);
    expect(find.byIcon(Icons.add_location_alt_outlined), findsOneWidget);

    await tester.tap(find.text('Addstation'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('signupRequiredDialog')), findsNothing);
    expect(find.text('Add a charging station'), findsOneWidget);
    expect(find.byKey(const Key('publicAddstationNotice')), findsOneWidget);
    expect(find.text('NO SIGNUP REQUIRED'), findsOneWidget);
  });

  testWidgets('Trip search suggests India-wide places for partial text', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: TripPlannerScreen(searchService: _FakePlaceSearchService()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final destination = find.widgetWithText(TextField, 'Destination');
    await tester.enterText(destination, 'ban');
    await tester.pumpAndSettle();
    expect(find.text('Bengaluru'), findsOneWidget);
    expect(find.text('Bandra'), findsOneWidget);

    await tester.tap(find.text('Bengaluru'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Plan route'));
    await tester.tap(find.text('Plan route'));
    await tester.pumpAndSettle();

    expect(find.text('Coordinate-based road estimate'), findsOneWidget);
    expect(find.text('Open live directions'), findsOneWidget);
    expect(find.textContaining('Estimated energy:'), findsOneWidget);
    expect(find.textContaining('Chargers along this route ('), findsOneWidget);
    expect(
      find.byKey(Key('routeCharger_${sampleStations.first.id}')),
      findsOneWidget,
    );
    expect(find.text('Statiq Connaught Place'), findsNothing);
  });

  testWidgets('search, favorites, navigation, and trip planning work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: VoltMapApp()));
    await tester.pumpAndSettle();

    expect(find.text('Find the right charger, faster.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('locationField_Search across India')),
      '500081',
    );
    await tester.pumpAndSettle();
    expect(find.text('ChargeZone Hitech City'), findsOneWidget);
    expect(find.text('Tata Power Madhapur'), findsOneWidget);
    expect(find.text('2 demos'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('locationField_Search across India')),
      'Zeon',
    );
    await tester.pumpAndSettle();
    expect(find.text('Zeon Charging Hub'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Add to favorites').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add to favorites').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('Zeon Charging Hub'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.text('India Charger Map'), findsOneWidget);

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Destination'),
      'Vijayawada',
    );
    await tester.ensureVisible(find.text('Plan route'));
    await tester.tap(find.text('Plan route'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Estimated energy:'), findsOneWidget);
    expect(find.text('Save this trip'), findsOneWidget);
  });

  testWidgets('India-wide discovery searches PIN, area, city, and state', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: VoltMapApp()));
    await tester.pumpAndSettle();

    final discoverySearch =
        find.byKey(const Key('locationField_Search across India'));
    await tester.enterText(discoverySearch, '110001');
    await tester.pumpAndSettle();
    expect(find.text('Statiq Connaught Place'), findsOneWidget);
    expect(find.text('1 demo'), findsOneWidget);

    await tester.enterText(discoverySearch, '400-051');
    await tester.pumpAndSettle();
    expect(find.text('Tata Power BKC'), findsOneWidget);
    expect(find.text('1 demo'), findsOneWidget);

    await tester.enterText(discoverySearch, 'Whitefield');
    await tester.pumpAndSettle();
    expect(find.text('Ather Grid Whitefield'), findsOneWidget);

    await tester.enterText(discoverySearch, 'Bangalore');
    await tester.pumpAndSettle();
    expect(find.text('Ather Grid Whitefield'), findsOneWidget);
    expect(find.text('3 demos'), findsOneWidget);

    await tester.enterText(discoverySearch, 'Tamil Nadu');
    await tester.pumpAndSettle();
    expect(find.text('Zeon Peelamedu'), findsOneWidget);
    expect(find.text('3 demos'), findsOneWidget);
  });

  test('local India suggestions resolve 500079 and partial ben searches', () {
    const service = PlaceSearchService();
    final pinResults = service.localSuggestions('500079');
    expect(pinResults, isNotEmpty);
    expect(pinResults.first.primaryText, contains('Karmanghat'));
    expect(pinResults.first.secondaryText, contains('Hyderabad'));

    final benResults = service.localSuggestions('ben');
    expect(benResults.map((place) => place.primaryText), contains('Bengaluru'));
    expect(
        benResults.map((place) => place.primaryText), contains('Benson Town'));
    expect(
      benResults.map((place) => place.primaryText),
      contains('Benniganahalli'),
    );
  });

  testWidgets('unavailable chargers are clearly marked and cannot charge', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    final unavailable = sampleStations.firstWhere(
      (station) => !station.available,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StationDetailsScreen(station: unavailable),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unavailableStationBanner')), findsOneWidget);
    expect(find.textContaining('NOT WORKING / UNAVAILABLE'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Unavailable'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('public charger reports validate and remain saved for review', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AddChargerScreen())),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Station name'),
      'Community EV Hub',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Operator or network'),
      'Community Charge',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Street address / landmark'),
      'LB Nagar Metro',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'City / area'),
      'Karmanghat',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'State / UT'),
      'Telangana',
    );
    await tester.enterText(
      find.byKey(const Key('chargerPinField')),
      '500079',
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submitChargerReportButton')));
    await tester.pumpAndSettle();

    expect(find.text('Report saved'), findsOneWidget);
    expect(find.byKey(const Key('finishChargerReportButton')), findsOneWidget);
    expect(
      find.byKey(const Key('openPublicChargerReviewButton')),
      findsOneWidget,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('voltmap_charger_submissions'), isNotNull);
    await tester.tap(find.byKey(const Key('finishChargerReportButton')));
    await tester.pumpAndSettle();
    final stationField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Station name'),
    );
    expect(stationField.controller?.text, isEmpty);
  });

  testWidgets('compact phone navigation reaches every responsive app section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: VoltMapApp()));
    await tester.pumpAndSettle();

    final navigation = find.byType(NavigationBar);
    expect(navigation, findsOneWidget);
    await tester.tap(
      find.descendant(
          of: navigation, matching: find.byIcon(Icons.map_outlined)),
    );
    await tester.pumpAndSettle();
    expect(find.text('India Charger Map'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: navigation,
        matching: find.byIcon(Icons.route_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Trip Planner'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: navigation,
        matching: find.byIcon(Icons.favorite_border),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Favorites'), findsWidgets);
    await tester.tap(
      find.descendant(
        of: navigation,
        matching: find.byIcon(Icons.add_location_alt_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add a charging station'), findsOneWidget);
    expect(find.text('Addstation'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: navigation,
        matching: find.byIcon(Icons.person_outline),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Profile & settings'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('installVoltMapEVTile')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UPI is verified before metered charging and charged afterward', (
    tester,
  ) async {
    _useDesktopViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StationDetailsScreen(station: sampleStations.first),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('openCheckoutButton')));
    await tester.pumpAndSettle();
    expect(find.text('Set up charging'), findsOneWidget);
    expect(find.text('Credit / debit card'), findsOneWidget);
    expect(find.text('VoltMapEV wallet'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('upiIdField')), 'fake@upi');
    await tester.tap(find.byKey(const Key('authorizeButton')));
    await tester.pump();
    expect(
      find.text('UPI ID could not be verified. Use driver@upi'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('upiIdField')), 'driver@upi');
    await tester.tap(find.byKey(const Key('authorizeButton')));
    await tester.pump();
    expect(find.text('Validating securely…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    expect(find.text('Live charging session'), findsOneWidget);
    expect(
      find.text('Payment method verified. ₹0.00 was charged upfront.'),
      findsOneWidget,
    );
    expect(find.textContaining('UPI dr••@upi'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const Key('stopChargingButton')));
    await tester.pump();
    expect(find.text('Finalizing payment…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Charging complete'), findsOneWidget);
    expect(
      find.text('Final payment captured after charging finished.'),
      findsOneWidget,
    );
    expect(find.text('₹28.13'), findsWidgets);
    expect(find.textContaining('VM-'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chargingDoneButton')));
    await tester.pumpAndSettle();
    expect(find.text('Charging session complete'), findsOneWidget);
    expect(find.textContaining('Final payment: ₹28.13'), findsOneWidget);
  });

  testWidgets('card authorization rejects declined cards before charging', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ChargingCheckoutScreen(station: sampleStations.first),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardOption = find.byKey(const Key('paymentMethod_card'));
    await tester.ensureVisible(cardOption);
    await tester.pumpAndSettle();
    await tester.tap(cardOption);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('authorizeButton')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('cardholderField')));
    await tester.pumpAndSettle();
    expect(find.text('Enter the cardholder name'), findsOneWidget);
    expect(find.text('Enter a valid 16-digit sandbox card'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('cardholderField')));
    await tester.enterText(
      find.byKey(const Key('cardholderField')),
      'Test Driver',
    );
    await tester.ensureVisible(find.byKey(const Key('cardNumberField')));
    await tester.enterText(
      find.byKey(const Key('cardNumberField')),
      '4000000000000002',
    );
    await tester.ensureVisible(find.byKey(const Key('expiryField')));
    await tester.enterText(find.byKey(const Key('expiryField')), '1230');
    await tester.enterText(find.byKey(const Key('cvvField')), '123');
    await tester.tap(find.byKey(const Key('authorizeButton')));
    await tester.pump();
    expect(
      find.text(
        'Card was declined. Use sandbox card 4242 4242 4242 4242',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('cardNumberField')),
      '4242424242424242',
    );
    await tester.tap(find.byKey(const Key('authorizeButton')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    expect(find.text('Live charging session'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const Key('stopChargingButton')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Charging complete'), findsOneWidget);
    expect(find.text('Card ending 4242'), findsOneWidget);
  });

  testWidgets('wallet authorizes first and captures after charging', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ChargingCheckoutScreen(station: sampleStations.first),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final walletOption = find.byKey(const Key('paymentMethod_wallet'));
    await tester.ensureVisible(walletOption);
    await tester.pumpAndSettle();
    await tester.tap(walletOption);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sandbox balance is unlimited'), findsOneWidget);
    await tester.tap(find.byKey(const Key('authorizeButton')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    expect(find.text('Live charging session'), findsOneWidget);
    expect(
      find.text('Payment method verified. ₹0.00 was charged upfront.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const Key('stopChargingButton')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Charging complete'), findsOneWidget);
    expect(find.text('VoltMapEV demo wallet'), findsOneWidget);
  });

  testWidgets('charging stops and captures automatically at the energy limit', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ChargingSessionScreen(
            station: sampleStations.first,
            connectorType: 'CCS2',
            energyLimitKwh: 1.25,
            paymentMethod: 'VoltMapEV demo wallet',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Payment method verified. ₹0.00 was charged upfront.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.text('Finalizing payment…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Charging complete'), findsOneWidget);
    expect(find.text('Paid • Automatic stop'), findsOneWidget);
    expect(find.text('₹28.13'), findsWidgets);
  });
}

class _FakePlaceSearchService extends PlaceSearchService {
  const _FakePlaceSearchService();

  @override
  Future<List<PlaceSuggestion>> searchIndia(String rawQuery) async {
    return localSuggestions(rawQuery);
  }
}

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
