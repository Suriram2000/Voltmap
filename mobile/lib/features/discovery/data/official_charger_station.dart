class OfficialChargerStation {
  const OfficialChargerStation({
    required this.operatorName,
    required this.ownership,
    required this.state,
    required this.district,
    required this.city,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.postcodes,
    required this.connectors,
    this.providerStationId,
    this.availableConnectors,
    this.totalConnectors,
    this.pricePerKwh,
    this.currency = 'INR',
    this.liveStatusUpdatedAt,
    this.sourceNames = const [],
    this.operatorVerified = false,
    this.liveDataIsFresh = false,
  });

  factory OfficialChargerStation.fromCompactJson(Map<String, dynamic> json) {
    return OfficialChargerStation(
      operatorName: json['o'] as String? ?? 'Charging station',
      ownership: json['g'] as String? ?? '',
      state: json['s'] as String? ?? '',
      district: json['d'] as String? ?? '',
      city: json['c'] as String? ?? '',
      address: json['a'] as String? ?? '',
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      postcodes: (json['p'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      connectors: (json['ch'] as List<dynamic>? ?? const [])
          .map(
            (value) => OfficialChargerConnector.fromCompactJson(
              value as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      sourceNames: const ['BEE national inventory'],
    );
  }

  final String operatorName;
  final String ownership;
  final String state;
  final String district;
  final String city;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> postcodes;
  final List<OfficialChargerConnector> connectors;
  final String? providerStationId;
  final int? availableConnectors;
  final int? totalConnectors;
  final double? pricePerKwh;
  final String currency;
  final DateTime? liveStatusUpdatedAt;
  final List<String> sourceNames;
  final bool operatorVerified;
  final bool liveDataIsFresh;

  bool get hasLiveAvailability =>
      availableConnectors != null &&
      totalConnectors != null &&
      liveStatusUpdatedAt != null &&
      liveDataIsFresh;

  bool get hasLivePrice =>
      pricePerKwh != null && liveStatusUpdatedAt != null && liveDataIsFresh;

  String get feedbackStationId => providerStationId?.isNotEmpty == true
      ? providerStationId!
      : 'inventory:${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}:$operatorName';

  String get sourceLabel => sourceNames.isEmpty
      ? (operatorVerified ? 'Verified operator feed' : 'Published inventory')
      : sourceNames.toSet().join(' + ');

  String get displayName =>
      city.isEmpty ? operatorName : '$operatorName - $city';

  String get areaLabel => <String>[
        city,
        district,
        state,
      ].where((value) => value.isNotEmpty).toSet().join(', ');
}

class OfficialChargerConnector {
  const OfficialChargerConnector({
    required this.type,
    this.ratingKw,
    this.count,
  });

  factory OfficialChargerConnector.fromCompactJson(
    Map<String, dynamic> json,
  ) {
    return OfficialChargerConnector(
      type: json['t'] as String? ?? 'Connector',
      ratingKw: (json['kw'] as num?)?.toDouble(),
      count: (json['n'] as num?)?.toInt(),
    );
  }

  final String type;
  final double? ratingKw;
  final int? count;

  String get label {
    final details = <String>[];
    if (ratingKw != null) {
      final rating = ratingKw! % 1 == 0
          ? ratingKw!.toStringAsFixed(0)
          : ratingKw!.toStringAsFixed(1);
      details.add('$rating kW');
    }
    if (count != null) details.add('$count connector${count == 1 ? '' : 's'}');
    return details.isEmpty ? type : '$type - ${details.join(', ')}';
  }
}

class OfficialChargerMatch {
  const OfficialChargerMatch({
    required this.station,
    required this.distanceKm,
    required this.exactPostcode,
  });

  final OfficialChargerStation station;
  final double? distanceKm;
  final bool exactPostcode;
}

class OfficialChargerSearchResult {
  const OfficialChargerSearchResult({
    required this.source,
    required this.sourceUrl,
    required this.asOf,
    required this.totalStationCount,
    required this.radiusKm,
    required this.matches,
    this.isRealtime = false,
    this.statusMessage,
  });

  final String source;
  final String sourceUrl;
  final DateTime asOf;
  final int totalStationCount;
  final double radiusKm;
  final List<OfficialChargerMatch> matches;
  final bool isRealtime;
  final String? statusMessage;

  int get exactPostcodeCount =>
      matches.where((match) => match.exactPostcode).length;
}
