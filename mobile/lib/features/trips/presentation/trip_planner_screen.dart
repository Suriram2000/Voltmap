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
  Timer? _stationPreviewDebounce;
  OfficialChargerSearchResult? _stationPreview;
  PlaceSuggestion? _stationPreviewPlace;
  String? _stationPreviewQuery;
  String? _stationPreviewError;
  bool _stationPreviewLoading = false;
  bool _showAllPreviewStations = false;
  int _stationPreviewRequestId = 0;
  final Set<String> _selectedPreviewStationIds = {};

  @override
  void dispose() {
    _stationPreviewDebounce?.cancel();
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
                        onSelected: (place) {
                          originPlace = place;
                          if (place != null) {
                            _queueStationPreview(
                              place.displayName,
                              selected: place,
                            );
                          }
                        },
                        onChanged: (value) => _queueStationPreview(value),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      LocationAutocompleteField(
                        controller: destinationController,
                        label: 'Destination',
                        hint: 'Try “ban” for Bengaluru and more places',
                        prefixIcon: Icons.flag,
                        searchService: widget.searchService,
                        onSelected: (place) {
                          destinationPlace = place;
                          if (place != null) {
                            _queueStationPreview(
                              place.displayName,
                              selected: place,
                            );
                          }
                        },
                        onChanged: (value) => _queueStationPreview(value),
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
                      if (_stationPreviewQuery != null) ...[
                        const SizedBox(height: 14),
                        _buildStationPreview(),
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

  Future<void> _planRoute() async {
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

    setState(() => _planning = true);
    final resolvedOrigin = await _resolvePlace(origin, originPlace);
    final resolvedDestination =
        await _resolvePlace(destination, destinationPlace);
    if (!mounted) return;
    final hasCoordinates =
        resolvedOrigin != null && resolvedDestination != null;
    if (!hasCoordinates) {
      setState(() => _planning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select both places from the suggestions so VoltMapEV can calculate the route corridor accurately.',
          ),
        ),
      );
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
    if (!mounted) return;
    final stopIds = selectChargingStops(
      stopCount: stopCount,
      routeChargers: routeChargers,
      preferredStationIds: _selectedPreviewStationIds,
    );
    final averageSpeedKmh = distance <= 50
        ? 35.0
        : distance <= 200
            ? 50.0
            : 65.0;
    final driveMinutes = (distance / averageSpeedKmh * 60).round();

    setState(() {
      _planning = false;
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
        userSelectedStationIds: routeChargers
            .where(
              (candidate) =>
                  _selectedPreviewStationIds.contains(candidate.stationId),
            )
            .map((candidate) => candidate.stationId)
            .toList(growable: false),
      );
    });
  }

  void _queueStationPreview(
    String rawQuery, {
    PlaceSuggestion? selected,
  }) {
    _stationPreviewDebounce?.cancel();
    final query = rawQuery.trim();
    final requestId = ++_stationPreviewRequestId;
    if (query.length < 3) {
      setState(() {
        _stationPreview = null;
        _stationPreviewPlace = null;
        _stationPreviewQuery = null;
        _stationPreviewError = null;
        _stationPreviewLoading = false;
        _selectedPreviewStationIds.clear();
      });
      return;
    }
    setState(() {
      _stationPreviewQuery = query;
      _stationPreviewError = null;
      _stationPreviewLoading = true;
      _showAllPreviewStations = false;
    });
    final isPin = RegExp(r'^[1-9]\d{5}$').hasMatch(query);
    _stationPreviewDebounce = Timer(
      Duration(milliseconds: isPin || selected != null ? 120 : 420),
      () => _loadStationPreview(
        query,
        selected: selected,
        requestId: requestId,
      ),
    );
  }

  Future<void> _loadStationPreview(
    String query, {
    PlaceSuggestion? selected,
    int? requestId,
  }) async {
    final activeRequestId = requestId ?? ++_stationPreviewRequestId;
    if (requestId == null) {
      setState(() {
        _stationPreviewLoading = true;
        _stationPreviewError = null;
      });
    }
    try {
      final resolved = await _resolvePlace(query, selected);
      if (resolved == null) {
        throw StateError(
          'Choose an India PIN, city, or area suggestion to load chargers.',
        );
      }
      final result = await widget.chargerDataService.search(
        query: query,
        center: resolved,
      );
      if (!mounted || activeRequestId != _stationPreviewRequestId) return;
      final availableIds = result.matches
          .map((match) => match.station.feedbackStationId)
          .toSet();
      setState(() {
        _stationPreview = result;
        _stationPreviewPlace = resolved;
        _stationPreviewError = null;
        _stationPreviewLoading = false;
        _selectedPreviewStationIds.retainAll(availableIds);
      });
    } catch (error) {
      if (!mounted || activeRequestId != _stationPreviewRequestId) return;
      setState(() {
        _stationPreview = null;
        _stationPreviewPlace = null;
        _stationPreviewLoading = false;
        _stationPreviewError = error is StateError
            ? error.message
            : 'Charging stations could not be loaded. Check your connection and retry.';
      });
    }
  }

  Widget _buildStationPreview() {
    final query = _stationPreviewQuery!;
    if (_stationPreviewLoading) {
      return const Card(
        key: Key('routeStationPreviewLoading'),
        child: ListTile(
          leading: CircularProgressIndicator(strokeWidth: 2),
          title: Text('Finding charging stations'),
          subtitle:
              Text('Matching chargers will appear before route planning.'),
        ),
      );
    }
    final error = _stationPreviewError;
    if (error != null) {
      return Card(
        key: const Key('routeStationPreviewError'),
        child: ListTile(
          leading: Icon(
            Icons.sync_problem_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('Could not load charging stations'),
          subtitle: Text(error),
          trailing: TextButton(
            key: const Key('retryRouteStationPreview'),
            onPressed: () => _loadStationPreview(
              query,
              selected: _stationPreviewPlace,
            ),
            child: const Text('Retry'),
          ),
        ),
      );
    }
    final result = _stationPreview;
    if (result == null) return const SizedBox.shrink();
    if (result.matches.isEmpty) {
      return Card(
        key: const Key('routeStationPreviewEmpty'),
        child: ListTile(
          leading: const Icon(Icons.ev_station_outlined),
          title: Text('No charging stations found near $query'),
          subtitle: const Text(
            'Try another PIN, city, or area. The map will never be left blank.',
          ),
        ),
      );
    }
    const initialCount = 8;
    final visibleMatches = _showAllPreviewStations
        ? result.matches
        : result.matches.take(initialCount).toList(growable: false);
    final exactLabel = result.exactPostcodeCount == 0
        ? ''
        : ' ${result.exactPostcodeCount} exact PIN match${result.exactPostcodeCount == 1 ? '' : 'es'}.';
    return Card(
      key: const Key('routeStationPreview'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const CircleAvatar(
                child: Icon(Icons.ev_station_rounded),
              ),
              title: Text(
                'Charging stations near ${_stationPreviewPlace?.primaryText ?? query}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${result.matches.length} matching station${result.matches.length == 1 ? '' : 's'} found.$exactLabel Select preferred stations before Plan route.',
              ),
            ),
            for (final match in visibleMatches)
              CheckboxListTile(
                key: ValueKey(
                  'routePreviewStation_${match.station.feedbackStationId}',
                ),
                value: _selectedPreviewStationIds.contains(
                  match.station.feedbackStationId,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(match.station.displayName),
                subtitle: Text(
                  '${match.station.address.isEmpty ? match.station.areaLabel : match.station.address}\n'
                  '${match.distanceKm == null ? 'Distance unavailable' : '${match.distanceKm!.toStringAsFixed(1)} km away'} · ${match.station.sourceLabel}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                secondary: IconButton(
                  tooltip: 'Review charger details',
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => OfficialChargerDetailsScreen(
                        station: match.station,
                        distanceKm: match.distanceKm,
                        distanceContext: 'from the selected route location',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedPreviewStationIds.add(
                        match.station.feedbackStationId,
                      );
                    } else {
                      _selectedPreviewStationIds.remove(
                        match.station.feedbackStationId,
                      );
                    }
                  });
                },
              ),
            if (result.matches.length > initialCount)
              TextButton.icon(
                key: const Key('toggleAllRoutePreviewStations'),
                onPressed: () => setState(
                  () => _showAllPreviewStations = !_showAllPreviewStations,
                ),
                icon: Icon(
                  _showAllPreviewStations
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(
                  _showAllPreviewStations
                      ? 'Show fewer stations'
                      : 'Show all ${result.matches.length} stations',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<PlaceSuggestion?> _resolvePlace(
    String input,
    PlaceSuggestion? selected,
  ) async {
    final normalizedInput = _normalizePlace(input);
    if (selected != null) {
      final selectedText = _normalizePlace(selected.displayName);
      if (selectedText.contains(normalizedInput) ||
          normalizedInput.contains(_normalizePlace(selected.primaryText))) {
        return selected;
      }
    }
    final suggestions = await widget.searchService.searchIndia(input);
    if (suggestions.isEmpty) return null;
    final postcode =
        RegExp(r'(?<!\d)([1-9]\d{5})(?!\d)').firstMatch(input)?.group(1);
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
                  userSelected: route.userSelectedStationIds.contains(
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
    required this.userSelected,
    required this.onTap,
  });

  final RouteChargerCandidate routeCharger;
  final bool recommended;
  final bool userSelected;
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
              if (userSelected)
                const Text(
                  'YOUR SELECTION',
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
    required this.userSelectedStationIds,
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
  final List<String> userSelectedStationIds;
  final String? chargerDataError;

  OfficialChargerStation? stationForId(String id) {
    for (final candidate in routeChargers) {
      if (candidate.stationId == id) return candidate.station;
    }
    return null;
  }
}
