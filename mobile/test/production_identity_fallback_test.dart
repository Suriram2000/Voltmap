import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltmap/core/config/app_environment.dart';
import 'package:voltmap/features/auth/presentation/phone_verification_screen.dart';

void main() {
  testWidgets(
    'production without a secure identity endpoint never offers a broken OTP',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PhoneVerificationScreen(feature: 'Favorites'),
          ),
        ),
      );

      expect(find.text('Continue on this device'), findsNWidgets(2));
      expect(find.textContaining('WhatsApp verification is temporarily'),
          findsOneWidget);
      expect(find.textContaining('No OTP was sent'), findsOneWidget);
      expect(find.text('Send OTP on WhatsApp'), findsNothing);
      expect(find.byKey(const Key('otpPhoneField')), findsNothing);
    },
    skip: AppRuntimeConfig.isSandbox,
  );
}
