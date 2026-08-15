import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../../core/config/app_environment.dart';
import '../../../shared/models/place_suggestion.dart';
import 'official_charger_search_service.dart';
import 'official_charger_station.dart';

/// Uses the VoltMapEV server as the only source of operator-authorized live
/// status. If that service is unavailable, the dated BEE inventory remains
/// available with an explicit fallback message instead of invented live data.
class RealtimeChargerSearchService extends OfficialChargerSearchService {
  RealtimeChargerSearchService({
    http.Client? client,
    String? baseUrl,
    OfficialChargerSearchService? fallback,
  })  : _client = client ?? http.Client(),
        _baseUri = Uri.parse(
          baseUrl ?? AppRuntimeConfig.realtimeChargerApiBaseUrl,
        ),
        _fallback = fallback ?? const OfficialChargerSearchService();

  final http.Client _client;
  final Uri _baseUri;
  final OfficialChargerSearchService _fallback;

  @override
  Future<OfficialChargerSearchResult> search({
    required String query,
    PlaceSuggestion? center,
  }) async {
    if (center == null || _baseUri.scheme != 'https' || _baseUri.host.isEmpty) {
      return _fallback.search(query: query, center: center);
    }

    try {
      return await _loadRealtime(center);
    } catch (_) {
      final fallback = await _fallback.search(query: query, center: center);
      return OfficialChargerSearchResult(
        source: fallback.source,
        sourceUrl: fallback.sourceUrl,
        asOf: fallback.asOf,
        totalStationCount: fallback.totalStationCount,
        radiusKm: fallback.radiusKm,
        matches: fallback.matches,
        statusMessage:
            'Live operator status is temporarily unavailable. Showing the dated BEE inventory; availability and price are not live.',
      );
    }
  }

  Future<OfficialChargerSearchResult> _loadRealtime(
    PlaceSuggestion center,
  ) async {
    final radiusKm = center.type == 'postcode' ? 15.0 : 25.0;
    final uri = _baseUri.resolve('/v1/chargers/nearby').replace(
      queryParameters: {
        'latitude': center.latitude.toString(),
        'longitude': center.longitude.toString(),
        'radiusKm': radiusKm.toString(),
      },
    );
    final response = await _client.get(
      uri,
      headers: const {'accept': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Live charger service returned ${response.statusCode}.',
        uri,
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final asOf = DateTime.parse(_requiredString(body, 'asOf')).toUtc();
    final rows = body['stations'] as List<dynamic>? ?? const [];
    final matches = rows.map((raw) {
      final row = raw as Map<String, dynamic>;
      final latitude = (row['latitude'] as num).toDouble();
      final longitude = (row['longitude'] as num).toDouble();
      final connectors =
          (row['connectors'] as List<dynamic>? ?? const []).map((rawConnector) {
        final connector = rawConnector as Map<String, dynamic>;
        return OfficialChargerConnector(
          type: connector['type'] as String? ?? 'Connector',
          ratingKw: (connector['ratingKw'] as num?)?.toDouble(),
          count: (connector['count'] as num?)?.toInt(),
        );
      }).toList(growable: false);
      final station = OfficialChargerStation(
        providerStationId: _requiredString(row, 'providerStationId'),
        operatorName: _requiredString(row, 'operatorName'),
        ownership: row['ownership'] as String? ?? 'Operator',
        state: row['state'] as String? ?? '',
        district: row['district'] as String? ?? '',
        city: row['city'] as String? ?? '',
        address: row['address'] as String? ?? '',
        latitude: latitude,
        longitude: longitude,
        postcodes: (row['postcodes'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
        connectors: connectors,
        availableConnectors: (row['availableConnectors'] as num?)?.toInt(),
        totalConnectors: (row['totalConnectors'] as num?)?.toInt(),
        pricePerKwh: (row['pricePerKwh'] as num?)?.toDouble(),
        currency: row['currency'] as String? ?? 'INR',
        liveStatusUpdatedAt: DateTime.parse(
          _requiredString(row, 'statusUpdatedAt'),
        ).toUtc(),
      );
      return OfficialChargerMatch(
        station: station,
        distanceKm: _distanceKm(
          center.latitude,
          center.longitude,
          latitude,
          longitude,
        ),
        exactPostcode: center.type == 'postcode' &&
            station.postcodes.contains(
              RegExp(r'(?<!\d)([1-9]\d{5})(?!\d)')
                  .firstMatch(center.displayName)
                  ?.group(1),
            ),
      );
    }).toList(growable: false)
      ..sort((a, b) => (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity));

    return OfficialChargerSearchResult(
      source: _requiredString(body, 'source'),
      sourceUrl: _requiredString(body, 'sourceUrl'),
      asOf: asOf,
      totalStationCount:
          (body['totalStationCount'] as num?)?.toInt() ?? matches.length,
      radiusKm: (body['radiusKm'] as num?)?.toDouble() ?? radiusKm,
      matches: matches,
      isRealtime: true,
      statusMessage:
          'Live operator status updated ${asOf.toLocal().toIso8601String()}.',
    );
  }

  static String _requiredString(Map<String, dynamic> body, String key) {
    final value = body[key] as String?;
    if (value == null || value.isEmpty) {
      throw FormatException('Missing $key');
    }
    return value;
  }

  static double _distanceKm(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(latitudeB - latitudeA);
    final dLon = _radians(longitudeB - longitudeA);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(latitudeA)) *
            math.cos(_radians(latitudeB)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double value) => value * math.pi / 180;
}
