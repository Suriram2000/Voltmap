import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/features/auth/presentation/auth_screen.dart';
import 'package:voltmap/features/discovery/presentation/add_charger_screen.dart';

void main() {
  testWidgets('signup reports every required invalid field', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter a valid email or phone number'), findsOneWidget);
    expect(
      find.text('Use 8+ characters with upper, lower, and a number'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('authNameField')), 'A');
    await tester.enterText(
        find.byKey(const Key('authIdentifierField')), '12345');
    await tester.enterText(find.byKey(const Key('authPasswordField')), 'weak');
    await tester.enterText(
        find.byKey(const Key('authConfirmField')), 'different');
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter a valid email or phone number'), findsOneWidget);
    expect(
      find.text('Use 8+ characters with upper, lower, and a number'),
      findsOneWidget,
    );
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('login distinguishes required fields from bad credentials', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();
    expect(find.text('Enter a valid email or phone number'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('authIdentifierField')),
      'driver@example.com',
    );
    await tester.enterText(find.byKey(const Key('authPasswordField')), 'wrong');
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('authError')), findsOneWidget);
    expect(find.text('Email/phone or password is incorrect.'), findsOneWidget);
  });

  testWidgets('charger report validates every required location field', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AddChargerScreen())),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submitChargerReportButton')));
    await tester.pump();

    for (final label in [
      'Station name',
      'Operator or network',
      'Street address / landmark',
      'City / area',
      'State / UT',
    ]) {
      expect(find.text('Please enter $label'), findsOneWidget);
    }
    expect(find.text('Enter a valid 6-digit Indian PIN'), findsOneWidget);
  });

  testWidgets('charger PIN rejects malformed India postal codes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    _useDesktopViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AddChargerScreen())),
    );
    await tester.pumpAndSettle();

    final pin = find.byKey(const Key('chargerPinField'));
    final submit = find.byKey(const Key('submitChargerReportButton'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    for (final invalid in ['50007', '000000', '50007A']) {
      await tester.enterText(pin, invalid);
      await tester.tap(submit);
      await tester.pump();
      expect(find.text('Enter a valid 6-digit Indian PIN'), findsOneWidget);
    }
  });
}

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
