import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../shared/models/place_suggestion.dart';
import 'official_charger_station.dart';

const officialChargerManifestAsset = 'assets/data/bee/manifest.json';

class OfficialChargerSearchService {
  const OfficialChargerSearchService();

  static const _maximumCachedSearches = 8;
  static Future<_OfficialChargerManifest>? _cachedManifest;
  static final Map<String, Future<List<OfficialChargerStation>>>
      _cachedStateStations = {};
  static final Map<String, Future<OfficialChargerSearchResult>>
      _cachedSearchResults = {};
  static Future<List<OfficialChargerStation>>? _cachedAllStations;

  /// Loads the deduplicated national inventory once for route-corridor
  /// planning. State assets remain independently cached for normal searches.
  Future<List<OfficialChargerStation>> loadAllStations() {
    return _cachedAllStations ??= _loadAllStations();
  }

  Future<OfficialChargerSearchResult> search({
    required String query,
    PlaceSuggestion? center,
  }) async {
    final cacheKey = '${_normalize(query)}|${center?.identity ?? ''}|'
        '${center?.type ?? ''}|${_normalize(center?.secondaryText ?? '')}';
    final cached = _cachedSearchResults.remove(cacheKey);
    if (cached != null) {
      _cachedSearchResults[cacheKey] = cached;
      return cached;
    }

    final request = _searchUncached(query: query, center: center);
    _cachedSearchResults[cacheKey] = request;
    while (_cachedSearchResults.length > _maximumCachedSearches) {
      _cachedSearchResults.remove(_cachedSearchResults.keys.first);
    }
    try {
      return await request;
    } catch (_) {
      if (identical(_cachedSearchResults[cacheKey], request)) {
        _cachedSearchResults.remove(cacheKey);
      }
      rethrow;
    }
  }

  Future<OfficialChargerSearchResult> _searchUncached({
    required String query,
    PlaceSuggestion? center,
  }) async {
    final manifest = await (_cachedManifest ??= _loadManifest());
    final selectedAssets = _selectStateAssets(
      manifest: manifest,
      query: query,
      center: center,
    );
    final stationGroups = await Future.wait(
      selectedAssets.map(_loadStateStations),
    );
    final index = OfficialChargerIndex(
      source: manifest.source,
      sourceUrl: manifest.sourceUrl,
      asOf: manifest.asOf,
      totalStationCount: manifest.stationCount,
      stations: stationGroups.expand((stations) => stations).toList(
            growable: false,
          ),
    );
    return searchOfficialChargers(index: index, query: query, center: center);
  }

  static Future<_OfficialChargerManifest> _loadManifest() async {
    final source = await rootBundle.loadString(officialChargerManifestAsset);
    return compute(_parseManifest, source);
  }

  static Future<List<OfficialChargerStation>> _loadAllStations() async {
    final manifest = await (_cachedManifest ??= _loadManifest());
    final sources = await Future.wait(
      manifest.states.map((state) => rootBundle.loadString(state.asset)),
    );
    return List<OfficialChargerStation>.unmodifiable(
      await compute(_parseAllStationLists, sources),
    );
  }

  static Future<List<OfficialChargerStation>> _loadStateStations(
    String asset,
  ) {
    return _cachedStateStations.putIfAbsent(asset, () async {
      final source = await rootBundle.loadString(asset);
      return compute(_parseStationList, source);
    });
  }
}

List<OfficialChargerStation> _parseAllStationLists(List<String> sources) {
  return sources.expand(_parseStationList).toList(growable: false);
}

List<String> _selectStateAssets({
  required _OfficialChargerManifest manifest,
  required String query,
  PlaceSuggestion? center,
}) {
  final locationText = _normalize(
    '$query ${center?.primaryText ?? ''} ${center?.secondaryText ?? ''}',
  );
  final matches = manifest.states
      .where((state) => locationText.contains(_normalize(state.name)))
      .map((state) => state.asset)
      .toList(growable: false);
  if (matches.isNotEmpty) return matches;

  // Remote place suggestions normally include a state in their address. If a
  // provider omits it, search all state files rather than silently hiding data.
  return manifest.states.map((state) => state.asset).toList(growable: false);
}

