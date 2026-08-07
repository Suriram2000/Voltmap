import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place_suggestion.dart';

class PlaceSearchService {
  const PlaceSearchService();

  static final Map<String, List<PlaceSuggestion>> _cache = {};

  List<PlaceSuggestion> localSuggestions(String rawQuery) {
    final query = rawQuery.trim();
    if (query.length < 2) return const [];
    return _popularIndianPlaces
        .where((place) => place.matches(query))
        .take(8)
        .toList(growable: false);
  }

  Future<List<PlaceSuggestion>> searchIndia(String rawQuery) async {
    final query = rawQuery.trim();
    final local = localSuggestions(query);
    if (query.length < 3) return local;

    final cacheKey = query.toLowerCase();
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final url = Uri.https('photon.komoot.io', '/api/', {
        'q': query,
        'limit': '18',
        'lang': 'en',
        'bbox': '68.0,6.0,97.5,37.5',
      });
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return local;

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final features = payload['features'] as List<dynamic>? ?? const [];
      final remote = features
          .map(_parseFeature)
          .whereType<PlaceSuggestion>()
          .where((place) => place.secondaryText.contains('India'));

      final merged = <PlaceSuggestion>[];
      final identities = <String>{};
      for (final place in <PlaceSuggestion>[...local, ...remote]) {
        if (identities.add(place.identity)) merged.add(place);
        if (merged.length == 10) break;
      }
      final result = List<PlaceSuggestion>.unmodifiable(merged);
      if (_cache.length >= 50) _cache.remove(_cache.keys.first);
      _cache[cacheKey] = result;
      return result;
    } catch (_) {
      return local;
    }
  }

  Future<PlaceSuggestion?> reverseIndia({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final url = Uri.https('photon.komoot.io', '/reverse', {
        'lat': latitude.toStringAsFixed(6),
        'lon': longitude.toStringAsFixed(6),
        'lang': 'en',
      });
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final features = payload['features'] as List<dynamic>? ?? const [];
      for (final feature in features) {
        final place = _parseFeature(feature);
        if (place != null) return place;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  PlaceSuggestion? _parseFeature(dynamic rawFeature) {
    if (rawFeature is! Map<String, dynamic>) return null;
    final properties = rawFeature['properties'];
    final geometry = rawFeature['geometry'];
    if (properties is! Map<String, dynamic> ||
        geometry is! Map<String, dynamic>) {
      return null;
    }
    if ((properties['countrycode'] as String?)?.toUpperCase() != 'IN') {
      return null;
    }

    final coordinates = geometry['coordinates'];
    if (coordinates is! List<dynamic> || coordinates.length < 2) return null;
    final longitude = coordinates[0];
    final latitude = coordinates[1];
    if (longitude is! num || latitude is! num) return null;

    final name = _string(properties['name']);
    if (name == null) return null;
    final addressParts = <String?>[
      _joinStreet(
        _string(properties['housenumber']),
        _string(properties['street']),
      ),
      _string(properties['locality']),
      _string(properties['district']),
      _string(properties['city']),
      _string(properties['county']),
      _string(properties['state']),
      _string(properties['postcode']),
      'India',
    ];
    final seen = <String>{name.toLowerCase()};
    final secondary = addressParts
        .whereType<String>()
        .where((part) => part.isNotEmpty && seen.add(part.toLowerCase()))
        .join(', ');

    return PlaceSuggestion(
      primaryText: name,
      secondaryText: secondary,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      type: _string(properties['type']) ?? 'place',
    );
  }

  String? _string(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _joinStreet(String? houseNumber, String? street) {
    if (houseNumber == null) return street;
    if (street == null) return houseNumber;
    return '$houseNumber $street';
  }
}

const _popularIndianPlaces = <PlaceSuggestion>[
  PlaceSuggestion(
    primaryText: 'Karmanghat / Vaishalinagar - 500079',
    secondaryText: 'Saroornagar, South East Hyderabad, Telangana, India',
    latitude: 17.3366,
    longitude: 78.5349,
    type: 'postcode',
    aliases: ['500079', 'Jillellaguda', 'South Hyderabad'],
  ),
  PlaceSuggestion(
    primaryText: 'Bengaluru',
    secondaryText: 'Karnataka, India',
    latitude: 12.9716,
    longitude: 77.5946,
    type: 'city',
    aliases: ['Bangalore', 'BLR'],
  ),
  PlaceSuggestion(
    primaryText: 'Bandra',
    secondaryText: 'Mumbai, Maharashtra, India',
    latitude: 19.0596,
    longitude: 72.8295,
    type: 'locality',
  ),
  PlaceSuggestion(
    primaryText: 'Banjara Hills',
    secondaryText: 'Hyderabad, Telangana, India',
    latitude: 17.4138,
    longitude: 78.4398,
    type: 'locality',
  ),
  PlaceSuggestion(
    primaryText: 'Baner',
    secondaryText: 'Pune, Maharashtra, India',
    latitude: 18.559,
    longitude: 73.7868,
    type: 'locality',
  ),
  PlaceSuggestion(
    primaryText: 'Banaswadi',
    secondaryText: 'Bengaluru, Karnataka, India',
    latitude: 13.0143,
    longitude: 77.6519,
    type: 'locality',
  ),
  PlaceSuggestion(
    primaryText: 'Benson Town',
    secondaryText: 'Bengaluru, Karnataka, India',
    latitude: 13.0014,
    longitude: 77.6053,
    type: 'locality',
  ),
  PlaceSuggestion(
    primaryText: 'Benniganahalli',
    secondaryText: 'Bengaluru, Karnataka, India',
    latitude: 13.0055,
    longitude: 77.6626,
    type: 'locality',
  ),
  PlaceSuggestion(
    primaryText: 'Bannerghatta',
    secondaryText: 'Bengaluru, Karnataka, India',
    latitude: 12.8001,
    longitude: 77.5774,
    type: 'locality',
  ),
  PlaceSuggestion(
    primaryText: 'Hyderabad',
    secondaryText: 'Telangana, India',
    latitude: 17.385,
    longitude: 78.4867,
    type: 'city',
    aliases: ['Secunderabad', 'HYD'],
  ),
  PlaceSuggestion(
    primaryText: 'Mumbai',
    secondaryText: 'Maharashtra, India',
    latitude: 19.076,
    longitude: 72.8777,
    type: 'city',
    aliases: ['Bombay'],
  ),
  PlaceSuggestion(
    primaryText: 'New Delhi',
    secondaryText: 'Delhi, India',
    latitude: 28.6139,
    longitude: 77.209,
    type: 'city',
    aliases: ['Delhi', 'NCR'],
  ),
  PlaceSuggestion(
    primaryText: 'Chennai',
    secondaryText: 'Tamil Nadu, India',
    latitude: 13.0827,
    longitude: 80.2707,
    type: 'city',
    aliases: ['Madras'],
  ),
  PlaceSuggestion(
    primaryText: 'Kolkata',
    secondaryText: 'West Bengal, India',
    latitude: 22.5726,
    longitude: 88.3639,
    type: 'city',
    aliases: ['Calcutta'],
  ),
  PlaceSuggestion(
    primaryText: 'Pune',
    secondaryText: 'Maharashtra, India',
    latitude: 18.5204,
    longitude: 73.8567,
    type: 'city',
    aliases: ['Poona'],
  ),
  PlaceSuggestion(
    primaryText: 'Ahmedabad',
    secondaryText: 'Gujarat, India',
    latitude: 23.0225,
    longitude: 72.5714,
    type: 'city',
    aliases: ['Amdavad'],
  ),
  PlaceSuggestion(
    primaryText: 'Vijayawada',
    secondaryText: 'Andhra Pradesh, India',
    latitude: 16.5062,
    longitude: 80.648,
    type: 'city',
    aliases: ['Bezawada'],
  ),
  PlaceSuggestion(
    primaryText: 'Visakhapatnam',
    secondaryText: 'Andhra Pradesh, India',
    latitude: 17.6868,
    longitude: 83.2185,
    type: 'city',
    aliases: ['Vizag'],
  ),
  PlaceSuggestion(
    primaryText: 'Kochi',
    secondaryText: 'Kerala, India',
    latitude: 9.9312,
    longitude: 76.2673,
    type: 'city',
    aliases: ['Cochin'],
  ),
];
