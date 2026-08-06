class SavedTrip {
  const SavedTrip({
    required this.id,
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.stopStationIds,
    required this.createdAt,
  });

  final String id;
  final String origin;
  final String destination;
  final double distanceKm;
  final int estimatedMinutes;
  final List<String> stopStationIds;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
        'id': id,
        'origin': origin,
        'destination': destination,
        'distanceKm': distanceKm,
        'estimatedMinutes': estimatedMinutes,
        'stopStationIds': stopStationIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedTrip.fromJson(Map<String, dynamic> json) => SavedTrip(
        id: json['id'] as String,
        origin: json['origin'] as String,
        destination: json['destination'] as String,
        distanceKm: (json['distanceKm'] as num).toDouble(),
        estimatedMinutes: json['estimatedMinutes'] as int,
        stopStationIds: List<String>.from(json['stopStationIds'] as List),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
