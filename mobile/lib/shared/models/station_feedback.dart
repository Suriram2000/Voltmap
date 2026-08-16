enum StationFeedbackCategory {
  chargingExperience('Charging experience'),
  notWorking('Charger not working'),
  permanentlyClosed('Station closed or removed'),
  wrongLocation('Wrong map location'),
  wrongConnector('Wrong connector or charging speed'),
  wrongPrice('Wrong price or fee'),
  duplicate('Duplicate station'),
  missingDetails('Missing station details'),
  other('Other correction');

  const StationFeedbackCategory(this.label);

  final String label;
}

class StationFeedbackDraft {
  const StationFeedbackDraft({
    required this.feedbackId,
    required this.stationId,
    required this.stationName,
    required this.operatorName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.details,
    required this.observedAt,
    required this.createdAt,
    this.sourceNames = const [],
    this.contact = '',
  });

  final String feedbackId;
  final String stationId;
  final String stationName;
  final String operatorName;
  final String address;
  final double latitude;
  final double longitude;
  final StationFeedbackCategory category;
  final String details;
  final DateTime observedAt;
  final DateTime createdAt;
  final List<String> sourceNames;
  final String contact;

  Uri privateAdminEmailUri(String adminEmail) {
    return Uri(
      scheme: 'mailto',
      path: adminEmail.trim().toLowerCase(),
      queryParameters: {
        'subject': '[VoltMapEV private station feedback] $stationName',
        'body': '''
Private VoltMapEV station feedback

Feedback ID: $feedbackId
Category: ${category.label}
Observed: ${observedAt.toUtc().toIso8601String()}
Submitted: ${createdAt.toUtc().toIso8601String()}

Station ID: $stationId
Station: $stationName
Operator: $operatorName
Address: $address
Coordinates: $latitude, $longitude
Catalog sources: ${sourceNames.isEmpty ? 'Not published' : sourceNames.join(', ')}

Feedback / evidence:
$details

Optional reporter contact: ${contact.trim().isEmpty ? 'Not provided' : contact.trim()}

This report is addressed only to the VoltMapEV administrator. Verify it against an operator, government, or field source before changing public station data.
''',
      },
    );
  }
}
