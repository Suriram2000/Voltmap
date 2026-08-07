import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/app/voltmap_app.dart';
import 'package:voltmap/features/discovery/data/sample_stations.dart';
import 'package:voltmap/features/discovery/presentation/station_details_screen.dart';
import 'package:voltmap/features/payments/presentation/charging_checkout_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

    await tester.enterText(find.byType(SearchBar), '500081');
    await tester.pumpAndSettle();
    expect(find.text('ChargeZone Hitech City'), findsOneWidget);
    expect(find.text('Tata Power Madhapur'), findsOneWidget);
    expect(find.text('2 results'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'Zeon');
    await tester.pumpAndSettle();
    expect(find.text('Zeon Charging Hub'), findsOneWidget);

    await tester.tap(find.byTooltip('Add to favorites').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('Zeon Charging Hub'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.text('Charger Map'), findsOneWidget);

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Destination'),
      'Vijayawada',
    );
    await tester.tap(find.text('Plan route'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Estimated energy:'), findsOneWidget);
    expect(find.text('Save this trip'), findsOneWidget);
  });

  testWidgets('UPI checkout saves a receipt and starts charging', (
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
    expect(find.text('Charging checkout'), findsOneWidget);
    expect(find.text('Credit / debit card'), findsOneWidget);
    expect(find.text('VoltMap wallet'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('upiIdField')), 'driver@upi');
    await tester.tap(find.byKey(const Key('payButton')));
    await tester.pump();
    expect(find.text('Processing securely…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.textContaining('UPI dr••@upi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('startChargingButton')));
    await tester.pumpAndSettle();
    expect(find.text('Charging session started'), findsOneWidget);
    expect(find.textContaining('Receipt: VM-'), findsOneWidget);
  });

  testWidgets('card checkout validates fields and accepts a test card', (
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
    await tester.tap(find.byKey(const Key('payButton')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('cardholderField')));
    await tester.pumpAndSettle();
    expect(find.text('Enter the cardholder name'), findsOneWidget);
    expect(find.text('Enter a valid 16-digit test card'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('cardholderField')));
    await tester.enterText(
      find.byKey(const Key('cardholderField')),
      'Test Driver',
    );
    await tester.ensureVisible(find.byKey(const Key('cardNumberField')));
    await tester.enterText(
      find.byKey(const Key('cardNumberField')),
      '4242424242424242',
    );
    await tester.ensureVisible(find.byKey(const Key('expiryField')));
    await tester.enterText(find.byKey(const Key('expiryField')), '1230');
    await tester.enterText(find.byKey(const Key('cvvField')), '123');
    await tester.tap(find.byKey(const Key('payButton')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('Card ending 4242'), findsOneWidget);
  });

  testWidgets('wallet checkout completes without payment credentials', (
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
    await tester.tap(find.byKey(const Key('payButton')));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('VoltMap demo wallet'), findsOneWidget);
  });
}

void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
