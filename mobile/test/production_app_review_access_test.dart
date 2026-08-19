import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/core/config/app_environment.dart';
import 'package:voltmap/features/auth/presentation/phone_verification_screen.dart';
import 'package:voltmap/features/profile/presentation/profile_screen.dart';
import 'package:voltmap/shared/state/app_state.dart';

void main() {
  if (AppRuntimeConfig.isSandbox) {
    test('App Review access test requires production dart defines', () {
      expect(AppRuntimeConfig.isSandbox, isTrue);
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
          overrides: [
            appStateProvider.overrideWith((ref) => appState),
          ],
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
      expect(find.byKey(const Key('appReviewDemoButton')), findsOneWidget);
      expect(
        find.textContaining('Local demo access for App Review'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('appReviewDemoButton')));
      await tester.pumpAndSettle();

      expect(accessGranted, isTrue);
      expect(appState.isSignedIn, isTrue);
      expect(appState.userIdentifier, 'demo@voltmapev.com');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateProvider.overrideWith((ref) => appState),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DEMO DRIVER PROFILE'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('deleteAccountTile')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('deleteAccountTile')), findsOneWidget);
    },
  );
}
