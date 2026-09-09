import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/core/config/app_environment.dart';
import 'package:voltmap/features/auth/presentation/phone_verification_screen.dart';
import 'package:voltmap/shared/models/saved_trip.dart';
import 'package:voltmap/shared/state/app_state.dart';
import 'package:voltmap/shared/widgets/registered_account_gate.dart';

void main() {
  testWidgets(
    'production offers WhatsApp OTP when the secure endpoint is configured',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PhoneVerificationScreen(feature: 'Favorites'),
          ),
        ),
      );

      expect(find.text('Continue with WhatsApp'), findsOneWidget);
      expect(find.text('Send OTP on WhatsApp'), findsOneWidget);
      expect(find.byKey(const Key('otpPhoneField')), findsOneWidget);
      expect(find.textContaining('temporarily unavailable'), findsNothing);
    },
    skip: AppRuntimeConfig.isSandbox ||
        !AppRuntimeConfig.hasSecureIdentityBackend,
  );

  for (final width in [360.0, 412.0]) {
    testWidgets(
      'Android production local access saves and deletes data at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final appState = AppState();
        await appState.load();
        bool? granted;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [appStateProvider.overrideWith((ref) => appState)],
            child: MaterialApp(
              theme: ThemeData(platform: TargetPlatform.android),
              home: Builder(
                builder: (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () async {
                      granted = await requireRegisteredAccount(
                        context,
                        appState,
                        'Saved trips and favorites',
                      );
                    },
                    child: const Text('Save a favorite'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Save a favorite'));
        await tester.pumpAndSettle();
        expect(find.text('Continue with WhatsApp'), findsOneWidget);
        final localAccess = find.byKey(const Key('appReviewDemoButton'));
        await tester.ensureVisible(localAccess);
        await tester.tap(localAccess);
        await tester.pumpAndSettle();

        expect(granted, isTrue);
        expect(appState.canUseSavedFeatures, isTrue);
        expect(appState.isDemoAccount, isTrue);
        await appState.toggleFavorite('review-station');
        await appState.saveTrip(SavedTrip(
          id: 'review-trip',
          origin: '500081',
          destination: '500079',
          distanceKm: 30,
          estimatedMinutes: 60,
          stopStationIds: const ['review-station'],
          createdAt: DateTime.utc(2026, 9, 9),
        ));
        final reloaded = AppState();
        await reloaded.load();
        expect(reloaded.canUseSavedFeatures, isTrue);
        expect(reloaded.isFavorite('review-station'), isTrue);
        expect(reloaded.savedTrips.single.id, 'review-trip');

        await reloaded.deleteLocalAccountAndData();
        final deleted = AppState();
        await deleted.load();
        expect(deleted.canUseSavedFeatures, isFalse);
        expect(deleted.favoriteStationIds, isEmpty);
        expect(deleted.savedTrips, isEmpty);
        expect(tester.takeException(), isNull);
      },
      skip: AppRuntimeConfig.isSandbox ||
          AppRuntimeConfig.isAppleAppStoreBuild ||
          !AppRuntimeConfig.hasSecureIdentityBackend,
    );
  }
}
