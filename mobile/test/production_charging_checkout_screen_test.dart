import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voltmap/core/config/app_environment.dart';
import 'package:voltmap/features/payments/presentation/production_charging_checkout_screen.dart';
import 'package:voltmap/shared/models/charging_receipt.dart';
import 'package:voltmap/shared/models/charging_station.dart';
import 'package:voltmap/shared/services/secure_charging_api.dart';
import 'package:voltmap/shared/services/secure_identity_api.dart';

void main() {
  if (AppRuntimeConfig.isSandbox) {
    test('production checkout test requires production dart defines', () {
      expect(AppRuntimeConfig.hasSecureIdentityBackend, isFalse);
      expect(AppRuntimeConfig.hasSecurePaymentBackend, isFalse);
    });
    return;
  }

  testWidgets(
      'verifies contact, opens hosted checkout, and accepts only server receipt',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final identityApi = SecureIdentityApi(
      baseUrl: 'https://api.voltmapev.test',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/verify')) {
          return http.Response(
            jsonEncode({
              'verified': true,
              'verifiedContactToken': 'contact_token_123',
              'destination': '******8714',
            }),
            200,
          );
        }
        expect(jsonDecode(request.body)['channel'], 'whatsapp');
        return http.Response(
          jsonEncode({
            'challengeId': 'otp_123',
            'destination': '9392788714',
            'expiresAt': '2099-08-15T13:00:00Z',
            'resendAt': '2099-08-15T12:55:30Z',
            'attemptsRemaining': 5,
          }),
          201,
        );
      }),
    );
    var receiptRequested = false;
    final chargingApi = SecureChargingApi(
      baseUrl: 'https://api.voltmapev.test',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          receiptRequested = true;
          return http.Response(jsonEncode(_receipt.toJson()), 200);
        }
        return http.Response(
          jsonEncode({
            'sessionId': 'session_123',
            'checkoutUrl': 'https://provider.example/checkout/123',
            'expiresAt': '2026-08-15T13:00:00Z',
          }),
          201,
        );
      }),
    );
    Uri? launchedUrl;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ProductionChargingCheckoutScreen(
            station: _station,
            identityApi: identityApi,
            chargingApi: chargingApi,
            checkoutLauncher: (url) async {
              launchedUrl = url;
              return true;
            },
          ),
        ),
      ),
    );

    final destinationField =
        find.byKey(const Key('productionReceiptDestination'));
    await tester.scrollUntilVisible(
      destinationField,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final destinationInput = tester.widget<TextField>(destinationField);
    expect(destinationInput.decoration?.prefixText, '+91 ');
    expect(find.text('WhatsApp'), findsOneWidget);
    await tester.enterText(
      destinationField,
      '9392788714',
    );
    final sendOtp = find.byKey(const Key('productionSendOtp'));
    await tester.ensureVisible(sendOtp);
    await tester.tap(sendOtp);
    await tester.pumpAndSettle();
    final otpField = find.byKey(const Key('productionOtpCode'));
    await tester.ensureVisible(otpField);
    await tester.enterText(otpField, '654321');
    final verifyOtp = find.byKey(const Key('productionVerifyOtp'));
    await tester.ensureVisible(verifyOtp);
    await tester.tap(verifyOtp);
    await tester.pumpAndSettle();

    expect(find.text('Receipt destination verified'), findsOneWidget);
    await tester.tap(find.byKey(const Key('productionCheckoutButton')));
    await tester.pumpAndSettle();

    expect(launchedUrl, Uri.parse('https://provider.example/checkout/123'));
    expect(
      find.text('Check verified payment & receipt'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('productionCheckoutButton')));
    await tester.pumpAndSettle();

    expect(receiptRequested, isTrue);
    expect(find.byKey(const Key('chargingReceiptScreen')), findsOneWidget);
    expect(find.text('Payment and meter reading verified'), findsOneWidget);
  });
}

const _station = ChargingStation(
  id: 'station-1',
  name: 'Verified Charge Hub',
  network: 'Operator',
  address: 'Karmanghat',
  city: 'Hyderabad',
  state: 'Telangana',
  postalCode: '500079',
  distanceKm: 1.2,
  powerKw: 60,
  availableConnectors: 1,
  totalConnectors: 2,
  latitude: 17.337,
  longitude: 78.535,
  connectorTypes: ['CCS2-01'],
  pricePerKwh: 18.5,
  rating: 4.8,
  amenities: [],
  dataSource: 'Operator OCPI',
  dataUpdatedLabel: 'Live status',
  availabilityIsLive: true,
  pricingIsLive: true,
);

final _receipt = ChargingReceipt(
  id: 'receipt-1',
  stationId: 'station-1',
  stationName: 'Verified Charge Hub',
  connectorType: 'CCS2-01',
  energyKwh: 10,
  ratePerKwh: 18.5,
  energySubtotal: 185,
  taxAmount: 0,
  serviceFee: 5,
  amount: 190,
  paymentMethod: 'UPI via provider',
  paymentReference: 'pay_verified_123',
  chargingSessionId: 'session_123',
  paymentVerified: true,
  meterReadingConfirmed: true,
  environment: 'production',
  createdAt: DateTime.utc(2026, 8, 15, 12),
  phoneVerified: true,
  deliveryMethod: 'WhatsApp',
  deliveryDestination: '******8714',
  deliveryStatus: 'Delivered',
  deliveryAttempts: [
    ReceiptDeliveryAttempt(
      channel: 'whatsapp',
      destination: '******8714',
      status: 'delivered',
      attemptedAt: DateTime.utc(2026, 8, 15, 12, 1),
      attemptNumber: 1,
    ),
  ],
);
