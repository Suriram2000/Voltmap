class ChargingStation {
  const ChargingStation({
    required this.id,
    required this.name,
    required this.network,
    required this.address,
    required this.postalCode,
    required this.distanceKm,
    required this.powerKw,
    required this.availableConnectors,
    required this.totalConnectors,
    required this.latitude,
    required this.longitude,
    required this.connectorTypes,
    required this.pricePerKwh,
    required this.rating,
    required this.amenities,
  });

  final String id;
  final String name;
  final String network;
  final String address;
  final String postalCode;
  final double distanceKm;
  final int powerKw;
  final int availableConnectors;
  final int totalConnectors;
  final double latitude;
  final double longitude;
  final List<String> connectorTypes;
  final double pricePerKwh;
  final double rating;
  final List<String> amenities;

  bool get available => availableConnectors > 0;
  bool get isFast => powerKw >= 100;
  String get formattedAddress => '$address, PIN $postalCode';
}
