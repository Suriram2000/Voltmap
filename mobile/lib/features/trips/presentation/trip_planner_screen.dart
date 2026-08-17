import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/place_suggestion.dart';
import '../../../shared/models/saved_trip.dart';
import '../../../shared/services/place_search_service.dart';
import '../../../shared/state/app_state.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';
import '../../../shared/widgets/registered_account_gate.dart';
import '../../discovery/data/official_charger_search_service.dart';
import '../../discovery/data/official_charger_station.dart';
import '../../discovery/presentation/official_charger_details_screen.dart';
import '../data/route_charger_planner.dart';

class TripPlannerScreen extends ConsumerStatefulWidget {
  const TripPlannerScreen({
    super.key,
    this.searchService = const PlaceSearchService(),
    this.chargerDataService = const OfficialChargerSearchService(),
  });

  final PlaceSearchService searchService;
  final OfficialChargerSearchService chargerDataService;

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
  bool _planning = false;
  Timer? _autoPlanDebounce;
  int _routeRequestId = 0;
  String? _routeInputError;

  @override
  void dispose() {
    _autoPlanDebounce?.cancel();
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
                'Search real places across India, estimate range, and find every published national-inventory charger near the route.',
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
                        shouldHideSuggestions: _shouldHideRoutePinSuggestions,
                        onSelected: (place) {
                          originPlace = place;
                          if (place != null) {
                            _scheduleAutoPlan(immediate: true);
                          }
                        },
                        onChanged: (_) {
                          originPlace = null;
                          _scheduleAutoPlan();
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      LocationAutocompleteField(
                        controller: destinationController,
                        label: 'Destination',
                        hint: 'Try “ban” for Bengaluru and more places',
                        prefixIcon: Icons.flag,
                        searchService: widget.searchService,
                        shouldHideSuggestions: _shouldHideRoutePinSuggestions,
                        onSelected: (place) {
                          destinationPlace = place;
                          if (place != null) {
                            _scheduleAutoPlan(immediate: true);
                          }
                        },
                        onChanged: (_) {
                          destinationPlace = null;
                          _scheduleAutoPlan();
                        },
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
                              'Route data updates automatically after both locations are typed. PIN, city, locality, and address searches are supported.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      if (_routeInputError != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          key: const Key('autoRouteInputError'),
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _routeInputError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
                                  onChangeEnd: (_) =>
                                      _scheduleAutoPlan(immediate: true),
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
                          onPressed: _planning ? null : _planRoute,
                          icon: _planning
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.route),
                          label: Text(
                            _planning
                                ? 'Finding route chargers…'
                                : 'Plan route',
                          ),
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
              if (appState.isRegisteredAccount) ...[
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
                            child:
                                Text('Plan and save a route to see it here.'),
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
              ] else
                const Card(
                  key: Key('publicTripPlannerNotice'),
                  child: ListTile(
                    leading: Icon(Icons.lock_open_rounded),
                    title: Text('Trip planning is public'),
                    subtitle: Text(
                      'Plan and inspect routes without an account. Signup is requested only when you save a trip.',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _scheduleAutoPlan({bool immediate = false}) {
    _autoPlanDebounce?.cancel();
    final requestId = ++_routeRequestId;
    final origin = originController.text.trim();
    final destination = destinationController.text.trim();
    final ready = origin.length >= 3 && destination.length >= 3;
    setState(() {
      _planning = ready;
      _routeInputError = null;
      route = null;
    });
    if (!ready) return;

    final pinInput = RegExp(r'^\d{5,6}$').hasMatch(origin) ||
        RegExp(r'^\d{5,6}$').hasMatch(destination);
    _autoPlanDebounce = Timer(
      Duration(milliseconds: immediate ? 40 : (pinInput ? 180 : 500)),
      () => _planRoute(
        showValidation: false,
        requestId: requestId,
      ),
    );
  }

  Future<void> _planRoute({
    bool showValidation = true,
    int? requestId,
  }) async {
    _autoPlanDebounce?.cancel();
    if (showValidation) FocusScope.of(context).unfocus();
    final activeRequestId = requestId ?? ++_routeRequestId;
    final origin = originController.text.trim();
    final destination = destinationController.text.trim();
    if (origin.isEmpty || destination.isEmpty) {
      if (mounted) setState(() => _planning = false);
      if (showValidation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter both a starting point and destination.'),
          ),
        );
      }
      return;
    }

    if (requestId == null) {
      setState(() {
        _planning = true;
        _routeInputError = null;
      });
    }
    final resolvedOrigin = await _resolvePlace(origin, originPlace);
    final resolvedDestination =
        await _resolvePlace(destination, destinationPlace);
    if (!mounted || activeRequestId != _routeRequestId) return;
    final hasCoordinates =
        resolvedOrigin != null && resolvedDestination != null;
    if (!hasCoordinates) {
      const message =
          'Enter a valid India PIN, city, area, or address for both route fields.';
      setState(() {
        _planning = false;
        _routeInputError = message;
        route = null;
      });
      if (showValidation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(message)),
        );
      }
      return;
    }
    originPlace = resolvedOrigin;
    destinationPlace = resolvedDestination;
    final distance =
        estimatedRoadDistanceKm(resolvedOrigin, resolvedDestination);
    final safeLegDistance = rangeKm * 0.72;
    final legCount = (distance / safeLegDistance).ceil();
    final stopCount = legCount > 1 ? legCount - 1 : 0;
    final corridorKm = routeCorridorKm(distance);
    List<RouteChargerCandidate> routeChargers;
    String? chargerDataError;
    try {
      final nationalStations =
          await widget.chargerDataService.loadAllStations();
      routeChargers = chargersAlongRoute(
        stations: nationalStations,
        origin: resolvedOrigin,
        destination: resolvedDestination,
        corridorKm: corridorKm,
      );
    } catch (_) {
      routeChargers = const [];
      chargerDataError =
          'The national charger inventory could not be loaded. Retry before travelling.';
    }
    if (!mounted || activeRequestId != _routeRequestId) return;
    final stopIds = selectChargingStops(
      stopCount: stopCount,
      routeChargers: routeChargers,
    );
    final averageSpeedKmh = distance <= 50
        ? 35.0
        : distance <= 200
            ? 50.0
            : 65.0;
    final driveMinutes = (distance / averageSpeedKmh * 60).round();

    setState(() {
      _planning = false;
      _routeInputError = null;
      route = _RoutePlan(
        origin: resolvedOrigin.primaryText,
        destination: resolvedDestination.primaryText,
        distanceKm: distance,
        estimatedMinutes: driveMinutes + stopIds.length * 25,
        energyKwh: distance * 0.16,
        stopStationIds: stopIds,
        requiredStopCount: stopCount,
        routeChargers: routeChargers,
        corridorKm: corridorKm,
        locationBased: true,
        chargerDataError: chargerDataError,
      );
    });
  }

  Future<PlaceSuggestion?> _resolvePlace(
    String input,
    PlaceSuggestion? selected,
  ) async {
    final lookupInput = _expandedPinLookup(input);
    final normalizedInput = _normalizePlace(lookupInput);
    if (selected != null) {
      final selectedText = _normalizePlace(selected.displayName);
      if (selectedText.contains(normalizedInput) ||
          normalizedInput.contains(_normalizePlace(selected.primaryText))) {
        return selected;
      }
    }
    final postcode =
        RegExp(r'(?<!\d)([1-9]\d{5})(?!\d)').firstMatch(lookupInput)?.group(1);
    if (postcode != null) {
      final localSuggestions = widget.searchService.localSuggestions(postcode);
      for (final suggestion in localSuggestions) {
        if (suggestion.displayName.contains(postcode)) return suggestion;
      }
    }

    final suggestions = await widget.searchService.searchIndia(lookupInput);
    if (suggestions.isEmpty) return null;
    if (postcode != null) {
      for (final suggestion in suggestions) {
        if (suggestion.displayName.contains(postcode)) return suggestion;
      }
    }
    for (final suggestion in suggestions) {
      if (_normalizePlace(suggestion.primaryText) == normalizedInput) {
        return suggestion;
      }
    }
    return suggestions.first;
  }

  String _expandedPinLookup(String input) {
    final trimmed = input.trim();
    if (!RegExp(r'^\d{5}$').hasMatch(trimmed)) return trimmed;

    final matches = <String>{};
    for (var index = 0; index <= trimmed.length; index++) {
      final candidate =
          '${trimmed.substring(0, index)}0${trimmed.substring(index)}';
      final hasExactLocalPin = widget.searchService
          .localSuggestions(candidate)
          .any((place) => place.displayName.contains(candidate));
      if (hasExactLocalPin) matches.add(candidate);
    }
    return matches.length == 1 ? matches.single : trimmed;
  }

  bool _shouldHideRoutePinSuggestions(String input) {
    final lookup = _expandedPinLookup(input);
    if (lookup != input.trim()) return true;
    if (!RegExp(r'^[1-9]\d{5}$').hasMatch(lookup)) return false;
    return widget.searchService
        .localSuggestions(lookup)
        .any((place) => place.displayName.contains(lookup));
  }

  String _normalizePlace(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

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

  Future<void> _saveRoute(AppState appState) async {
    final messenger = ScaffoldMessenger.of(context);
    final canSave =
        await requireRegisteredAccount(context, appState, 'Saved trips');
    if (!mounted || !canSave) return;
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
    await appState.saveTrip(trip);
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Trip saved on this device.')),
    );
  }
}

class _RouteResult extends StatefulWidget {
  const _RouteResult({
    required this.route,
    required this.onSave,
    required this.onOpenDirections,
  });

