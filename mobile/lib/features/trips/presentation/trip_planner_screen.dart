import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/place_suggestion.dart';
import '../../../shared/models/saved_trip.dart';
import '../../../shared/services/place_search_service.dart';
import '../../../shared/state/app_state.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';
import '../../discovery/data/sample_stations.dart';

class TripPlannerScreen extends ConsumerStatefulWidget {
  const TripPlannerScreen({
    super.key,
    this.searchService = const PlaceSearchService(),
  });

  final PlaceSearchService searchService;

  @override
  ConsumerState<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends ConsumerState<TripPlannerScreen> {
  final originController = TextEditingController(
    text: 'Hitech City, Hyderabad',
  );
  final destinationController = TextEditingController();
  PlaceSuggestion? originPlace = const PlaceSuggestion(
    primaryText: 'Hitech City',
    secondaryText: 'Hyderabad, Telangana, India',
    latitude: 17.4504,
    longitude: 78.3808,
    type: 'locality',
  );
  PlaceSuggestion? destinationPlace;
  double rangeKm = 325;
  _RoutePlan? route;

  @override
  void dispose() {
    originController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Planner')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text(
                'Plan an EV-ready route',
                style: Theme.of(
                  context,
                )
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Search real places across India, estimate range, and add charging stops from the demo network.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      LocationAutocompleteField(
                        controller: originController,
                        label: 'Starting point',
                        hint: 'Search any city, area, address, or PIN',
                        prefixIcon: Icons.my_location,
                        searchService: widget.searchService,
                        onSelected: (place) => originPlace = place,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      LocationAutocompleteField(
                        controller: destinationController,
                        label: 'Destination',
                        hint: 'Try “ban” for Bengaluru and more places',
                        prefixIcon: Icons.flag,
                        searchService: widget.searchService,
                        onSelected: (place) => destinationPlace = place,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _planRoute(),
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Icon(Icons.public_rounded, size: 16),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Type 2+ letters for India-wide city, locality, address, and PIN suggestions.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Icon(Icons.directions_car),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Usable vehicle range: ${rangeKm.round()} km'),
                                Slider(
                                  value: rangeKm,
                                  min: 120,
                                  max: 600,
                                  divisions: 24,
                                  label: '${rangeKm.round()} km',
                                  onChanged: (value) =>
                                      setState(() => rangeKm = value),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _planRoute,
                          icon: const Icon(Icons.route),
                          label: const Text('Plan route'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (route != null) ...[
                const SizedBox(height: 18),
                _RouteResult(
                  route: route!,
                  onSave: () => _saveRoute(appState),
                  onOpenDirections: _openLiveRoute,
                ),
              ],
              const SizedBox(height: 28),
              Row(
                children: [
                  Text(
                    'Saved trips',
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text('${appState.savedTrips.length}'),
                ],
              ),
              const SizedBox(height: 12),
              if (appState.savedTrips.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Row(
                      children: [
                        Icon(Icons.route_outlined),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Plan and save a route to see it here.'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final trip in appState.savedTrips) ...[
                  _SavedTripCard(
                    trip: trip,
                    onDelete: () => appState.removeTrip(trip.id),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }

  void _planRoute() {
    FocusScope.of(context).unfocus();
    final origin = originController.text.trim();
    final destination = destinationController.text.trim();
    if (origin.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter both a starting point and destination.'),
        ),
      );
      return;
    }

    final hasCoordinates = originPlace != null && destinationPlace != null;
    final distance = hasCoordinates
        ? _estimatedRoadDistance(originPlace!, destinationPlace!)
        : _fallbackDistance(origin, destination);
    final safeLegDistance = rangeKm * 0.72;
    final legCount = (distance / safeLegDistance).ceil();
    final stopCount = legCount > 1 ? legCount - 1 : 0;
    final stopIds = _selectChargingStops(
      stopCount: stopCount,
      origin: originPlace,
      destination: destinationPlace,
    );
    final driveMinutes = (distance / 65 * 60).round();
    final routeChargers = _chargersForRoute(
      origin: originPlace,
      destination: destinationPlace,
    );

    setState(() {
      route = _RoutePlan(
        origin: origin,
        destination: destination,
        distanceKm: distance,
        estimatedMinutes: driveMinutes + stopCount * 25,
        energyKwh: distance * 0.16,
        stopStationIds: stopIds,
        routeChargers: routeChargers,
        locationBased: hasCoordinates,
      );
    });
  }

  List<_RouteCharger> _chargersForRoute({
    required PlaceSuggestion? origin,
    required PlaceSuggestion? destination,
  }) {
    if (origin == null || destination == null) {
      return sampleStations
          .map((station) => _RouteCharger(stationId: station.id))
          .toList(growable: false);
    }

    final chargers = sampleStations.map((station) {
      return _RouteCharger(
        stationId: station.id,
        distanceFromRouteKm: _distanceFromRoute(
          station.latitude,
          station.longitude,
          origin.latitude,
          origin.longitude,
          destination.latitude,
          destination.longitude,
        ),
      );
    }).toList();
    chargers.sort((left, right) =>
        left.distanceFromRouteKm!.compareTo(right.distanceFromRouteKm!));
    return chargers;
  }

  double _distanceFromRoute(
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
    final fraction = routeLengthSquared == 0
        ? 0.0
        : ((stationX * routeX + stationY * routeY) / routeLengthSquared)
            .clamp(0.0, 1.0)
            .toDouble();
    final nearestLatitude =
        originLatitude + (destinationLatitude - originLatitude) * fraction;
    final nearestLongitude =
        originLongitude + (destinationLongitude - originLongitude) * fraction;
    return _straightLineDistance(
      stationLatitude,
      stationLongitude,
      nearestLatitude,
      nearestLongitude,
    );
  }

  double _fallbackDistance(String origin, String destination) {
    final seed = origin.codeUnits.fold<int>(0, (sum, unit) => sum + unit) +
        destination.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return 70.0 + (seed % 420);
  }

  double _estimatedRoadDistance(
    PlaceSuggestion origin,
    PlaceSuggestion destination,
  ) {
    return math.max(
      1,
      _straightLineDistance(
            origin.latitude,
            origin.longitude,
            destination.latitude,
            destination.longitude,
          ) *
          1.22,
    );
  }

  List<String> _selectChargingStops({
    required int stopCount,
    required PlaceSuggestion? origin,
    required PlaceSuggestion? destination,
  }) {
    if (stopCount == 0) return const [];
    final availableStations =
        sampleStations.where((station) => station.available).toList();
    if (origin == null || destination == null) {
      return List<String>.generate(
        stopCount,
        (index) => availableStations[index % availableStations.length].id,
      );
    }

    final selected = <String>[];
    for (var index = 0; index < stopCount; index++) {
      final fraction = (index + 1) / (stopCount + 1);
      final targetLatitude =
          origin.latitude + (destination.latitude - origin.latitude) * fraction;
      final targetLongitude = origin.longitude +
          (destination.longitude - origin.longitude) * fraction;
      final candidates = availableStations
          .where((station) => !selected.contains(station.id))
          .toList()
        ..sort((left, right) {
          final leftDistance = _straightLineDistance(
            targetLatitude,
            targetLongitude,
            left.latitude,
            left.longitude,
          );
          final rightDistance = _straightLineDistance(
            targetLatitude,
            targetLongitude,
            right.latitude,
            right.longitude,
          );
          return leftDistance.compareTo(rightDistance);
        });
      selected.add(
          (candidates.isEmpty ? availableStations.first : candidates.first).id);
    }
    return selected;
  }

  double _straightLineDistance(
    double originLatitudeDegrees,
    double originLongitudeDegrees,
    double destinationLatitudeDegrees,
    double destinationLongitudeDegrees,
  ) {
    const earthRadiusKm = 6371.0;
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

  Future<void> _openLiveRoute() async {
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': originController.text.trim(),
      'destination': destinationController.text.trim(),
      'travelmode': 'driving',
    });
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open live directions.')),
      );
    }
  }

  void _saveRoute(AppState appState) {
    final current = route!;
    final trip = SavedTrip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      origin: current.origin,
      destination: current.destination,
      distanceKm: current.distanceKm,
      estimatedMinutes: current.estimatedMinutes,
      stopStationIds: current.stopStationIds,
      createdAt: DateTime.now(),
    );
    appState.saveTrip(trip);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trip saved on this device.')));
  }
}

class _RouteResult extends StatelessWidget {
  const _RouteResult({
    required this.route,
    required this.onSave,
    required this.onOpenDirections,
  });

  final _RoutePlan route;
  final VoidCallback onSave;
  final VoidCallback onOpenDirections;

  @override
  Widget build(BuildContext context) {
    final hours = route.estimatedMinutes ~/ 60;
    final minutes = route.estimatedMinutes % 60;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.route)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${route.origin} → ${route.destination}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${route.distanceKm.toStringAsFixed(0)} km • ${hours}h ${minutes}m',
                      ),
                      Text(
                        route.locationBased
                            ? 'Coordinate-based road estimate'
                            : 'Demo estimate — select a search suggestion for location-based results',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Save trip',
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
              ],
            ),
            const Divider(height: 28),
            Text('Estimated energy: ${route.energyKwh.toStringAsFixed(1)} kWh'),
            const SizedBox(height: 12),
            if (route.stopStationIds.isEmpty)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle),
                title: Text('No charging stop needed'),
                subtitle: Text(
                  'This route fits within the selected safe range.',
                ),
              )
            else ...[
              Text(
                '${route.stopStationIds.length} recommended charging stop${route.stopStationIds.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              for (var index = 0; index < route.stopStationIds.length; index++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(
                    stationById(route.stopStationIds[index])?.name ??
                        'Charging stop',
                  ),
                  subtitle: Text(
                    route.locationBased
                        ? 'Nearest available demo charger to this route segment'
                        : 'Suggested 25 minute demo charging break',
                  ),
                ),
            ],
            const Divider(height: 30),
            Text(
              'All chargers for this route (${route.routeChargers.length})',
              key: const Key('allRouteChargersHeading'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              route.locationBased
                  ? 'All demo chargers, ordered by distance from the planned route.'
                  : 'All demo chargers. Select origin and destination suggestions to order them by route proximity.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final routeCharger in route.routeChargers)
              _RouteChargerTile(
                routeCharger: routeCharger,
                recommended: route.stopStationIds.contains(
                  routeCharger.stationId,
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save this trip'),
                ),
                FilledButton.icon(
                  key: const Key('openLiveDirectionsButton'),
                  onPressed: onOpenDirections,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open live directions'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedTripCard extends StatelessWidget {
  const _SavedTripCard({required this.trip, required this.onDelete});

  final SavedTrip trip;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.route)),
        title: Text('${trip.origin} → ${trip.destination}'),
        subtitle: Text(
          '${trip.distanceKm.toStringAsFixed(0)} km • ${trip.stopStationIds.length} charging stops',
        ),
        trailing: IconButton(
          tooltip: 'Delete saved trip',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

class _RouteChargerTile extends StatelessWidget {
  const _RouteChargerTile({
    required this.routeCharger,
    required this.recommended,
  });

  final _RouteCharger routeCharger;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final station = stationById(routeCharger.stationId)!;
    final statusColor = station.available
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return ListTile(
      key: Key('routeCharger_${station.id}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        station.available ? Icons.ev_station_rounded : Icons.block_rounded,
        color: statusColor,
      ),
      title: Text(station.name),
      subtitle: Text(
        '${station.formattedAddress}\n'
        '${station.powerKw} kW • ${station.connectorTypes.join(', ')}'
        '${routeCharger.distanceFromRouteKm == null ? '' : ' • ${routeCharger.distanceFromRouteKm!.toStringAsFixed(0)} km from route'}',
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            station.available ? 'AVAILABLE' : 'UNAVAILABLE',
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (recommended)
            const Text(
              'RECOMMENDED',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

class _RoutePlan {
  const _RoutePlan({
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.energyKwh,
    required this.stopStationIds,
    required this.routeChargers,
    required this.locationBased,
  });

  final String origin;
  final String destination;
  final double distanceKm;
  final int estimatedMinutes;
  final double energyKwh;
  final List<String> stopStationIds;
  final List<_RouteCharger> routeChargers;
  final bool locationBased;
}

class _RouteCharger {
  const _RouteCharger({
    required this.stationId,
    this.distanceFromRouteKm,
  });

  final String stationId;
  final double? distanceFromRouteKm;
}
