import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:voltmap/features/discovery/data/official_charger_search_service.dart';
import 'package:voltmap/features/discovery/data/official_charger_station.dart';
import 'package:voltmap/features/discovery/data/realtime_charger_search_service.dart';
import 'package:voltmap/shared/models/place_suggestion.dart';

void main() {
  const center = PlaceSuggestion(
    primaryText: '500079',
    secondaryText: 'Hyderabad, Telangana, India',
    latitude: 17.3366,
    longitude: 78.5349,
    type: 'postcode',
  );

  test('maps timestamped operator availability and tariff data', () async {
    late http.Request captured;
    final service = RealtimeChargerSearchService(
      baseUrl: 'https://api.voltmapev.test',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'source': 'Operator OCPI',
            'sourceUrl': 'https://operator.example',
            'asOf': '2026-08-15T12:00:00Z',
            'radiusKm': 15,
            'totalStationCount': 1,
            'stations': [
              {
                'providerStationId': 'op-123',
                'operatorName': 'Verified Charge Hub',
                'state': 'Telangana',
                'district': 'Hyderabad',
                'city': 'Hyderabad',
                'address': 'Karmanghat',
                'latitude': 17.337,
                'longitude': 78.535,
                'postcodes': ['500079'],
                'connectors': [
                  {'type': 'CCS2', 'ratingKw': 60, 'count': 2},
                ],
                'availableConnectors': 1,
                'totalConnectors': 2,
                'pricePerKwh': 18.5,
                'currency': 'INR',
                'statusUpdatedAt': '2026-08-15T11:59:30Z',
              },
            ],
          }),
          200,
        );
      }),
    );

    final result =
        await service.search(query: center.displayName, center: center);

    expect(captured.url.path, '/v1/chargers/nearby');
    expect(captured.url.queryParameters['radiusKm'], '15.0');
    expect(result.isRealtime, isTrue);
    expect(result.matches, hasLength(1));
    final station = result.matches.single.station;
    expect(station.providerStationId, 'op-123');
    expect(station.availableConnectors, 1);
    expect(station.totalConnectors, 2);
    expect(station.pricePerKwh, 18.5);
    expect(station.hasLiveAvailability, isTrue);
    expect(station.hasLivePrice, isTrue);
  });

  test('falls back to dated inventory with an explicit disclosure', () async {
    final service = RealtimeChargerSearchService(
      baseUrl: 'https://api.voltmapev.test',
      client: MockClient((_) async => http.Response('unavailable', 503)),
      fallback: const _FallbackSearchService(),
    );

    final result =
        await service.search(query: center.displayName, center: center);

    expect(result.isRealtime, isFalse);
    expect(result.matches, hasLength(1));
    expect(result.statusMessage, contains('Live operator status'));
    expect(result.statusMessage, contains('dated BEE inventory'));
    expect(result.matches.single.station.hasLiveAvailability, isFalse);
  });
}

class _FallbackSearchService extends OfficialChargerSearchService {
  const _FallbackSearchService();

  @override
  Future<OfficialChargerSearchResult> search({
    required String query,
    PlaceSuggestion? center,
  }) async {
    return OfficialChargerSearchResult(
      source: 'BEE',
      sourceUrl: 'https://beeindia.gov.in',
      asOf: DateTime.utc(2025, 10, 26),
      totalStationCount: 1,
      radiusKm: 15,
      matches: const [
        OfficialChargerMatch(
          station: OfficialChargerStation(
            operatorName: 'Inventory Station',
            ownership: '',
            state: 'Telangana',
            district: 'Hyderabad',
            city: 'Hyderabad',
            address: 'Karmanghat',
            latitude: 17.337,
            longitude: 78.535,
            postcodes: ['500079'],
            connectors: [OfficialChargerConnector(type: 'CCS2')],
          ),
          distanceKm: 1,
          exactPostcode: true,
        ),
      ],
    );
  }
}