@visibleForTesting
OfficialChargerSearchResult searchOfficialChargers({
  required OfficialChargerIndex index,
  required String query,
  PlaceSuggestion? center,
}) {
  final postcode =
      RegExp(r'(?<!\d)([1-9]\d{5})(?!\d)').firstMatch(query)?.group(1);
  final radiusKm = center?.type == 'postcode' ? 15.0 : 25.0;
  final normalizedQuery = _normalize(query);
  final matches = <OfficialChargerMatch>[];

  for (final station in index.stations) {
    final exactPostcode =
        postcode != null && station.postcodes.contains(postcode);
    final distanceKm = center == null
        ? null
        : distanceBetweenKm(
            center.latitude,
            center.longitude,
            station.latitude,
            station.longitude,
          );
    final textMatch = normalizedQuery.isNotEmpty &&
        _normalize(
          '${station.operatorName} ${station.address} ${station.city} '
          '${station.district} ${station.state} ${station.postcodes.join(' ')}',
        ).contains(normalizedQuery);

    if (exactPostcode ||
        (distanceKm != null && distanceKm <= radiusKm) ||
        (center == null && textMatch)) {
      matches.add(
        OfficialChargerMatch(
          station: station,
          distanceKm: distanceKm,
          exactPostcode: exactPostcode,
        ),
      );
    }
  }

  matches.sort((left, right) {
    if (left.exactPostcode != right.exactPostcode) {
      return left.exactPostcode ? -1 : 1;
    }
    final distanceComparison = (left.distanceKm ?? double.infinity)
        .compareTo(right.distanceKm ?? double.infinity);
    if (distanceComparison != 0) return distanceComparison;
    return left.station.displayName.compareTo(right.station.displayName);
  });

  return OfficialChargerSearchResult(
    source: index.source,
    sourceUrl: index.sourceUrl,
    asOf: index.asOf,
    totalStationCount: index.totalStationCount,
    radiusKm: radiusKm,
    matches: matches,
  );
}

@visibleForTesting
double distanceBetweenKm(
  double latitudeA,
  double longitudeA,
  double latitudeB,
  double longitudeB,
) {
  const earthRadiusKm = 6371.0088;
  final latitudeDelta = _radians(latitudeB - latitudeA);
  final longitudeDelta = _radians(longitudeB - longitudeA);
  final a = math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(_radians(latitudeA)) *
          math.cos(_radians(latitudeB)) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

_OfficialChargerManifest _parseManifest(String source) {
  final json = jsonDecode(source) as Map<String, dynamic>;
  return _OfficialChargerManifest(
    source: json['source'] as String,
    sourceUrl: json['sourceUrl'] as String,
    asOf: DateTime.parse(json['asOf'] as String),
    stationCount: (json['stationCount'] as num).toInt(),
    states: (json['states'] as List<dynamic>)
        .map(
          (value) => _OfficialStateAsset.fromJson(
            value as Map<String, dynamic>,
          ),
        )
        .toList(growable: false),
  );
}

List<OfficialChargerStation> _parseStationList(String source) {
  final json = jsonDecode(source) as Map<String, dynamic>;
  return (json['stations'] as List<dynamic>)
      .map(
        (value) => OfficialChargerStation.fromCompactJson(
          value as Map<String, dynamic>,
        ),
      )
      .toList(growable: false);
}

@visibleForTesting
class OfficialChargerIndex {
  const OfficialChargerIndex({
    required this.source,
    required this.sourceUrl,
    required this.asOf,
    required this.totalStationCount,
    required this.stations,
  });

  final String source;
  final String sourceUrl;
  final DateTime asOf;
  final int totalStationCount;
  final List<OfficialChargerStation> stations;
}

class _OfficialChargerManifest {
  const _OfficialChargerManifest({
    required this.source,
    required this.sourceUrl,
    required this.asOf,
    required this.stationCount,
    required this.states,
  });

  final String source;
  final String sourceUrl;
  final DateTime asOf;
  final int stationCount;
  final List<_OfficialStateAsset> states;
}

class _OfficialStateAsset {
  const _OfficialStateAsset({required this.name, required this.asset});

  factory _OfficialStateAsset.fromJson(Map<String, dynamic> json) {
    return _OfficialStateAsset(
      name: json['name'] as String,
      asset: json['asset'] as String,
    );
  }

  final String name;
  final String asset;
}
