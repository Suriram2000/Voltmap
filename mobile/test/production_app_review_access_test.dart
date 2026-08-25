import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/core/config/app_environment.dart';
import 'package:voltmap/features/auth/presentation/auth_screen.dart';
import 'package:voltmap/features/auth/presentation/phone_verification_screen.dart';
import 'package:voltmap/features/discovery/presentation/station_details_screen.dart';
import 'package:voltmap/features/profile/presentation/profile_screen.dart';
import 'package:voltmap/shared/models/charging_station.dart';
import 'package:voltmap/shared/state/app_state.dart';

void main() {
  if (AppRuntimeConfig.isSandbox || !AppRuntimeConfig.isAppleAppStoreBuild) {
    test('App Review access test requires App Store production defines', () {
      expect(
        AppRuntimeConfig.isSandbox || !AppRuntimeConfig.isAppleAppStoreBuild,
        isTrue,
      );
    });
    return;
  }

  testWidgets(
    'production App Store build provides local reviewer access and deletion',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final appState = AppState();
      await appState.load();
      bool? accessGranted;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appStateProvider.overrideWith((ref) => appState)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const Key('openReviewAccess'),
                    onPressed: () async {
                      accessGranted = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) => const PhoneVerificationScreen(
                            feature: 'Saved trips and favorites',
                          ),
                        ),
                      );
                    },
                    child: const Text('Open review access'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('openReviewAccess')));
      await tester.pumpAndSettle();

      expect(AppRuntimeConfig.isSandbox, isFalse);
      expect(AppRuntimeConfig.isAppleAppStoreBuild, isTrue);
      expect(find.byKey(const Key('appReviewDemoButton')), findsOneWidget);
      expect(find.text('Continue on this device'), findsOneWidget);
      expect(find.textContaining('No phone number'), findsOneWidget);
      expect(find.textContaining('WhatsApp'), findsNothing);

      await tester.tap(find.byKey(const Key('appReviewDemoButton')));
      await tester.pumpAndSettle();

      expect(accessGranted, isTrue);
      expect(appState.isSignedIn, isTrue);
      expect(appState.userIdentifier, 'demo@voltmapev.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appStateProvider.overrideWith((ref) => appState)],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LOCAL DRIVER PROFILE'), findsOneWidget);
      expect(find.textContaining('Android'), findsNothing);
      expect(find.byKey(const Key('paymentHistoryTile')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('deleteAccountTile')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('deleteAccountTile')), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appStateProvider.overrideWith((ref) => appState)],
          child: const MaterialApp(
            home: StationDetailsScreen(
              station: ChargingStation(
                id: 'review-station',
                name: 'Review Station',
                network: 'Reference operator',
                address: 'Hyderabad',
                city: 'Hyderabad',
                state: 'Telangana',
                postalCode: '500079',
                distanceKm: 1.2,
                latitude: 17.33,
                longitude: 78.55,
                connectorTypes: ['CCS2'],
                powerKw: 60,
                totalConnectors: 2,
                availableConnectors: 1,
                pricePerKwh: 18,
                rating: 4.5,
                amenities: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Navigate'), findsOneWidget);
      expect(find.text('Charge & pay'), findsNothing);
      expect(find.byKey(const Key('openCheckoutButton')), findsNothing);
    },
  );

  testWidgets(
    'App Store Profile provides one-tap local access without credentials',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      _setReviewViewport(tester, const Size(820, 1180));
      final appState = AppState();
      await appState.load();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appStateProvider.overrideWith((ref) => appState)],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('profileAppReviewContinueButton')),
        findsOneWidget,
      );
      expect(find.text('Continue on this device'), findsOneWidget);
      expect(find.byKey(const Key('profileSignUpButton')), findsNothing);
      expect(find.byKey(const Key('profileSignInButton')), findsNothing);
      expect(find.text('Password'), findsNothing);

      await tester.tap(find.byKey(const Key('profileAppReviewContinueButton')));
      await tester.pumpAndSettle();

      expect(appState.isDemoAccount, isTrue);
      expect(find.text('LOCAL DRIVER PROFILE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in const [Size(390, 844), Size(820, 1180)]) {
    testWidgets(
      'App Store access hides credential fields at ${viewport.width.toInt()}px',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        _setReviewViewport(tester, viewport);
        final appState = AppState();
        await appState.load();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [appStateProvider.overrideWith((ref) => appState)],
            child: const MaterialApp(home: AuthScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final continueButton = find.byKey(const Key('appReviewContinueButton'));
        await tester.ensureVisible(continueButton);
        await tester.pumpAndSettle();
        expect(continueButton, findsOneWidget);
        expect(find.byKey(const Key('authIdentifierField')), findsNothing);
        expect(find.byKey(const Key('authPasswordField')), findsNothing);
        expect(find.textContaining('No username or password'), findsOneWidget);

        await tester.tap(continueButton);
        await tester.pumpAndSettle();

        expect(appState.isDemoAccount, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

void _setReviewViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
