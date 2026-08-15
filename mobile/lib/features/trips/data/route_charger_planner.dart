import 'dart:math' as math;

import '../../../shared/models/place_suggestion.dart';
import '../../discovery/data/official_charger_station.dart';

class RouteChargerCandidate {
  const RouteChargerCandidate({
    required this.station,
    required this.distanceFromRouteKm,
    required this.routeProgress,
  });

  final OfficialChargerStation station;
  final double distanceFromRouteKm;
  final double routeProgress;

  String get stationId => station.feedbackStationId;
}

double estimatedRoadDistanceKm(
  PlaceSuggestion origin,
  PlaceSuggestion destination,
) {
  return math.max(
    1,
    straightLineDistanceKm(
          origin.latitude,
          origin.longitude,
          destination.latitude,
          destination.longitude,
        ) *
        1.22,
  );
}

double routeCorridorKm(double routeDistanceKm) {
  if (routeDistanceKm <= 50) return 4;
  if (routeDistanceKm <= 200) return 6;
  if (routeDistanceKm <= 600) return 10;
  return 15;
}

List<RouteChargerCandidate> chargersAlongRoute({
  required Iterable<OfficialChargerStation> stations,
  required PlaceSuggestion origin,
  required PlaceSuggestion destination,
  required double corridorKm,
}) {
  final latitudePadding = corridorKm / 110.574;
  final middleLatitude = (origin.latitude + destination.latitude) / 2;
  final longitudeScale = math.max(0.2, math.cos(_radians(middleLatitude)));
  final longitudePadding = corridorKm / (111.320 * longitudeScale);
  final minimumLatitude =
      math.min(origin.latitude, destination.latitude) - latitudePadding;
  final maximumLatitude =
      math.max(origin.latitude, destination.latitude) + latitudePadding;
  final minimumLongitude =
      math.min(origin.longitude, destination.longitude) - longitudePadding;
  final maximumLongitude =
      math.max(origin.longitude, destination.longitude) + longitudePadding;

  final byStationId = <String, RouteChargerCandidate>{};
  for (final station in stations) {
    if (station.latitude < minimumLatitude ||
        station.latitude > maximumLatitude ||
        station.longitude < minimumLongitude ||
        station.longitude > maximumLongitude) {
      continue;
    }
    final progress = routeProgress(
      station.latitude,
      station.longitude,
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    final distance = distanceFromRouteKm(
      station.latitude,
      station.longitude,
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    if (distance > corridorKm) continue;
    final candidate = RouteChargerCandidate(
      station: station,
      distanceFromRouteKm: distance,
      routeProgress: progress,
    );
    final existing = byStationId[candidate.stationId];
    if (existing == null ||
        candidate.distanceFromRouteKm < existing.distanceFromRouteKm) {
      byStationId[candidate.stationId] = candidate;
    }
  }

  final result = byStationId.values.toList(growable: false);
  result.sort((left, right) {
    final progress = left.routeProgress.compareTo(right.routeProgress);
    if (progress != 0) return progress;
    return left.distanceFromRouteKm.compareTo(right.distanceFromRouteKm);
  });
  return result;
}

List<String> selectChargingStops({
  required int stopCount,
  required List<RouteChargerCandidate> routeChargers,
}) {
  if (stopCount <= 0 || routeChargers.isEmpty) return const [];
  final selected = <String>[];
  for (var index = 0; index < stopCount; index++) {
    final targetProgress = (index + 1) / (stopCount + 1);
    final candidates = routeChargers
        .where((candidate) => !selected.contains(candidate.stationId))
        .toList()
      ..sort((left, right) {
        final leftLive = left.station.hasLiveAvailability &&
            (left.station.availableConnectors ?? 0) > 0;
        final rightLive = right.station.hasLiveAvailability &&
            (right.station.availableConnectors ?? 0) > 0;
        if (leftLive != rightLive) return leftLive ? -1 : 1;
        final leftScore = (left.routeProgress - targetProgress).abs() * 100 +
            left.distanceFromRouteKm;
        final rightScore = (right.routeProgress - targetProgress).abs() * 100 +
            right.distanceFromRouteKm;
        return leftScore.compareTo(rightScore);
      });
    if (candidates.isEmpty) break;
    selected.add(candidates.first.stationId);
  }
  return selected;
}

double routeProgress(
  double stationLatitude,
  double stationLongitude,
  double originLatitude,
  double originLongitude,
  double destinationLatitude,
  double destinationLongitude,
) {
  final latitudeScale = math.cos(
    _radians((originLatitude + destinationLatitude) / 2),
  );
  final routeX = (destinationLongitude - originLongitude) * latitudeScale;
  final routeY = destinationLatitude - originLatitude;
  final stationX = (stationLongitude - originLongitude) * latitudeScale;
  final stationY = stationLatitude - originLatitude;
  final routeLengthSquared = routeX * routeX + routeY * routeY;
  if (routeLengthSquared == 0) return 0;
  return ((stationX * routeX + stationY * routeY) / routeLengthSquared)
      .clamp(0.0, 1.0)
      .toDouble();
}

double distanceFromRouteKm(
  double stationLatitude,
  double stationLongitude,
  double originLatitude,
  double originLongitude,
  double destinationLatitude,
  double destinationLongitude,
) {
  final progress = routeProgress(
    stationLatitude,
    stationLongitude,
    originLatitude,
    originLongitude,
    destinationLatitude,
    destinationLongitude,
  );
  final nearestLatitude =
      originLatitude + (destinationLatitude - originLatitude) * progress;
  final nearestLongitude =
      originLongitude + (destinationLongitude - originLongitude) * progress;
  return straightLineDistanceKm(
    stationLatitude,
    stationLongitude,
    nearestLatitude,
    nearestLongitude,
  );
}

double straightLineDistanceKm(
  double originLatitudeDegrees,
  double originLongitudeDegrees,
  double destinationLatitudeDegrees,
  double destinationLongitudeDegrees,
) {
  const earthRadiusKm = 6371.0088;
  final latitudeDelta =
      _radians(destinationLatitudeDegrees - originLatitudeDegrees);
  final longitudeDelta =
      _radians(destinationLongitudeDegrees - originLongitudeDegrees);
  final originLatitude = _radians(originLatitudeDegrees);
  final destinationLatitude = _radians(destinationLatitudeDegrees);
  final a = math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(originLatitude) *
          math.cos(destinationLatitude) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;
