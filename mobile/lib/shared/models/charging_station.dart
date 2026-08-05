class ChargingStation {
  const ChargingStation({
    required this.id,
    required this.name,
    required this.network,
    required this.distanceKm,
    required this.powerKw,
    required this.availableConnectors,
    required this.totalConnectors,
  });

  final String id;
  final String name;
  final String network;
  final double distanceKm;
  final int powerKw;
  final int availableConnectors;
  final int totalConnectors;

  bool get available => availableConnectors > 0;
}
