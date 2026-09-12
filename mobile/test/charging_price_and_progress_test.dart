import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voltmap/features/discovery/presentation/charge_here_sheet.dart';
import 'package:voltmap/features/payments/presentation/charging_progress_card.dart';
import 'package:voltmap/shared/models/charging_session_status.dart';
import 'package:voltmap/shared/services/secure_charging_api.dart';

Map<String, dynamic> snapshot() => {
      'sessionId': 'session-1',
      'stationId': 'station-1',
      'environment': 'production',
      'currency': 'INR',
      'status': 'charging',
      'meterReadingConfirmed': true,
      'energyKwh': 2.5,
      'ratePerKwh': 18.5,
      'energySubtotal': 46.25,
      'taxAmount': 0,
      'serviceFee': 5,
      'totalAmount': 51.25,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

void main() {
  test('rejects unconfirmed meter, invalid amounts and inconsistent totals',
      () {
    for (final change in <Map<String, dynamic>>[
      {'meterReadingConfirmed': false},
      {'energyKwh': -1},
      {'ratePerKwh': double.nan},
      {'totalAmount': 0},
      {'currency': 'USD'},
      {'environment': 'sandbox'},
      {'status': 'made_up'},
      {'updatedAt': '2099-01-01T00:00:00Z'},
    ]) {
      expect(() => ChargingSessionStatus.fromJson({...snapshot(), ...change}),
          throwsFormatException,
          reason: '$change');
    }
  });

  test('API refuses another session or station and accepts pending updates',
      () async {
    for (final change in [
      {'sessionId': 'other'},
      {'stationId': 'other'}
    ]) {
      final api = SecureChargingApi(
          baseUrl: 'https://api.voltmapev.test',
          client: MockClient((_) async =>
              http.Response(jsonEncode({...snapshot(), ...change}), 200)));
      await expectLater(
          api.sessionStatus(
              sessionId: 'session-1',
              stationId: 'station-1',
              verifiedContactToken: 'token'),
          throwsA(isA<SecureChargingApiException>()));
    }
    final api = SecureChargingApi(
        baseUrl: 'https://api.voltmapev.test',
        client: MockClient((_) async => http.Response('', 202)));
    expect(
        await api.sessionStatus(
            sessionId: 'session-1',
            stationId: 'station-1',
            verifiedContactToken: 'token'),
        isNull);
  });

  for (final width in [320.0, 744.0, 1032.0]) {
    testWidgets(
        'unit price guide fits width $width and unknown rates are not free',
        (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final price in <double?>[18.5, null]) {
        await tester.pumpWidget(MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => showChargeHereSheet(
                              context: context,
                              stationName: 'Selected station',
                              operatorName: 'Operator',
                              address: 'Hyderabad',
                              pricePerKwh: price,
                              onDirections: () async {},
                            ),
                        child: const Text('Open'))))));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('1 unit = 1 kWh'), findsOneWidget);
        if (price == null) {
          expect(find.text('Price per unit: confirm with operator'),
              findsOneWidget);
          expect(find.textContaining('₹0.00'), findsNothing);
        } else {
          expect(find.text('₹18.50 per unit'), findsOneWidget);
          expect(find.textContaining('Reference estimate'), findsOneWidget);
          expect(find.textContaining('₹185.00'), findsOneWidget);
        }
        expect(find.text('While charging'), findsOneWidget);
        expect(find.text('Charging complete'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets(
      'progress uses server units and marks stale data without claiming paid',
      (tester) async {
    final data = ChargingSessionStatus.fromJson(snapshot());
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ChargingProgressCard(
      snapshot: data,
      now: data.updatedAt.add(const Duration(minutes: 2)),
    ))));
    expect(find.text('Last reported: Charging in progress'), findsOneWidget);
    expect(find.text('2.500 kWh'), findsOneWidget);
    expect(find.text('₹51.25'), findsOneWidget);
    expect(find.textContaining('Update delayed'), findsOneWidget);
    expect(find.text('Paid'), findsNothing);
    expect(find.text('Charging complete'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
