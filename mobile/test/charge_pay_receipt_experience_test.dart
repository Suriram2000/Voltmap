import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/features/discovery/data/sample_stations.dart';
import 'package:voltmap/features/discovery/presentation/station_details_screen.dart';
import 'package:voltmap/features/payments/presentation/charging_receipt_screen.dart';
import 'package:voltmap/shared/models/charging_receipt.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'voltmap_signed_in': true,
      'voltmap_profile_name': 'Test Driver',
      'voltmap_profile_email': 'driver@voltmap.in',
    });
  });

  testWidgets('compact charger details support compare, navigate and charge', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final station = sampleStations.first;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: StationDetailsScreen(station: station)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chargerDetailsHero')), findsOneWidget);
    expect(find.text('Choose the right charger'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Charging speed'),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Charging speed'), findsOneWidget);
    expect(find.text('Connector'), findsOneWidget);
    expect(find.text('Estimated price'), findsOneWidget);
    expect(find.text('Listed ports'), findsOneWidget);
    expect(find.text('Navigate'), findsOneWidget);
    expect(find.text('Charge & pay'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed session shows an honest itemized receipt on phone', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    final station = sampleStations.first;
    final receipt = ChargingReceipt(
      id: 'VM-RECEIPT-123',
      stationId: station.id,
      stationName: station.name,
      connectorType: station.connectorTypes.first,
      energyKwh: 18.4,
      ratePerKwh: 18,
      energySubtotal: 331.2,
      taxAmount: 59.62,
      serviceFee: 0.18,
      amount: 391,
      paymentMethod: 'UPI dr••@upi',
      paymentReference: 'PAY-VERIFIED-123',
      chargingSessionId: 'SESSION-123',
      paymentVerified: true,
      meterReadingConfirmed: true,
      environment: 'production',
      createdAt: DateTime(2026, 8, 14, 20, 15),
      deliveryMethod: 'Email',
      deliveryDestination: 'd•••@example.com',
      deliveryStatus: 'Delivered by email',
      emailVerified: true,
      deliveryAttempts: [
        ReceiptDeliveryAttempt(
          channel: 'email',
          destination: 'd•••@example.com',
          status: 'delivered',
          attemptedAt: DateTime(2026, 8, 14, 20, 16),
          attemptNumber: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChargingReceiptScreen(receipt: receipt, station: station),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chargingReceiptScreen')), findsOneWidget);
    expect(find.text('Session completed'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('18.40'),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('18.40'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('₹391.00'),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('₹391.00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('PAY-VERIFIED-123'),
      420,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('SESSION-123'), findsOneWidget);
    expect(find.text('PAY-VERIFIED-123'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Verified digital receipt'),
      350,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Delivered by email'), findsOneWidget);
    expect(find.text('Verified digital receipt'), findsOneWidget);
    expect(find.byKey(const Key('receiptDoneButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
