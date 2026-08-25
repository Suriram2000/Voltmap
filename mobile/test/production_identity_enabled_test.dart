import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltmap/core/config/app_environment.dart';
import 'package:voltmap/features/auth/presentation/phone_verification_screen.dart';

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
}
