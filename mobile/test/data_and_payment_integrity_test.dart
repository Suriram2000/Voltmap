import 'package:flutter_test/flutter_test.dart';
import 'package:voltmap/features/discovery/data/national_charger_data.dart';
import 'package:voltmap/features/discovery/data/sample_stations.dart';
import 'package:voltmap/shared/models/charger_submission.dart';
import 'package:voltmap/shared/models/charging_receipt.dart';
import 'package:voltmap/shared/models/saved_trip.dart';
import 'package:voltmap/shared/services/sandbox_payment_validator.dart';

void main() {
  group('sandbox payment field validation', () {
    test('UPI accepts only documented sandbox identities', () {
      expect(
        SandboxPaymentValidator.validateUpi(null),
        'Enter a valid sandbox UPI ID',
      );
      expect(
        SandboxPaymentValidator.validateUpi('a@upi'),
        'Enter a valid sandbox UPI ID',
      );
      expect(
        SandboxPaymentValidator.validateUpi('real.person@bank'),
        'UPI ID could not be verified. Use driver@upi',
      );
      expect(SandboxPaymentValidator.validateUpi(' DRIVER@UPI '), isNull);
      expect(SandboxPaymentValidator.validateUpi('success@upi'), isNull);
    });

    test('cardholder, card number, and CVV reject malformed values', () {
      expect(
        SandboxPaymentValidator.validateCardholder(' '),
        'Enter the cardholder name',
      );
      expect(SandboxPaymentValidator.validateCardholder('A'), isNotNull);
      expect(SandboxPaymentValidator.validateCardholder('Test Driver'), isNull);

      expect(SandboxPaymentValidator.validateCardNumber(''), isNotNull);
      expect(
        SandboxPaymentValidator.validateCardNumber('4242 4242 4242 4241'),
        'Enter a valid 16-digit sandbox card',
      );
      expect(
        SandboxPaymentValidator.validateCardNumber('4000 0000 0000 0002'),
        'Card was declined. Use sandbox card 4242 4242 4242 4242',
      );
      expect(
        SandboxPaymentValidator.validateCardNumber('4242 4242 4242 4242'),
        isNull,
      );

      for (final invalid in [null, '', '12', '12345', '12a', ' 123']) {
        expect(
          SandboxPaymentValidator.validateCvv(invalid),
          'Enter 3 or 4 digits',
        );
      }
      expect(SandboxPaymentValidator.validateCvv('123'), isNull);
      expect(SandboxPaymentValidator.validateCvv('1234'), isNull);
    });

    test('expiry rejects bad and past dates at month precision', () {
      final now = DateTime(2026, 8, 10);
      expect(
        SandboxPaymentValidator.validateExpiry('', currentDate: now),
        'Use MM/YY',
      );
      expect(
        SandboxPaymentValidator.validateExpiry('00/30', currentDate: now),
        'Invalid month',
      );
      expect(
        SandboxPaymentValidator.validateExpiry('13/30', currentDate: now),
        'Invalid month',
      );
      expect(
        SandboxPaymentValidator.validateExpiry('07/26', currentDate: now),
        'Card is expired',
      );
      expect(
        SandboxPaymentValidator.validateExpiry('08/26', currentDate: now),
        isNull,
      );
      expect(
        SandboxPaymentValidator.validateExpiry('12/30', currentDate: now),
        isNull,
      );
    });

    test('payment references are masked before display or persistence', () {
      expect(SandboxPaymentValidator.maskUpi('driver@upi'), 'UPI dr••@upi');
      expect(SandboxPaymentValidator.maskUpi('broken'), 'UPI account');
      expect(
        SandboxPaymentValidator.maskCard('4242 4242 4242 4242'),
        'Card ending 4242',
      );
      expect(SandboxPaymentValidator.maskCard('12'), 'Card');
    });
  });

  group('charger catalog integrity', () {
    test(
      'every bundled charger has valid and internally consistent fields',
      () {
        expect(sampleStations, hasLength(45));
        expect(
          sampleStations.map((station) => station.id).toSet(),
          hasLength(45),
        );

        for (final station in sampleStations) {
          expect(station.id.trim(), isNotEmpty, reason: station.name);
          expect(station.name.trim(), isNotEmpty, reason: station.id);
          expect(station.network.trim(), isNotEmpty, reason: station.id);
          expect(station.address.trim(), isNotEmpty, reason: station.id);
          expect(station.city.trim(), isNotEmpty, reason: station.id);
          expect(station.state.trim(), isNotEmpty, reason: station.id);
          expect(
            RegExp(r'^\d{6}$').hasMatch(station.postalCode),
            isTrue,
            reason: station.id,
          );
          expect(station.latitude, inInclusiveRange(6, 38), reason: station.id);
          expect(
            station.longitude,
            inInclusiveRange(68, 98),
            reason: station.id,
          );
          expect(
            station.distanceKm,
            greaterThanOrEqualTo(0),
            reason: station.id,
          );
          expect(station.powerKw, greaterThan(0), reason: station.id);
          expect(station.totalConnectors, greaterThan(0), reason: station.id);
          expect(
            station.availableConnectors,
            inInclusiveRange(0, station.totalConnectors),
            reason: station.id,
          );
          expect(station.connectorTypes, isNotEmpty, reason: station.id);
          expect(
            station.connectorTypes.toSet(),
            hasLength(station.connectorTypes.length),
          );
          expect(station.pricePerKwh, greaterThan(0), reason: station.id);
          expect(station.rating, inInclusiveRange(0, 5), reason: station.id);
          expect(station.dataSource.trim(), isNotEmpty, reason: station.id);
          expect(
            station.dataUpdatedLabel,
            contains('not live'),
            reason: station.id,
          );
          expect(station.availabilityIsLive, isFalse, reason: station.id);
          expect(station.pricingIsLive, isFalse, reason: station.id);
        }
      },
    );

    test('official coverage matches the dated government aggregate', () {
      expect(officialStationTotal, 29277);
      expect(officialStationDataDate, '1 August 2025');
      expect(stateChargerCoverage, hasLength(36));
      expect(
        stateChargerCoverage.map((coverage) => coverage.state).toSet(),
        hasLength(36),
      );
      expect(
        stateChargerCoverage.fold<int>(
          0,
          (total, coverage) => total + coverage.stationCount,
        ),
        officialStationTotal,
      );
      for (final coverage in stateChargerCoverage) {
        expect(coverage.state.trim(), isNotEmpty);
        expect(coverage.stationCount, greaterThan(0), reason: coverage.state);
      }
    });
  });

  group('stored model round trips', () {
    test('charger report preserves every submitted field', () {
      final original = ChargerSubmission(
        id: 'submission-1',
        stationName: 'Community Charge Hub',
        operatorName: 'Community Charge',
        address: 'LB Nagar Metro',
        city: 'Hyderabad',
        state: 'Telangana',
        postalCode: '500079',
        connectorTypes: const ['CCS2', 'Type 2'],
        reportedStatus: 'Working',
        notes: 'Photo and operator confirmation required.',
        createdAt: DateTime.utc(2026, 8, 10, 12, 30),
      );
      final restored = ChargerSubmission.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.stationName, original.stationName);
      expect(restored.operatorName, original.operatorName);
      expect(restored.address, original.address);
      expect(restored.city, original.city);
      expect(restored.state, original.state);
      expect(restored.postalCode, original.postalCode);
      expect(restored.connectorTypes, original.connectorTypes);
      expect(restored.reportedStatus, original.reportedStatus);
      expect(restored.notes, original.notes);
      expect(restored.createdAt, original.createdAt);
      expect(restored.issueBody, contains('Please verify this location'));
    });

    test(
      'receipt stores only masked payment reference and measured totals',
      () {
        final original = ChargingReceipt(
          id: 'VM-123',
          stationId: 'chargezone-1',
          stationName: 'ChargeZone Hitech City',
          connectorType: 'CCS2',
          energyKwh: 12.75,
          amount: 240.88,
          paymentMethod: 'Card ending 4242',
          createdAt: DateTime.utc(2026, 8, 10, 12),
          customerPhone: '••••••8714',
          deliveryMethod: 'Email',
          deliveryDestination: 'd•••@example.com',
          deliveryStatus: 'Not sent — provider not connected',
        );
        final restored = ChargingReceipt.fromJson(original.toJson());

        expect(restored.id, original.id);
        expect(restored.stationId, original.stationId);
        expect(restored.energyKwh, original.energyKwh);
        expect(restored.amount, original.amount);
        expect(restored.paymentMethod, 'Card ending 4242');
        expect(restored.paymentMethod, isNot(contains('4242424242424242')));
        expect(restored.createdAt, original.createdAt);
        expect(restored.customerPhone, '••••••8714');
        expect(restored.deliveryMethod, 'Email');
        expect(restored.deliveryDestination, 'd•••@example.com');
        expect(
          restored.deliveryStatus,
          'Not sent — provider not connected',
        );
      },
    );

    test('saved trip preserves only selected route charger identifiers', () {
      final original = SavedTrip(
        id: 'trip-1',
        origin: 'Hyderabad',
        destination: 'Bengaluru',
        distanceKm: 570,
        estimatedMinutes: 660,
        stopStationIds: const ['zeon-electronic-city'],
        createdAt: DateTime.utc(2026, 8, 10),
      );
      final restored = SavedTrip.fromJson(original.toJson());

      expect(restored.origin, original.origin);
      expect(restored.destination, original.destination);
      expect(restored.distanceKm, original.distanceKm);
      expect(restored.estimatedMinutes, original.estimatedMinutes);
      expect(restored.stopStationIds, original.stopStationIds);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
