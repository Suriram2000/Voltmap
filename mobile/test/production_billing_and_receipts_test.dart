import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voltmap/shared/models/charging_receipt.dart';
import 'package:voltmap/shared/services/charging_billing.dart';
import 'package:voltmap/shared/services/secure_charging_api.dart';
import 'package:voltmap/shared/services/secure_identity_api.dart';

void main() {
  group('confirmed metered billing', () {
    test('rounds units, subtotal, tax, fee and total deterministically', () {
      final bill = ChargingBilling.calculate(
        confirmedUnitsKwh: 12.7549,
        ratePerKwh: 18.50,
        taxRate: 0.18,
        serviceFee: 5,
      );

      expect(bill.unitsKwh, 12.755);
      expect(bill.energySubtotal, 235.97);
      expect(bill.taxAmount, 42.47);
      expect(bill.serviceFee, 5);
      expect(bill.total, 283.44);
    });

    test('rejects negative meter and money inputs', () {
      expect(
        () => ChargingBilling.calculate(
          confirmedUnitsKwh: -1,
          ratePerKwh: 18,
          taxRate: 0,
          serviceFee: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('verified receipt audit record', () {
    final receipt = ChargingReceipt(
      id: 'VM-RECEIPT-1',
      stationId: 'station-1',
      stationName: 'Verified Charge Hub',
      connectorType: 'CCS2-01',
      energyKwh: 12.755,
      ratePerKwh: 18.50,
      energySubtotal: 235.97,
      taxAmount: 42.47,
      serviceFee: 5,
      amount: 283.44,
      paymentMethod: 'UPI via provider',
      paymentReference: 'pay_verified_123',
      chargingSessionId: 'session_123',
      paymentVerified: true,
      meterReadingConfirmed: true,
      environment: 'production',
      createdAt: DateTime.utc(2026, 8, 14, 12),
      customerPhone: '••••••8714',
      customerEmail: 'd•••@example.com',
      phoneVerified: true,
      emailVerified: true,
      deliveryMethod: 'Email and SMS',
      deliveryDestination: 'verified contacts',
      deliveryStatus: 'Delivered',
      deliveryAttempts: [
        ReceiptDeliveryAttempt(
          channel: 'email',
          destination: 'd•••@example.com',
          status: 'retry_scheduled',
          attemptedAt: DateTime.utc(2026, 8, 14, 12, 0, 5),
          attemptNumber: 1,
          errorCode: 'temporary_provider_error',
        ),
        ReceiptDeliveryAttempt(
          channel: 'email',
          destination: 'd•••@example.com',
          status: 'delivered',
          attemptedAt: DateTime.utc(2026, 8, 14, 12, 1),
          attemptNumber: 2,
        ),
      ],
    );

    test('round trips every required receipt and delivery field', () {
      final restored = ChargingReceipt.fromJson(receipt.toJson());

      expect(restored.isVerifiedSuccessful, isTrue);
      expect(restored.ratePerKwh, 18.50);
      expect(restored.taxAmount, 42.47);
      expect(restored.serviceFee, 5);
      expect(restored.paymentReference, 'pay_verified_123');
      expect(restored.chargingSessionId, 'session_123');
      expect(restored.deliveryAttempts, hasLength(2));
      expect(restored.deliveryAttempts.last.delivered, isTrue);
    });

    test('downloadable text includes the complete billing trail', () {
      final text = receipt.toPlainText();

      expect(text, contains('Verified Charge Hub'));
      expect(text, contains('Units consumed: 12.76 kWh'));
      expect(text, contains('Rate per unit: INR 18.50/kWh'));
      expect(text, contains('Taxes: INR 42.47'));
      expect(text, contains('Total amount: INR 283.44'));
      expect(text, contains('pay_verified_123'));
      expect(text, contains('session_123'));
    });
  });

  group('secure server contract', () {
    test('uses an idempotency key and never sends raw payment credentials',
        () async {
      late http.Request captured;
      final api = SecureChargingApi(
        baseUrl: 'https://payments.voltmapev.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'sessionId': 'session_123',
              'checkoutUrl': 'https://provider.example/checkout/123',
              'expiresAt': '2026-08-14T13:00:00Z',
            }),
            201,
          );
        }),
      );

      final authorization = await api.authorizeSession(
        stationId: 'station-1',
        chargerId: 'CCS2-01',
        approvedEnergyLimitKwh: 20,
        disclosedRatePerKwh: 18.5,
        disclosedTaxRate: 0.18,
        disclosedServiceFee: 5,
        verifiedContactToken: 'contact_token_123',
        idempotencyKey: 'session-create-123',
      );

      expect(authorization.sessionId, 'session_123');
      expect(captured.headers['idempotency-key'], 'session-create-123');
      expect(captured.body, isNot(contains('cardNumber')));
      expect(captured.body, isNot(contains('cvv')));
      expect(captured.body, isNot(contains('upiPin')));
    });

    test('refuses a receipt not verified by webhook and meter', () async {
      final unverified = ChargingReceipt(
        id: 'VM-1',
        stationId: 'station-1',
        stationName: 'Station',
        connectorType: 'CCS2',
        energyKwh: 2,
        amount: 40,
        paymentMethod: 'provider',
        paymentReference: 'pay_1',
        chargingSessionId: 'session_1',
        paymentVerified: false,
        meterReadingConfirmed: true,
        environment: 'production',
        createdAt: DateTime.utc(2026, 8, 14),
      );
      final api = SecureChargingApi(
        baseUrl: 'https://payments.voltmapev.test',
        client: MockClient(
          (_) async => http.Response(jsonEncode(unverified.toJson()), 200),
        ),
      );

      expect(
        () => api.verifiedReceipt('session_1'),
        throwsA(isA<SecureChargingApiException>()),
      );
    });

    test('refund requests are idempotent and contain no banking data',
        () async {
      late http.Request captured;
      final api = SecureChargingApi(
        baseUrl: 'https://payments.voltmapev.com',
        client: MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'status': 'refund_pending'}), 202);
        }),
      );

      await api.requestRefund(
        paymentReference: 'pay_verified_123',
        reason: 'charging_session_interrupted',
        idempotencyKey: 'refund-pay_verified_123-1',
      );

      expect(
        captured.url.path,
        '/v1/payments/pay_verified_123/refunds',
      );
      expect(
        captured.headers['idempotency-key'],
        'refund-pay_verified_123-1',
      );
      expect(captured.body, contains('charging_session_interrupted'));
      expect(captured.body, isNot(contains('card')));
      expect(captured.body, isNot(contains('cvv')));
      expect(captured.body, isNot(contains('upiPin')));
    });
  });

  group('secure OTP contract', () {
    test('sends only the destination and receives no preview OTP', () async {
      late http.Request captured;
      final api = SecureIdentityApi(
        baseUrl: 'https://identity.voltmapev.test',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'challengeId': 'otp_123',
              'destination': '9392788714',
              'expiresAt': '2026-08-14T13:00:00Z',
              'resendAt': '2026-08-14T12:55:30Z',
              'attemptsRemaining': 5,
            }),
            201,
          );
        }),
      );

      final challenge = await api.sendOtp(
        channel: 'sms',
        destination: '9392788714',
        purpose: 'account_sign_in',
      );

      expect(challenge.id, 'otp_123');
      expect(challenge.attemptsRemaining, 5);
      expect(challenge.resendAt, DateTime.utc(2026, 8, 14, 12, 55, 30));
      expect(captured.url.path, '/v1/identity/otp/challenges');
      expect(captured.body, isNot(contains('123456')));
      expect(captured.body, isNot(contains('previewCode')));
    });

    test('returns an opaque contact token only after OTP verification',
        () async {
      final api = SecureIdentityApi(
        baseUrl: 'https://identity.voltmapev.test',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'verified': true,
              'verifiedContactToken': 'contact_token_123',
              'destination': 'd***@example.com',
            }),
            200,
          );
        }),
      );
      final contact = await api.verifyOtp(
        challenge: ContactOtpChallenge(
          id: 'otp_123',
          channel: 'email',
          destination: 'driver@example.com',
          expiresAt: DateTime.utc(2026, 8, 14, 13),
          resendAt: DateTime.utc(2026, 8, 14, 12, 55, 30),
          attemptsRemaining: 5,
        ),
        code: '654321',
      );

      expect(contact.token, 'contact_token_123');
      expect(contact.destination, 'd***@example.com');
    });

    test('preserves server rate-limit and attempt metadata', () async {
      final api = SecureIdentityApi(
        baseUrl: 'https://identity.voltmapev.com',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': 'otp_rate_limited',
              'message': 'Too many OTP requests. Try again later.',
              'retryAfterSeconds': 60,
              'attemptsRemaining': 0,
            }),
            429,
          ),
        ),
      );

      expect(
        () => api.sendOtp(
          channel: 'sms',
          destination: '9392788714',
          purpose: 'account_sign_in',
        ),
        throwsA(
          isA<SecureIdentityApiException>()
              .having((error) => error.code, 'code', 'otp_rate_limited')
              .having(
                (error) => error.retryAfterSeconds,
                'retryAfterSeconds',
                60,
              )
              .having(
                (error) => error.attemptsRemaining,
                'attemptsRemaining',
                0,
              ),
        ),
      );
    });
  });
}
