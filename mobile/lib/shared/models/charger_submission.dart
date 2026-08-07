class ChargerSubmission {
  const ChargerSubmission({
    required this.id,
    required this.stationName,
    required this.operatorName,
    required this.address,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.connectorTypes,
    required this.reportedStatus,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String stationName;
  final String operatorName;
  final String address;
  final String city;
  final String state;
  final String postalCode;
  final List<String> connectorTypes;
  final String reportedStatus;
  final String notes;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'stationName': stationName,
        'operatorName': operatorName,
        'address': address,
        'city': city,
        'state': state,
        'postalCode': postalCode,
        'connectorTypes': connectorTypes,
        'reportedStatus': reportedStatus,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChargerSubmission.fromJson(Map<String, dynamic> json) {
    return ChargerSubmission(
      id: json['id'] as String,
      stationName: json['stationName'] as String,
      operatorName: json['operatorName'] as String,
      address: json['address'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      postalCode: json['postalCode'] as String,
      connectorTypes: (json['connectorTypes'] as List<dynamic>)
          .whereType<String>()
          .toList(growable: false),
      reportedStatus: json['reportedStatus'] as String,
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  String get issueBody => '''
## Charger details

- **Station name:** $stationName
- **Operator/network:** $operatorName
- **Address:** $address
- **City:** $city
- **State:** $state
- **PIN code:** $postalCode
- **Connectors:** ${connectorTypes.join(', ')}
- **Reported status:** $reportedStatus

## Notes / verification evidence

${notes.isEmpty ? 'No additional notes supplied.' : notes}

---
Submitted from the VoltMap public charger-report form. Please verify this location before adding it to the catalog.
''';
}