  final _RoutePlan route;
  final VoidCallback onSave;
  final VoidCallback onOpenDirections;

  @override
  State<_RouteResult> createState() => _RouteResultState();
}

class _RouteResultState extends State<_RouteResult> {
  static const _initialChargerCount = 25;
  bool _showAllChargers = false;

  @override
  void didUpdateWidget(covariant _RouteResult oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.route, widget.route)) {
      _showAllChargers = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final visibleChargers = _showAllChargers
        ? route.routeChargers
        : route.routeChargers.take(_initialChargerCount);
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
                            ? 'Coordinate-based road estimate • charger corridor uses the national inventory'
                            : 'Select a search suggestion for location-based results',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Save trip',
                  onPressed: widget.onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                ),
              ],
            ),
            const Divider(height: 28),
            Text('Estimated energy: ${route.energyKwh.toStringAsFixed(1)} kWh'),
            if (route.chargerDataError != null) ...[
              const SizedBox(height: 10),
              Text(
                route.chargerDataError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (route.requiredStopCount == 0)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.check_circle),
                title: Text('No charging stop needed'),
                subtitle: Text(
                  'This route fits within the selected safe range.',
                ),
              )
            else if (route.stopStationIds.isEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text('No catalog charger coverage on this route'),
                subtitle: const Text(
                  'Retry the plan or verify current operator availability before travelling.',
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
                    route
                            .stationForId(route.stopStationIds[index])
                            ?.displayName ??
                        'Charging stop',
                  ),
                  subtitle: Text(
                    route.locationBased
                        ? 'Closest published charger to this route segment • verify live status before travel'
                        : 'Suggested charging break',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    final station =
                        route.stationForId(route.stopStationIds[index]);
                    if (station == null) return;
                    _openStationDetails(context, station);
                  },
                ),
              if (route.stopStationIds.length < route.requiredStopCount)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: const Text('Limited catalog coverage'),
                  subtitle: Text(
                    'This trip needs about ${route.requiredStopCount} stops, but only ${route.stopStationIds.length} suitable published charger${route.stopStationIds.length == 1 ? '' : 's'} were found on the route.',
                  ),
                ),
            ],
            const Divider(height: 30),
            Text(
              'Chargers along this route (${route.routeChargers.length})',
              key: const Key('routeChargersHeading'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              route.locationBased
                  ? 'Published BEE/operator chargers within ${route.corridorKm.toStringAsFixed(0)} km of the route, ordered from origin to destination. Inventory-only status must be verified.'
                  : 'Select origin and destination suggestions to find chargers along the route.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (route.routeChargers.isEmpty)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.ev_station_outlined),
                title: Text('No route chargers found'),
                subtitle: Text(
                  'Try another route or open live directions for current charging options.',
                ),
              )
            else
              for (final routeCharger in visibleChargers)
                _RouteChargerTile(
                  routeCharger: routeCharger,
                  recommended: route.stopStationIds.contains(
                    routeCharger.stationId,
                  ),
                  onTap: () => Navigator.of(context).push<void>(
                    _stationDetailsRoute(
                      routeCharger.station,
                      distanceKm: routeCharger.distanceFromRouteKm,
                    ),
                  ),
                ),
            if (route.routeChargers.length > _initialChargerCount)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('toggleAllRouteChargers'),
                  onPressed: () => setState(
                    () => _showAllChargers = !_showAllChargers,
                  ),
                  icon: Icon(
                    _showAllChargers
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  label: Text(
                    _showAllChargers
                        ? 'Show fewer chargers'
                        : 'Show all ${route.routeChargers.length} route chargers',
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save this trip'),
                ),
                FilledButton.icon(
                  key: const Key('openLiveDirectionsButton'),
                  onPressed: widget.onOpenDirections,
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

  void _openStationDetails(
    BuildContext context,
    OfficialChargerStation station,
  ) {
    Navigator.of(context).push<void>(_stationDetailsRoute(station));
  }

  MaterialPageRoute<void> _stationDetailsRoute(
    OfficialChargerStation station, {
    double? distanceKm,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => OfficialChargerDetailsScreen(
        station: station,
        distanceKm: distanceKm,
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
    required this.onTap,
  });

  final RouteChargerCandidate routeCharger;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final station = routeCharger.station;
    final hasLiveAvailability = station.hasLiveAvailability;
    final availableNow =
        hasLiveAvailability && (station.availableConnectors ?? 0) > 0;
    final statusColor = hasLiveAvailability
        ? availableNow
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final connectors = station.connectors
        .take(3)
        .map((connector) => connector.label)
        .join(', ');
    return ListTile(
      key: Key('routeCharger_${routeCharger.stationId}'),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        availableNow ? Icons.ev_station_rounded : Icons.ev_station_outlined,
        color: statusColor,
      ),
      title: Text(station.displayName),
      subtitle: Text(
        '${station.address.isEmpty ? station.areaLabel : station.address}\n'
        '${connectors.isEmpty ? 'Connector details not published' : connectors}'
        ' • ${routeCharger.distanceFromRouteKm.toStringAsFixed(1)} km from route\n'
        'Source: ${station.sourceLabel}',
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasLiveAvailability
                    ? availableNow
                        ? '${station.availableConnectors}/${station.totalConnectors} LIVE'
                        : 'BUSY / OFFLINE'
                    : 'VERIFY STATUS',
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
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded),
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
    required this.requiredStopCount,
    required this.routeChargers,
    required this.corridorKm,
    required this.locationBased,
    this.chargerDataError,
  });

  final String origin;
  final String destination;
  final double distanceKm;
  final int estimatedMinutes;
  final double energyKwh;
  final List<String> stopStationIds;
  final int requiredStopCount;
  final List<RouteChargerCandidate> routeChargers;
  final double corridorKm;
  final bool locationBased;
  final String? chargerDataError;

  OfficialChargerStation? stationForId(String id) {
    for (final candidate in routeChargers) {
      if (candidate.stationId == id) return candidate.station;
    }
    return null;
  }
}
