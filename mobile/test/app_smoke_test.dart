import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/app/voltmap_app.dart';
import 'package:voltmap/features/discovery/data/sample_stations.dart';
import 'package:voltmap/features/discovery/data/national_charger_data.dart';
import 'package:voltmap/features/discovery/data/official_charger_search_service.dart';
import 'package:voltmap/features/discovery/data/official_charger_station.dart';
import 'package:voltmap/features/discovery/presentation/add_charger_screen.dart';
import 'package:voltmap/features/discovery/presentation/discovery_screen.dart';
import 'package:voltmap/features/discovery/presentation/station_details_screen.dart';
import 'package:voltmap/features/map/presentation/map_screen.dart';
import 'package:voltmap/features/payments/presentation/charging_checkout_screen.dart';
import 'package:voltmap/features/shell/presentation/app_shell.dart';
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

    await tester.pumpWidget(
      const ProviderScope(
        child: VoltMapApp(
          chargerDataService: _FakeOfficialChargerSearchService(),
        ),
      ),
    );
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

  test('account deletion removes the local profile and personal data',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();
    expect(
      await state.signUp(
        name: 'Delete Me',
        identifier: 'delete@example.com',
        password: 'DeleteMe123!',
      ),
      isNull,
    );
    await state.toggleFavorite('station-1');

    await state.deleteLocalAccountAndData();

    expect(state.hasLocalAccount, isFalse);
    expect(state.isSignedIn, isFalse);
    expect(state.favoriteStationIds, isEmpty);
    expect(state.savedTrips, isEmpty);
    expect(state.chargingReceipts, isEmpty);
    expect(state.chargerSubmissions, isEmpty);
    expect(state.userName, 'VoltMapEV Driver');
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

  testWidgets('guests verify an India phone with OTP before saving a trip', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _useDesktopViewport(tester);

    await tester.pumpWidget(
      const ProviderScope(
        child: VoltMapApp(
          chargerDataService: _FakeOfficialChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('phoneVerificationScreen')), findsNothing);
    expect(find.byKey(const Key('publicTripPlannerNotice')), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Destination'),
      'Bengaluru',
    );
    await tester.ensureVisible(find.text('Plan route'));
    await tester.tap(find.text('Plan route'));
    await _waitForRoutePlan(tester);
    await tester.tap(find.byTooltip('Save trip'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('phoneVerificationScreen')), findsOneWidget);
    expect(find.text('Continue with phone'), findsOneWidget);
    expect(find.textContaining('Saved trips'), findsOneWidget);
    final otpPhoneField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('otpPhoneField')),
        matching: find.byType(TextField),
      ),
    );
    expect(otpPhoneField.decoration?.prefixText, '+91 ');

    await tester.enterText(
        find.byKey(const Key('otpPhoneField')), '9392788714');
    await tester.tap(find.byKey(const Key('sendOtpButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('previewOtpNotice')), findsOneWidget);
    expect(find.textContaining('Preview code: 123456'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('otpCodeField')), '654321');
    await tester.tap(find.byKey(const Key('verifyOtpButton')));
    await tester.pumpAndSettle();
    expect(
      find.text('That OTP is incorrect. Check the code and try again.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('otpCodeField')), '123456');
    await tester.tap(find.byKey(const Key('verifyOtpButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phoneVerificationScreen')), findsNothing);
    expect(find.text('Trip saved on this device.'), findsOneWidget);
  });

  testWidgets('App Review demo can inspect saved features without SMS', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _useDesktopViewport(tester);

    await tester.pumpWidget(
      const ProviderScope(
        child: VoltMapApp(
          chargerDataService: _FakeOfficialChargerSearchService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Destination'),
      'Bengaluru',
    );
    await tester.ensureVisible(find.text('Plan route'));
    await tester.tap(find.text('Plan route'));
    await _waitForRoutePlan(tester);
    await tester.tap(find.byTooltip('Save trip'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('phoneVerificationScreen')), findsOneWidget);
    expect(find.byKey(const Key('appReviewDemoButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('appReviewDemoButton')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('phoneVerificationScreen')), findsNothing);
    expect(find.text('Trip saved on this device.'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO DRIVER PROFILE'), findsOneWidget);
    expect(find.text('demo@voltmapev.com'), findsOneWidget);
  });

  test('India phone normalization is limited to valid mobile numbers', () {
    expect(
      AppState.normalizeIndianMobile('93927 88714'),
      '+919392788714',
    );
    expect(
      AppState.normalizeIndianMobile('+91 93927 88714'),
      '+919392788714',
    );
    expect(AppState.normalizeIndianMobile('1234567890'), isNull);
    expect(AppState.normalizeIndianMobile('93927'), isNull);
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

  testWidgets('navigation tabs load on demand and preserve visited tabs', (
    tester,
  ) async {
    _useDesktopViewport(tester);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AppShell())),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(DiscoveryScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(MapScreen, skipOffstage: false), findsNothing);
    expect(find.byType(TripPlannerScreen, skipOffstage: false), findsNothing);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen, skipOffstage: false), findsOneWidget);

    await tester.tap(find.byKey(const Key('voltmapevHomeLogoButton')));
    await tester.pumpAndSettle();
    expect(find.byType(MapScreen, skipOffstage: false), findsOneWidget);
    expect(
      find.byType(DiscoveryScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byKey(const Key('footerFeedbackButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('footerFeedbackButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privateAppFeedbackDialog')), findsOneWidget);
    expect(find.text('Send private app feedback'), findsOneWidget);
  });

  testWidgets('Trip search suggests India-wide places for partial text', (
    tester,
  ) async {
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: TripPlannerScreen(
            searchService: _FakePlaceSearchService(),
            chargerDataService: _FakeOfficialChargerSearchService(),
          ),
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
    await _waitForRoutePlan(tester);

    expect(
        find.textContaining('Coordinate-based road estimate'), findsOneWidget);
    expect(find.text('Open live directions'), findsOneWidget);
    expect(find.textContaining('Estimated energy:'), findsOneWidget);
    expect(find.textContaining('Chargers along this route ('), findsOneWidget);
    expect(
        find.textContaining('Published BEE/operator chargers'), findsOneWidget);
    expect(find.textContaining('Demo chargers within'), findsNothing);
    expect(find.text('Statiq Connaught Place'), findsNothing);
  });

  testWidgets('search, favorites, navigation, and trip planning work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: VoltMapApp(
          chargerDataService: _FakeOfficialChargerSearchService(),
        ),
      ),
    );
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
    expect(find.text('Find chargers near you'), findsOneWidget);

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Destination'),
      'Vijayawada',
    );
    await tester.ensureVisible(find.text('Plan route'));
    await tester.tap(find.text('Plan route'));
    await _waitForRoutePlan(tester);
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

  testWidgets('station details disclose data limits and support corrections', (
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

    expect(
      find.byKey(const Key('stationDataTransparencyBanner')),
      findsOneWidget,
    );
    expect(find.text('Check live details before travel'), findsOneWidget);
    expect(find.text('Estimated price'), findsOneWidget);
    expect(find.text('Listed ports'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('reportStationCorrectionButton')),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('reportStationCorrectionButton')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('reportStationCorrectionButton')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('privateStationFeedbackDialog')), findsOneWidget);
    expect(find.text('Send private station feedback'), findsOneWidget);
    expect(find.textContaining('never posted to GitHub'), findsOneWidget);
  });

  testWidgets('charger reports remain local with private admin delivery', (
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
      find.byKey(const Key('openPrivateChargerReviewButton')),
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
    expect(find.text('Find chargers near you'), findsOneWidget);
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
    expect(find.byKey(const Key('footerFeedbackButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('footerFeedbackButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('privateAppFeedbackDialog')), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
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
    expect(find.text('Charge & pay'), findsOneWidget);
    expect(find.byKey(const Key('chargePayJourneyHeader')), findsOneWidget);
    await _scrollToPaymentPhone(tester);
    final paymentPhoneField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('paymentPhoneField')),
        matching: find.byType(TextField),
      ),
    );
    expect(paymentPhoneField.decoration?.prefixText, '+91 ');
    final cardOption = find.byKey(const Key('paymentMethod_card'));
    await tester.scrollUntilVisible(
      cardOption,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Credit / debit card'), findsOneWidget);
    expect(find.text('VoltMapEV wallet'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('paymentPhoneField')),
      '9392788714',
    );

    await tester.enterText(find.byKey(const Key('upiIdField')), 'fake@upi');
    await tester.tap(find.byKey(const Key('authorizeButton')));
    await tester.pump();
    expect(
      find.text('UPI ID could not be verified. Use driver@upi'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('upiIdField')), 'driver@upi');
    final emailReceiptOption = find.byKey(
      const Key('receiptDelivery_email'),
    );
    await tester.scrollUntilVisible(
      emailReceiptOption,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(emailReceiptOption);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('receiptEmailField')),
      'driver@example.com',
    );
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
    expect(find.text('Email • d•••@example.com'), findsOneWidget);
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
    expect(
      find.text('Not sent — sandbox contact is not verified'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('chargingDoneButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chargingReceiptScreen')), findsOneWidget);
    expect(find.text('Session completed'), findsOneWidget);
    expect(find.text('₹28.13'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Not sent — sandbox contact is not verified'),
      450,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.text('Not sent — sandbox contact is not verified'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Sandbox receipt — no real payment was collected'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.text('Sandbox receipt — no real payment was collected'),
      findsOneWidget,
    );
  });

  testWidgets('guest users can open payment checkout without signup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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
    expect(find.text('Charge & pay'), findsOneWidget);
    expect(find.byKey(const Key('phoneVerificationScreen')), findsNothing);
    await _scrollToPaymentPhone(tester);
    expect(find.byKey(const Key('paymentPhoneField')), findsOneWidget);
    expect(find.text('Guest checkout — no signup required'), findsOneWidget);
    final paymentPhoneField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('paymentPhoneField')),
        matching: find.byType(TextField),
      ),
    );
    expect(paymentPhoneField.decoration?.prefixText, '+91 ');
  });

  testWidgets('payment phone is required and reused for SMS receipts', (
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

    await _scrollToPaymentPhone(tester);
    final paymentPhoneField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('paymentPhoneField')),
        matching: find.byType(TextField),
      ),
    );
    expect(paymentPhoneField.decoration?.prefixText, '+91 ');
    await tester.enterText(find.byKey(const Key('paymentPhoneField')), '12345');
    await tester.tap(find.byKey(const Key('authorizeButton')));
    await tester.pump();
    expect(
      find.text('Enter a valid 10-digit Indian mobile number'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('paymentPhoneField')),
      '9392788714',
    );

    final emailOption = find.byKey(const Key('receiptDelivery_email'));
    await tester.scrollUntilVisible(
      emailOption,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(emailOption);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('receiptEmailField')),
      'not-an-email',
    );
    await tester.tap(find.byKey(const Key('authorizeButton')));
    await tester.pump();
    expect(find.text('Enter a valid email address'), findsOneWidget);

    final smsOption = find.byKey(const Key('receiptDelivery_sms'));
    await tester.ensureVisible(smsOption);
    await tester.tap(smsOption);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receiptPhoneField')), findsNothing);
    expect(find.byKey(const Key('receiptSmsMessage')), findsOneWidget);
    expect(
      find.textContaining(
        'receipt will use the +91 mobile number entered for this payment',
      ),
      findsOneWidget,
    );
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

    await _scrollToPaymentPhone(tester);
    await tester.enterText(
      find.byKey(const Key('paymentPhoneField')),
      '9392788714',
    );
    final cardOption = find.byKey(const Key('paymentMethod_card'));
    await tester.scrollUntilVisible(
      cardOption,
      300,
      scrollable: find.byType(Scrollable).first,
    );
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

    await _scrollToPaymentPhone(tester);
    await tester.enterText(
      find.byKey(const Key('paymentPhoneField')),
      '9392788714',
    );
    final walletOption = find.byKey(const Key('paymentMethod_wallet'));
    await tester.scrollUntilVisible(
      walletOption,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(walletOption);
    await tester.pumpAndSettle();
    expect(find.textContaining('Sandbox balance is unlimited'), findsOneWidget);
    final smsOption = find.byKey(const Key('receiptDelivery_sms'));
    await tester.scrollUntilVisible(
      smsOption,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(smsOption);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('authorizeButton')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    expect(find.text('Live charging session'), findsOneWidget);
    expect(
      find.text('Payment method verified. ₹0.00 was charged upfront.'),
      findsOneWidget,
    );
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('+91 ••••••8714'), findsWidgets);
    expect(find.text('SMS • +91 ••••••8714'), findsOneWidget);
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
            customerPhone: '9392788714',
            receiptDeliveryMethod: 'In app',
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

Future<void> _scrollToPaymentPhone(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('paymentPhoneField')),
    360,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _waitForRoutePlan(WidgetTester tester) async {
  for (var attempt = 0; attempt < 600; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    if (find.text('Finding route chargers…').evaluate().isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Route planning did not finish within 30 seconds.');
}

class _FakeOfficialChargerSearchService extends OfficialChargerSearchService {
  const _FakeOfficialChargerSearchService();

  @override
  Future<List<OfficialChargerStation>> loadAllStations() async => const [];
}
