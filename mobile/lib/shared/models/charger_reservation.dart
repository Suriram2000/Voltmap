enum ChargerReservationStatus { requested, confirmed, cancelled, expired }

class ChargerReservation {
  const ChargerReservation({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.connectorType,
    required this.arrivalWindowStart,
    required this.arrivalWindowEnd,
    required this.createdAt,
    this.status = ChargerReservationStatus.requested,
  });

  final String id;
  final String stationId;
  final String stationName;
  final String connectorType;
  final DateTime arrivalWindowStart;
  final DateTime arrivalWindowEnd;
  final DateTime createdAt;
  final ChargerReservationStatus status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'stationId': stationId,
        'stationName': stationName,
        'connectorType': connectorType,
        'arrivalWindowStart': arrivalWindowStart.toIso8601String(),
        'arrivalWindowEnd': arrivalWindowEnd.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
      };

  factory ChargerReservation.fromJson(Map<String, dynamic> json) {
    final status = ChargerReservationStatus.values.where(
      (value) => value.name == json['status'],
    );
    return ChargerReservation(
      id: json['id'] as String,
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String,
      connectorType: json['connectorType'] as String,
      arrivalWindowStart: DateTime.parse(json['arrivalWindowStart'] as String),
      arrivalWindowEnd: DateTime.parse(json['arrivalWindowEnd'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: status.isEmpty ? ChargerReservationStatus.requested : status.first,
    );
  }

  ChargerReservation copyWith({ChargerReservationStatus? status}) =>
      ChargerReservation(
        id: id,
        stationId: stationId,
        stationName: stationName,
        connectorType: connectorType,
        arrivalWindowStart: arrivalWindowStart,
        arrivalWindowEnd: arrivalWindowEnd,
        createdAt: createdAt,
        status: status ?? this.status,
      );
}
