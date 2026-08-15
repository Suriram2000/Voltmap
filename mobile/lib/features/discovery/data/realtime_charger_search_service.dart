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
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _baseUri = Uri.parse(
          baseUrl ?? AppRuntimeConfig.realtimeChargerApiBaseUrl,
        ),
        _fallback = fallback ?? const OfficialChargerSearchService(),
        _clock = clock ?? DateTime.now;

  final http.Client _client;
  final Uri _baseUri;
  final OfficialChargerSearchService _fallback;
  final DateTime Function() _clock;

  @override
  Future<OfficialChargerSearchResult> search({
    required String query,
    PlaceSuggestion? center,
  }) async {
    if (center == null || _baseUri.scheme != 'https' || _baseUri.host.isEmpty) {
      return _fallback.search(query: query, center: center);
    }

    final fallbackRequest = _fallback.search(query: query, center: center);
    try {
      final realtime = await _loadRealtime(center);
      try {
        final inventory = await fallbackRequest;
        return _mergeResults(realtime: realtime, inventory: inventory);
      } catch (_) {
        return realtime;
      }
    } catch (_) {
      final fallback = await fallbackRequest;
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
    final source = _requiredString(body, 'source');
    final rows = body['stations'] as List<dynamic>? ?? const [];
    final matches = <OfficialChargerMatch>[];
    var rejectedRows = 0;
    for (final raw in rows) {
      try {
        final row = raw as Map<String, dynamic>;
        final station = _parseStation(row, source: source);
        matches.add(
          OfficialChargerMatch(
            station: station,
            distanceKm: _distanceKm(
              center.latitude,
              center.longitude,
              station.latitude,
              station.longitude,
            ),
            exactPostcode: center.type == 'postcode' &&
                station.postcodes.contains(
                  RegExp(r'(?<!\d)([1-9]\d{5})(?!\d)')
                      .firstMatch(center.displayName)
                      ?.group(1),
                ),
          ),
        );
      } catch (_) {
        // Keep valid stations available while excluding malformed, impossible,
        // or internally inconsistent provider records.
        rejectedRows++;
      }
    }
    matches.sort((a, b) => (a.distanceKm ?? double.infinity)
        .compareTo(b.distanceKm ?? double.infinity));

    return OfficialChargerSearchResult(
      source: source,
      sourceUrl: _requiredString(body, 'sourceUrl'),
      asOf: asOf,
      totalStationCount:
          (body['totalStationCount'] as num?)?.toInt() ?? matches.length,
      radiusKm: (body['radiusKm'] as num?)?.toDouble() ?? radiusKm,
      matches: matches,
      isRealtime: true,
      statusMessage: rejectedRows == 0
          ? 'Live operator status updated ${asOf.toLocal().toIso8601String()}.'
          : 'Live operator status updated ${asOf.toLocal().toIso8601String()}; $rejectedRows invalid provider record${rejectedRows == 1 ? '' : 's'} excluded.',
    );
  }

  OfficialChargerStation _parseStation(
    Map<String, dynamic> row, {
    required String source,
  }) {
    final latitude = (row['latitude'] as num).toDouble();
    final longitude = (row['longitude'] as num).toDouble();
    if (latitude < 6 || latitude > 38 || longitude < 68 || longitude > 98) {
      throw const FormatException('Station coordinates are outside India.');
    }

    final connectors =
        (row['connectors'] as List<dynamic>? ?? const []).map((rawConnector) {
      final connector = rawConnector as Map<String, dynamic>;
      final ratingKw = (connector['ratingKw'] as num?)?.toDouble();
      final count = (connector['count'] as num?)?.toInt();
      if (ratingKw != null && (ratingKw <= 0 || ratingKw > 1000)) {
        throw const FormatException('Invalid connector rating.');
      }
      if (count != null && count < 0) {
        throw const FormatException('Invalid connector count.');
      }
      return OfficialChargerConnector(
        type: connector['type'] as String? ?? 'Connector',
        ratingKw: ratingKw,
        count: count,
      );
    }).toList(growable: false);

    final available = (row['availableConnectors'] as num?)?.toInt();
    final total = (row['totalConnectors'] as num?)?.toInt();
    if (available != null &&
        (available < 0 || total == null || available > total)) {
      throw const FormatException('Invalid live availability counts.');
    }
    if (total != null && total < 0) {
      throw const FormatException('Invalid total connector count.');
    }
    final price = (row['pricePerKwh'] as num?)?.toDouble();
    if (price != null && (price <= 0 || price > 1000)) {
      throw const FormatException('Invalid tariff.');
    }

    final updatedAt =
        DateTime.parse(_requiredString(row, 'statusUpdatedAt')).toUtc();
    final age = _clock().toUtc().difference(updatedAt);
    final isFresh = age >= const Duration(minutes: -5) &&
        age <= const Duration(minutes: 15);
    final operatorVerified = row['operatorVerified'] as bool? ?? false;
    final sources = (row['sources'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);

    return OfficialChargerStation(
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
      availableConnectors: available,
      totalConnectors: total,
      pricePerKwh: price,
      currency: row['currency'] as String? ?? 'INR',
      liveStatusUpdatedAt: updatedAt,
      sourceNames: sources.isEmpty ? [source] : sources,
      operatorVerified: operatorVerified,
      liveDataIsFresh: isFresh && operatorVerified,
    );
  }

  static OfficialChargerSearchResult _mergeResults({
    required OfficialChargerSearchResult realtime,
    required OfficialChargerSearchResult inventory,
  }) {
    final merged = <OfficialChargerMatch>[...realtime.matches];
    var duplicateCount = 0;
    for (final candidate in inventory.matches) {
      final duplicate = realtime.matches.any(
        (live) => _isLikelySameStation(live.station, candidate.station),
      );
      if (duplicate) {
        duplicateCount++;
      } else {
        merged.add(candidate);
      }
    }
    merged.sort((a, b) {
      if (a.exactPostcode != b.exactPostcode) return a.exactPostcode ? -1 : 1;
      return (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity);
    });

    return OfficialChargerSearchResult(
      source: '${realtime.source} + ${inventory.source}',
      sourceUrl: realtime.sourceUrl,
      asOf: realtime.asOf.isAfter(inventory.asOf)
          ? realtime.asOf
          : inventory.asOf,
      totalStationCount:
          math.max(realtime.totalStationCount, inventory.totalStationCount),
      radiusKm: realtime.radiusKm,
      matches: merged,
      isRealtime: true,
      statusMessage:
          'Combined ${realtime.matches.length} timestamped operator record${realtime.matches.length == 1 ? '' : 's'} with the dated ${inventory.source} inventory; $duplicateCount duplicate${duplicateCount == 1 ? '' : 's'} removed. Live labels appear only on fresh, operator-verified data. ${realtime.statusMessage ?? ''}',
    );
  }

  static bool _isLikelySameStation(
    OfficialChargerStation left,
    OfficialChargerStation right,
  ) {
    if (left.providerStationId != null &&
        left.providerStationId == right.providerStationId) {
      return true;
    }
    if (_distanceKm(
          left.latitude,
          left.longitude,
          right.latitude,
          right.longitude,
        ) >
        0.08) {
      return false;
    }
    final leftOperator = _normalize(left.operatorName);
    final rightOperator = _normalize(right.operatorName);
    final operatorsMatch = leftOperator.isNotEmpty &&
        rightOperator.isNotEmpty &&
        (leftOperator == rightOperator ||
            leftOperator.contains(rightOperator) ||
            rightOperator.contains(leftOperator));
    final leftAddress = _normalize(left.address);
    final rightAddress = _normalize(right.address);
    final addressesMatch = leftAddress.length >= 8 &&
        rightAddress.length >= 8 &&
        (leftAddress.contains(rightAddress) ||
            rightAddress.contains(leftAddress));
    return operatorsMatch || addressesMatch;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

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
