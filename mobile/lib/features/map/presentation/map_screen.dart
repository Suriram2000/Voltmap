import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/place_suggestion.dart';
import '../../../shared/services/place_search_service.dart';
import '../../../shared/widgets/location_autocomplete_field.dart';
import '../../discovery/data/official_charger_search_service.dart';
import '../../discovery/data/official_charger_station.dart';

typedef MapLocationLoader = Future<MapUserLocation> Function();

@visibleForTesting
bool canOpenMapAppSettings({
  required bool isWeb,
  required bool permissionFailure,
  required bool blocked,
}) =>
    !isWeb && permissionFailure && blocked;

enum _MapFailureType { permission, offline, service }

class MapUserLocation {
  const MapUserLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.locationLoader,
    this.placeSearchService = const PlaceSearchService(),
    this.chargerSearchService = const OfficialChargerSearchService(),
  });

  final MapLocationLoader? locationLoader;
  final PlaceSearchService placeSearchService;
  final OfficialChargerSearchService chargerSearchService;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TextEditingController _mapSearchController = TextEditingController();
  bool _loading = true;
  bool _locationEnabled = true;
  bool _locationBlocked = false;
  _MapFailureType? _failureType;
  String? _error;
  MapUserLocation? _location;
  PlaceSuggestion? _place;
  OfficialChargerSearchResult? _result;
  int _selectedIndex = 0;
  int _requestId = 0;
  String _connectorFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNearbyChargers());
  }

  @override
  void dispose() {
    _mapSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find chargers near you'),
        actions: [
          if (_loading && result != null)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            key: const Key('refreshNearbyChargersButton'),
            tooltip: 'Refresh my location',
            onPressed:
                _loading || !_locationEnabled ? null : _loadNearbyChargers,
            icon: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _LocationAccessControl(
            enabled: _locationEnabled,
            loading: _loading,
            onChanged: _setLocationEnabled,
          ),
          Expanded(
            child: result != null && _location != null
                ? _buildNearbyExperience(result, _location!)
                : _buildStatusBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBody() {
    if (!_locationEnabled) {
      return _buildSearchableStatus(
        status: const _MapStatusCard(
          key: Key('nearbyChargerLocationOff'),
          icon: Icons.location_off_rounded,
          title: 'Location sharing is off',
          message:
              'Search an area or PIN above to use the charger map without sharing your device location. Turn location sharing on whenever you want automatic nearby results.',
        ),
      );
    }

    if (_loading) {
      return _buildSearchableStatus(
        status: const _MapStatusCard(
          key: Key('nearbyChargerLoading'),
          icon: Icons.my_location_rounded,
          title: 'Finding chargers near you',
          message:
              'Allow location access to center the map, or search an area or PIN above instead.',
          loading: true,
        ),
      );
    }

    final offline = _failureType == _MapFailureType.offline;
    final permission = _failureType == _MapFailureType.permission;
    final canOpenSettings = canOpenMapAppSettings(
      isWeb: kIsWeb,
      permissionFailure: permission,
      blocked: _locationBlocked,
    );
    return _buildSearchableStatus(
      status: _MapStatusCard(
        key: const Key('nearbyChargerError'),
        icon: permission
            ? Icons.location_disabled_rounded
            : offline
                ? Icons.cloud_off_rounded
                : Icons.sync_problem_rounded,
        title: permission
            ? 'Location access is off'
            : offline
                ? 'You appear to be offline'
                : 'Charger service is unavailable',
        message: permission
            ? '${_error ?? 'Location permission is unavailable.'} You can still search any area or PIN above.'
            : _error ?? 'Try again to show nearby chargers.',
        primaryLabel: 'Try again',
        onPrimary: _loadNearbyChargers,
        secondaryLabel: canOpenSettings ? 'Open settings' : null,
        onSecondary: canOpenSettings ? Geolocator.openAppSettings : null,
      ),
    );
  }

  Widget _buildSearchableStatus({required Widget status}) {
    return Column(
      key: const Key('mapSearchableStatus'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LocationAutocompleteField(
                    key: const Key('mapLocationSearch'),
                    controller: _mapSearchController,
                    label: 'Search chargers by area or PIN',
                    hint: 'Try 500079, Hyderabad, or Bengaluru',
                    prefixIcon: Icons.search_rounded,
                    searchService: widget.placeSearchService,
                    onSelected: (place) {
                      if (place != null) _loadSelectedPlace(place);
                    },
                    onSubmitted: _submitPlaceSearch,
                    textInputAction: TextInputAction.search,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: status),
      ],
    );
  }

  Widget _buildNearbyExperience(
    OfficialChargerSearchResult result,
    MapUserLocation location,
  ) {
    if (result.matches.isEmpty) {
      return _buildSearchableStatus(
        status: _MapStatusCard(
          key: const Key('nearbyChargerNoResults'),
          icon: Icons.ev_station_outlined,
          title: 'No nearby chargers found',
          message:
              'No stations in the dated BEE inventory were found near ${_place?.primaryText ?? 'your location'} within ${result.radiusKm.toStringAsFixed(0)} km. Search another area or PIN above.',
          primaryLabel: _locationEnabled ? 'Refresh nearby chargers' : null,
          onPrimary: _locationEnabled ? _loadNearbyChargers : null,
        ),
      );
    }
    final filteredMatches = result.matches
        .where((match) => _matchesConnectorFilter(match, _connectorFilter))
        .toList(growable: false);
    final visibleResult = OfficialChargerSearchResult(
      source: result.source,
      sourceUrl: result.sourceUrl,
      asOf: result.asOf,
      totalStationCount: result.totalStationCount,
      radiusKm: result.radiusKm,
      matches: filteredMatches,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedIndex = visibleResult.matches.isEmpty
            ? -1
            : _selectedIndex.clamp(0, visibleResult.matches.length - 1);
        final map = _NearbyMapCanvas(
          key: const Key('nearbyChargerMap'),
          location: location,
          locationLabel: _place?.primaryText ?? 'Current location',
          matches: visibleResult.matches,
          radiusKm: visibleResult.radiusKm,
          selectedIndex: selectedIndex,
          onSelected: (index) => setState(() => _selectedIndex = index),
        );
        final panel = _NearbyChargerPanel(
          result: visibleResult,
          locationLabel: _place?.primaryText ?? 'Current location',
          activeFilter: _connectorFilter,
          selectedIndex: selectedIndex,
          onSelected: (index) => setState(() => _selectedIndex = index),
          onDirections: _openDirections,
        );

        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              Expanded(child: _buildMapLayer(map)),
              SizedBox(
                key: const Key('nearbyChargerSidebar'),
                width: math.min(420, constraints.maxWidth * 0.38),
                child: panel,
              ),
            ],
          );
        }

        return Stack(
          children: [
            Positioned.fill(child: _buildMapLayer(map)),
            DraggableScrollableSheet(
              key: const Key('nearbyChargerBottomSheet'),
              initialChildSize: 0.4,
              minChildSize: 0.2,
              maxChildSize: 0.88,
              snap: true,
              snapSizes: const [0.4, 0.88],
              builder: (context, scrollController) => Material(
                elevation: 18,
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26)),
                clipBehavior: Clip.antiAlias,
                child: _NearbyChargerPanel(
                  result: visibleResult,
                  locationLabel: _place?.primaryText ?? 'Current location',
                  activeFilter: _connectorFilter,
                  selectedIndex: selectedIndex,
                  onSelected: (index) => setState(() => _selectedIndex = index),
                  onDirections: _openDirections,
                  scrollController: scrollController,
                  showDragHandle: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapLayer(Widget map) {
    return Stack(
      children: [
        Positioned.fill(child: map),
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: _MapSearchOverlay(
            controller: _mapSearchController,
            locationLabel: _place?.primaryText ?? 'your area',
            searchService: widget.placeSearchService,
            loading: _loading,
            activeFilter: _connectorFilter,
            onSelected: (place) {
              if (place != null) _loadSelectedPlace(place);
            },
            onSubmitted: _submitPlaceSearch,
            onFilterPressed: _showConnectorFilters,
          ),
        ),
        Positioned(
          top: 88,
          right: 16,
          child: FloatingActionButton.small(
            key: const Key('mapRecenterButton'),
            heroTag: 'mapRecenter',
            tooltip: 'Center on my location',
            onPressed: _loading ? null : _loadNearbyChargers,
            child: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ),
      ],
    );
  }

  Future<void> _loadNearbyChargers() async {
    if (!_locationEnabled) return;
    if (_loading && _requestId > 0) return;
    _mapSearchController.clear();
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _locationBlocked = false;
      _failureType = null;
      _error = null;
    });

    try {
      final location =
          await (widget.locationLoader?.call() ?? _loadDeviceLocation());
      final place = await widget.placeSearchService.reverseIndia(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      final center = place ??
          PlaceSuggestion(
            primaryText: 'Current location',
            secondaryText:
                '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}, India',
            latitude: location.latitude,
            longitude: location.longitude,
            type: 'current_location',
          );
      final result = await widget.chargerSearchService.search(
        query: center.displayName,
        center: center,
      );
      if (!mounted || requestId != _requestId || !_locationEnabled) return;
      setState(() {
        _location = location;
        _place = center;
        _result = result;
        _selectedIndex = 0;
        _connectorFilter = 'All';
        _loading = false;
      });
    } on _MapLocationException catch (error) {
      if (!mounted || requestId != _requestId || !_locationEnabled) return;
      setState(() {
        _loading = false;
        _locationBlocked = error.blocked;
        _failureType = _MapFailureType.permission;
        _error = error.message;
      });
    } on TimeoutException {
      if (!mounted || requestId != _requestId || !_locationEnabled) return;
      setState(() {
        _loading = false;
        _failureType = _MapFailureType.offline;
        _error = 'The request timed out. Check your connection and try again.';
      });
    } on http.ClientException {
      if (!mounted || requestId != _requestId || !_locationEnabled) return;
      setState(() {
        _loading = false;
        _failureType = _MapFailureType.offline;
        _error = 'Connect to the internet to load nearby charger records.';
      });
    } catch (_) {
      if (!mounted || requestId != _requestId || !_locationEnabled) return;
      setState(() {
        _loading = false;
        _failureType = _MapFailureType.service;
        _error =
            'VoltMapEV could not load charger data. The map is hidden until data is available; try again shortly.';
      });
    }
  }

  Future<void> _loadSelectedPlace(PlaceSuggestion place) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _failureType = null;
      _error = null;
      _selectedIndex = 0;
      _connectorFilter = 'All';
    });
    try {
      final result = await widget.chargerSearchService.search(
        query: place.displayName,
        center: place,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _location = MapUserLocation(
          latitude: place.latitude,
          longitude: place.longitude,
        );
        _place = place;
        _result = result;
        _loading = false;
      });
    } on TimeoutException {
      _showPlaceSearchError(
        requestId,
        'The area search timed out. Check your connection and try again.',
        _MapFailureType.offline,
      );
    } on http.ClientException {
      _showPlaceSearchError(
        requestId,
        'Connect to the internet to search another area.',
        _MapFailureType.offline,
      );
    } catch (_) {
      _showPlaceSearchError(
        requestId,
        'VoltMapEV could not load chargers for that area. Try again shortly.',
        _MapFailureType.service,
      );
    }
  }

  void _showPlaceSearchError(
    int requestId,
    String message,
    _MapFailureType failureType,
  ) {
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _loading = false;
      _failureType = failureType;
      _error = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submitPlaceSearch(String value) async {
    final query = value.trim();
    if (query.length < 2) return;
    final places = await widget.placeSearchService.searchIndia(query);
    if (!mounted) return;
    if (places.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose an India area, city, or PIN suggestion.'),
        ),
      );
      return;
    }
    final place = places.first;
    _mapSearchController
      ..text = place.displayName
      ..selection = TextSelection.collapsed(offset: place.displayName.length);
    await _loadSelectedPlace(place);
  }

  Future<void> _showConnectorFilters() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter nearby chargers',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Filter the station list and map markers by connector or published charging speed.',
              ),
              const SizedBox(height: 14),
              RadioGroup<String>(
                groupValue: _connectorFilter,
                onChanged: (value) => Navigator.pop(context, value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in const [
                      'All',
                      'CCS2',
                      'Type 2',
                      'Fast 50+ kW',
                    ])
                      RadioListTile<String>(
                        key: ValueKey('mapFilter_$option'),
                        value: option,
                        title: Text(option),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null || selected == _connectorFilter) return;
    setState(() {
      _connectorFilter = selected;
      _selectedIndex = 0;
    });
  }

  bool _matchesConnectorFilter(
    OfficialChargerMatch match,
    String filter,
  ) {
    if (filter == 'All') return true;
    final connectors = match.station.connectors;
    return switch (filter) {
      'CCS2' => connectors.any(
          (connector) => connector.type.toLowerCase().contains('ccs'),
        ),
      'Type 2' => connectors.any((connector) {
          final type = connector.type.toLowerCase();
          return type.contains('type-ii') || type.contains('type 2');
        }),
      'Fast 50+ kW' => connectors.any(
          (connector) => (connector.ratingKw ?? 0) >= 50,
        ),
      _ => true,
    };
  }

  void _setLocationEnabled(bool enabled) {
    if (enabled == _locationEnabled) return;

    if (!enabled) {
      _requestId++;
      setState(() {
        _locationEnabled = false;
        _loading = false;
        _locationBlocked = false;
        _failureType = null;
        _error = null;
        _location = null;
        _place = null;
        _result = null;
        _selectedIndex = 0;
        _connectorFilter = 'All';
      });
      _mapSearchController.clear();
      return;
    }

    setState(() {
      _locationEnabled = true;
      _loading = false;
    });
    _loadNearbyChargers();
  }

  Future<MapUserLocation> _loadDeviceLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const _MapLocationException(
        'Turn on Location Services to find chargers near you.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _MapLocationException(
        kIsWeb
            ? 'Location access is blocked for VoltMapEV. Allow it in your browser site settings, then try again.'
            : 'Location access is blocked for VoltMapEV. Open settings and allow access while using the app.',
        blocked: true,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const _MapLocationException(
        'Location permission is needed to center the map and show nearby chargers.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return MapUserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> _openDirections(OfficialChargerStation station) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${station.latitude},${station.longitude}',
      'travelmode': 'driving',
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }
}

