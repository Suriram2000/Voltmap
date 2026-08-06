import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/saved_trip.dart';
import '../../../shared/state/app_state.dart';
import '../../discovery/data/sample_stations.dart';

class TripPlannerScreen extends ConsumerStatefulWidget {
  const TripPlannerScreen({super.key});

  @override
  ConsumerState<TripPlannerScreen> createState() => _TripPlannerScreenState();
}

class _TripPlannerScreenState extends ConsumerState<TripPlannerScreen> {
  final originController = TextEditingController(text: 'Hitech City, Hyderabad');
  final destinationController = TextEditingController();
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            'Plan an EV-ready route',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'VoltMap estimates range and adds available charging stops using the demo network.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  TextField(
                    controller: originController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Starting point',
                      prefixIcon: Icon(Icons.my_location),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: destinationController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _planRoute(),
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      hintText: 'For example: Vijayawada',
                      prefixIcon: Icon(Icons.flag),
                    ),
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
                            Text('Usable vehicle range: ${rangeKm.round()} km'),
                            Slider(
                              value: rangeKm,
                              min: 120,
                              max: 600,
                              divisions: 24,
                              label: '${rangeKm.round()} km',
                              onChanged: (value) => setState(() => rangeKm = value),
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
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Text(
                'Saved trips',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
                    Expanded(child: Text('Plan and save a route to see it here.')),
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
    );
  }

  void _planRoute() {
    final origin = originController.text.trim();
    final destination = destinationController.text.trim();
    if (origin.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter both a starting point and destination.')),
      );
      return;
    }

    final seed = origin.codeUnits.fold<int>(0, (sum, unit) => sum + unit) +
        destination.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    final distance = 70.0 + (seed % 420);
    final safeLegDistance = rangeKm * 0.72;
    final legCount = (distance / safeLegDistance).ceil();
    final stopCount = legCount > 1 ? legCount - 1 : 0;
    final availableStations = sampleStations.where((station) => station.available).toList();
    final stopIds = List<String>.generate(
      stopCount,
      (index) => availableStations[index % availableStations.length].id,
    );
    final driveMinutes = (distance / 65 * 60).round();

    setState(() {
      route = _RoutePlan(
        origin: origin,
        destination: destination,
        distanceKm: distance,
        estimatedMinutes: driveMinutes + stopCount * 25,
        energyKwh: distance * 0.16,
        stopStationIds: stopIds,
      );
    });
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trip saved on this device.')),
    );
  }
}

class _RouteResult extends StatelessWidget {
  const _RouteResult({required this.route, required this.onSave});

  final _RoutePlan route;
  final VoidCallback onSave;

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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text('${route.distanceKm.toStringAsFixed(0)} km • ${hours}h ${minutes}m'),
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
                subtitle: Text('This route fits within the selected safe range.'),
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
                  title: Text(stationById(route.stopStationIds[index])?.name ?? 'Charging stop'),
                  subtitle: const Text('Suggested 25 minute charging break'),
                ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save this trip'),
              ),
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

class _RoutePlan {
  const _RoutePlan({
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.energyKwh,
    required this.stopStationIds,
  });

  final String origin;
  final String destination;
  final double distanceKm;
  final int estimatedMinutes;
  final double energyKwh;
  final List<String> stopStationIds;
}
