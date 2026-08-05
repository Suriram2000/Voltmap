import '../../../shared/models/charging_station.dart';

const sampleStations = [
  ChargingStation(id: 'chargezone-1', name: 'ChargeZone Hitech City', network: 'ChargeZone', distanceKm: 0.8, powerKw: 120, availableConnectors: 2, totalConnectors: 4),
  ChargingStation(id: 'statiq-1', name: 'Statiq Jubilee Hills', network: 'Statiq', distanceKm: 1.7, powerKw: 60, availableConnectors: 0, totalConnectors: 2),
  ChargingStation(id: 'jiobp-1', name: 'Jio-bp Pulse', network: 'Jio-bp Pulse', distanceKm: 3.2, powerKw: 60, availableConnectors: 3, totalConnectors: 4),
];