class _MapLocationException implements Exception {
  const _MapLocationException(this.message, {this.blocked = false});

  final String message;
  final bool blocked;
}

class _MapSearchOverlay extends StatelessWidget {
  const _MapSearchOverlay({
    required this.controller,
    required this.locationLabel,
    required this.searchService,
    required this.loading,
    required this.activeFilter,
    required this.onSelected,
    required this.onSubmitted,
    required this.onFilterPressed,
  });

  final TextEditingController controller;
  final String locationLabel;
  final PlaceSearchService searchService;
  final bool loading;
  final String activeFilter;
  final ValueChanged<PlaceSuggestion?> onSelected;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: LocationAutocompleteField(
              key: const Key('mapLocationSearch'),
              controller: controller,
              label: 'Search map',
              hint: 'Area, city or PIN near $locationLabel',
              prefixIcon: Icons.search_rounded,
              searchService: searchService,
              onSelected: onSelected,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              suffixIcon: loading
                  ? const Padding(
                      padding: EdgeInsets.all(15),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Badge(
          isLabelVisible: activeFilter != 'All',
          child: Material(
            color: colors.surface.withValues(alpha: 0.98),
            elevation: 3,
            shadowColor: Colors.black26,
            shape: const CircleBorder(),
            child: IconButton.filledTonal(
              key: const Key('mapFilterButton'),
              tooltip: activeFilter == 'All'
                  ? 'Filter chargers'
                  : 'Filter: $activeFilter',
              onPressed: onFilterPressed,
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationAccessControl extends StatelessWidget {
  const _LocationAccessControl({
    required this.enabled,
    required this.loading,
    required this.onChanged,
  });

  final bool enabled;
  final bool loading;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = !enabled
        ? 'Off — your location is not being used.'
        : loading
            ? 'On — finding chargers near you…'
            : 'On — map centered near your location.';

    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
        child: Material(
          color: enabled
              ? colors.primaryContainer.withValues(alpha: 0.64)
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile.adaptive(
            key: const Key('mapLocationToggle'),
            value: enabled,
            onChanged: onChanged,
            secondary: CircleAvatar(
              backgroundColor:
                  enabled ? colors.primary : colors.surfaceContainerHighest,
              foregroundColor:
                  enabled ? colors.onPrimary : colors.onSurfaceVariant,
              child: Icon(
                enabled ? Icons.near_me_rounded : Icons.location_off_rounded,
                size: 20,
              ),
            ),
            title: Text(
              enabled ? 'Location sharing enabled' : 'Location sharing off',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(status),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          ),
        ),
      ),
    );
  }
}

class _MapStatusCard extends StatelessWidget {
  const _MapStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 32, child: Icon(icon, size: 32)),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  if (loading) ...[
                    const SizedBox(height: 22),
                    const LinearProgressIndicator(value: 0.45),
                  ],
                  if (primaryLabel != null && onPrimary != null) ...[
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: onPrimary,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(primaryLabel!),
                    ),
                  ],
                  if (secondaryLabel != null && onSecondary != null)
                    TextButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NearbyMapCanvas extends StatelessWidget {
  const _NearbyMapCanvas({
    super.key,
    required this.location,
    required this.locationLabel,
    required this.matches,
    required this.radiusKm,
    required this.selectedIndex,
    required this.onSelected,
  });

  final MapUserLocation location;
  final String locationLabel;
  final List<OfficialChargerMatch> matches;
  final double radiusKm;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final projection = _MapProjection(
          center: location,
          radiusKm: radiusKm,
          size: size,
        );
        return Semantics(
          label: 'Nearby charger map with ${matches.length} official stations',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: matches.isEmpty
                ? null
                : (details) {
                    var closestIndex = -1;
                    var closestDistance = double.infinity;
                    for (var index = 0; index < matches.length; index++) {
                      final station = matches[index].station;
                      final point = projection.project(
                        station.latitude,
                        station.longitude,
                      );
                      final distance = (point - details.localPosition).distance;
                      if (distance < closestDistance) {
                        closestDistance = distance;
                        closestIndex = index;
                      }
                    }
                    if (closestIndex >= 0 && closestDistance <= 28) {
                      onSelected(closestIndex);
                    }
                  },
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _NearbyMapPainter(
                        projection: projection,
                        matches: matches,
                        selectedIndex: selectedIndex,
                        colorScheme: colors,
                        locationLabel: locationLabel,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 12),
                      ],
                    ),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LegendDot(color: Color(0xFF1A73E8)),
                          SizedBox(width: 6),
                          Text('You'),
                          SizedBox(width: 12),
                          _LegendDot(color: AppTheme.brandGreen),
                          SizedBox(width: 6),
                          Text('Chargers'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const SizedBox.square(dimension: 10),
      );
}

class _MapProjection {
  const _MapProjection({
    required this.center,
    required this.radiusKm,
    required this.size,
  });

  final MapUserLocation center;
  final double radiusKm;
  final Size size;

  Offset project(double latitude, double longitude) {
    final latitudeSpan = math.max(radiusKm / 110.574, 0.01);
    final cosine = math.max(
      math.cos(center.latitude * math.pi / 180).abs(),
      0.2,
    );
    final longitudeSpan = math.max(radiusKm / (111.320 * cosine), 0.01);
    final width = math.max(size.width - 40, 1.0);
    final height = math.max(size.height - 40, 1.0);
    final x =
        ((longitude - (center.longitude - longitudeSpan)) / (longitudeSpan * 2))
            .clamp(0.0, 1.0);
    final y =
        (1 - (latitude - (center.latitude - latitudeSpan)) / (latitudeSpan * 2))
            .clamp(0.0, 1.0);
    return Offset(20 + x * width, 20 + y * height);
  }
}

class _NearbyMapPainter extends CustomPainter {
  const _NearbyMapPainter({
    required this.projection,
    required this.matches,
    required this.selectedIndex,
    required this.colorScheme,
    required this.locationLabel,
  });

  final _MapProjection projection;
  final List<OfficialChargerMatch> matches;
  final int selectedIndex;
  final ColorScheme colorScheme;
  final String locationLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final isLight = colorScheme.brightness == Brightness.light;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = isLight ? const Color(0xFFF1F6F8) : const Color(0xFF101C1B),
    );

    final water = Path()
      ..moveTo(size.width * 0.84, -20)
      ..cubicTo(
        size.width * 0.73,
        size.height * 0.2,
        size.width * 1.03,
        size.height * 0.38,
        size.width * 0.88,
        size.height * 0.58,
      )
      ..lineTo(size.width + 20, size.height * 0.64)
      ..lineTo(size.width + 20, -20)
      ..close();
    canvas.drawPath(
      water,
      Paint()
        ..color = isLight ? const Color(0xFFDCEFF7) : const Color(0xFF17333A),
    );

    final parkPaint = Paint()
      ..color = isLight ? const Color(0xFFDDEEDC) : const Color(0xFF173127);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.08,
          size.height * 0.16,
          size.width * 0.22,
          size.height * 0.13,
        ),
        const Radius.circular(32),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.63,
          size.height * 0.58,
          size.width * 0.2,
          size.height * 0.15,
        ),
        const Radius.circular(26),
      ),
      parkPaint,
    );

    final minorRoad = Paint()
      ..color = isLight ? Colors.white : const Color(0xFF263631)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final roadOutline = Paint()
      ..color = isLight ? const Color(0xFFD5E0E7) : const Color(0xFF344943)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final majorRoad = Paint()
      ..color = isLight ? const Color(0xFFF8FCFE) : const Color(0xFF2A3A35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final diagonal = Path()
      ..moveTo(-20, size.height * 0.72)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.62,
        size.width * 0.62,
        size.height * 0.28,
        size.width + 20,
        size.height * 0.34,
      );
    canvas.drawPath(diagonal, roadOutline);
    canvas.drawPath(diagonal, majorRoad);

    for (var index = 0; index < 7; index++) {
      final fraction = (index + 1) / 8;
      final vertical = Path()
        ..moveTo(size.width * fraction - 40, -20)
        ..cubicTo(
          size.width * (fraction + 0.08),
          size.height * 0.32,
          size.width * (fraction - 0.08),
          size.height * 0.68,
          size.width * fraction + 45,
          size.height + 20,
        );
      canvas.drawPath(vertical, minorRoad);
    }
    for (var index = 0; index < 6; index++) {
      final fraction = (index + 1) / 7;
      final horizontal = Path()
        ..moveTo(-20, size.height * fraction + 25)
        ..cubicTo(
          size.width * 0.3,
          size.height * (fraction - 0.07),
          size.width * 0.68,
          size.height * (fraction + 0.07),
          size.width + 20,
          size.height * fraction - 25,
        );
      canvas.drawPath(horizontal, minorRoad);
    }

    _drawMapLabel(
      canvas,
      locationLabel.split('/').first.trim(),
      Offset(size.width * 0.5, size.height * 0.56),
      colorScheme.onSurface.withValues(alpha: 0.76),
      20,
      FontWeight.w800,
    );

    for (var index = 0; index < matches.length; index++) {
      final station = matches[index].station;
      final point = projection.project(station.latitude, station.longitude);
      _drawChargerPin(
        canvas,
        point,
        selected: index == selectedIndex,
        connectorCount: station.connectors.fold<int>(
          0,
          (sum, connector) => sum + (connector.count ?? 1),
        ),
      );
    }

    final userPoint = projection.project(
      projection.center.latitude,
      projection.center.longitude,
    );
    canvas.drawCircle(
      userPoint,
      30,
      Paint()..color = const Color(0x331A73E8),
    );
    canvas.drawCircle(
      userPoint,
      17,
      Paint()..color = const Color(0x221A73E8),
    );
    canvas.drawCircle(userPoint, 10, Paint()..color = const Color(0xFF1A73E8));
    canvas.drawCircle(
      userPoint,
      10,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _drawChargerPin(
    Canvas canvas,
    Offset point, {
    required bool selected,
    required int connectorCount,
  }) {
    final center = point.translate(0, -22);
    final radius = selected ? 23.0 : 19.0;
    if (selected) {
      canvas.drawCircle(
        center,
        radius + 7,
        Paint()..color = AppTheme.brandLime.withValues(alpha: 0.5),
      );
    }
    final pointer = Path()
      ..moveTo(point.dx, point.dy)
      ..lineTo(center.dx - 10, center.dy + 10)
      ..lineTo(center.dx + 10, center.dy + 10)
      ..close();
    canvas.drawPath(pointer, Paint()..color = AppTheme.brandGreen);
    canvas.drawCircle(center, radius, Paint()..color = AppTheme.brandGreen);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3 : 2,
    );

    final bolt = Path()
      ..moveTo(center.dx + 3, center.dy - 13)
      ..lineTo(center.dx - 8, center.dy + 1)
      ..lineTo(center.dx - 1, center.dy + 1)
      ..lineTo(center.dx - 5, center.dy + 13)
      ..lineTo(center.dx + 10, center.dy - 4)
      ..lineTo(center.dx + 3, center.dy - 4)
      ..close();
    canvas.drawPath(bolt, Paint()..color = Colors.white);

    final countText = connectorCount > 99 ? '99+' : '$connectorCount';
    final textPainter = TextPainter(
      text: TextSpan(
        text: countText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: point.translate(0, -2),
        width: math.max(26, textPainter.width + 12),
        height: 18,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(badgeRect, Paint()..color = const Color(0xFF12201B));
    textPainter.paint(
      canvas,
      Offset(
        badgeRect.center.dx - textPainter.width / 2,
        badgeRect.center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawMapLabel(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double size,
    FontWeight weight,
  ) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 220);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _NearbyMapPainter oldDelegate) =>
      oldDelegate.matches != matches ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.locationLabel != locationLabel ||
      oldDelegate.projection.size != projection.size ||
      oldDelegate.projection.center.latitude != projection.center.latitude ||
      oldDelegate.projection.center.longitude != projection.center.longitude;
}

class _NearbyChargerPanel extends StatelessWidget {
  const _NearbyChargerPanel({
    required this.result,
    required this.locationLabel,
    required this.activeFilter,
    required this.selectedIndex,
    required this.onSelected,
    required this.onDirections,
    this.scrollController,
    this.showDragHandle = false,
  });

  final OfficialChargerSearchResult result;
  final String locationLabel;
  final String activeFilter;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<OfficialChargerStation> onDirections;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: ListView.builder(
        key: const Key('nearbyChargerPanel'),
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(14, showDragHandle ? 6 : 14, 14, 30),
        itemCount: result.matches.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _NearbyPanelHeader(
              result: result,
              locationLabel: locationLabel,
              activeFilter: activeFilter,
              showDragHandle: showDragHandle,
            );
          }
          final matchIndex = index - 1;
          final match = result.matches[matchIndex];
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _NearbyStationTile(
              match: match,
              selected: matchIndex == selectedIndex,
              onTap: () => onSelected(matchIndex),
              onDirections: () => onDirections(match.station),
            ),
          );
        },
      ),
    );
  }
}

class _NearbyPanelHeader extends StatelessWidget {
  const _NearbyPanelHeader({
    required this.result,
    required this.locationLabel,
    required this.activeFilter,
    required this.showDragHandle,
  });

  final OfficialChargerSearchResult result;
  final String locationLabel;
  final String activeFilter;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDragHandle)
          Center(
            child: Container(
              width: 42,
              height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Nearby Chargers',
                key: const Key('nearbyChargerCount'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text(
                  '${result.matches.length} shown',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Near $locationLabel • within ${result.radiusKm.toStringAsFixed(0)} km${activeFilter == 'All' ? '' : ' • $activeFilter'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          'List and markers cover the same map area. Official BEE inventory is not live; availability and prices must be verified before travel.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _NearbyStationTile extends StatelessWidget {
  const _NearbyStationTile({
    required this.match,
    required this.selected,
    required this.onTap,
    required this.onDirections,
  });

  final OfficialChargerMatch match;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final station = match.station;
    final connectorSummary = station.connectors
        .take(3)
        .map((connector) => connector.label)
        .join(' • ');
    final speedRatings = station.connectors
        .map((connector) => connector.ratingKw)
        .whereType<double>();
    final maxSpeed =
        speedRatings.isEmpty ? null : speedRatings.reduce(math.max);
    return Material(
      key: ValueKey(
        'nearby_${station.latitude}_${station.longitude}_${station.operatorName}',
      ),
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
                child: Icon(
                  Icons.ev_station_rounded,
                  size: 20,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : AppTheme.brandGreen,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      station.areaLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (connectorSummary.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        connectorSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      'Availability: Not published • Price: Not published',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      maxSpeed == null
                          ? 'Charging speed: Not published'
                          : 'Charging speed: up to ${maxSpeed % 1 == 0 ? maxSpeed.toStringAsFixed(0) : maxSpeed.toStringAsFixed(1)} kW',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (match.distanceKm != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${match.distanceKm!.toStringAsFixed(1)} km away',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Directions in Google Maps',
                onPressed: onDirections,
                icon: const Icon(Icons.directions_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
