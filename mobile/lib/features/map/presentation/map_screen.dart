import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/place_suggestion.dart';
import '../../../shared/services/place_search_service.dart';
import '../../discovery/data/official_charger_search_service.dart';
import '../../discovery/data/official_charger_station.dart';

typedef MapLocationLoader = Future<MapUserLocation> Function();

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
  bool _loading = true;
  bool _locationBlocked = false;
  String? _error;
  MapUserLocation? _location;
  PlaceSuggestion? _place;
  OfficialChargerSearchResult? _result;
  int _selectedIndex = 0;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNearbyChargers());
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('India Charger Map'),
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
            onPressed: _loading ? null : _loadNearbyChargers,
            icon: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: result != null && _location != null
          ? _buildNearbyExperience(result, _location!)
          : _buildStatusBody(),
    );
  }

  Widget _buildStatusBody() {
    if (_loading) {
      return const _MapStatusCard(
        key: Key('nearbyChargerLoading'),
        icon: Icons.my_location_rounded,
        title: 'Finding chargers near you',
        message:
            'Allow location access to center the map and load nearby official charging stations.',
        loading: true,
      );
    }

    return _MapStatusCard(
      key: const Key('nearbyChargerError'),
      icon: _locationBlocked
          ? Icons.location_disabled_rounded
          : Icons.location_searching_rounded,
      title: _locationBlocked
          ? 'Location access is off'
          : 'Your location could not be loaded',
      message: _error ?? 'Try again to show nearby chargers.',
      primaryLabel: 'Try again',
      onPrimary: _loadNearbyChargers,
      secondaryLabel: _locationBlocked ? 'Open settings' : null,
      onSecondary: _locationBlocked ? Geolocator.openAppSettings : null,
    );
  }

  Widget _buildNearbyExperience(
    OfficialChargerSearchResult result,
    MapUserLocation location,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedIndex = result.matches.isEmpty
            ? -1
            : _selectedIndex.clamp(0, result.matches.length - 1);
        final map = _NearbyMapCanvas(
          key: const Key('nearbyChargerMap'),
          location: location,
          matches: result.matches,
          radiusKm: result.radiusKm,
          selectedIndex: selectedIndex,
          onSelected: (index) => setState(() => _selectedIndex = index),
        );
        final panel = _NearbyChargerPanel(
          result: result,
          locationLabel: _place?.primaryText ?? 'Current location',
          selectedIndex: selectedIndex,
          onSelected: (index) => setState(() => _selectedIndex = index),
          onDirections: _openDirections,
        );

        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              Expanded(child: map),
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
            Positioned.fill(child: map),
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
                  result: result,
                  locationLabel: _place?.primaryText ?? 'Current location',
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

  Future<void> _loadNearbyChargers() async {
    if (_loading && _requestId > 0) return;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _locationBlocked = false;
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
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _location = location;
        _place = center;
        _result = result;
        _selectedIndex = 0;
        _loading = false;
      });
    } on _MapLocationException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _locationBlocked = error.blocked;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = 'Check location services and your connection, then try again.';
      });
    }
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
        'Location access is blocked for VoltMapEV. Open settings and allow access while using the app.',
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
    required this.matches,
    required this.radiusKm,
    required this.selectedIndex,
    required this.onSelected,
  });

  final MapUserLocation location;
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
  });

  final _MapProjection projection;
  final List<OfficialChargerMatch> matches;
  final int selectedIndex;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colorScheme.surfaceContainerLowest,
    );

    final gridPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    const spacing = 52.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final roadPaint = Paint()
      ..color = colorScheme.surfaceContainerHighest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final road = Path()
      ..moveTo(-20, size.height * 0.72)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.62,
        size.width * 0.62,
        size.height * 0.28,
        size.width + 20,
        size.height * 0.34,
      );
    canvas.drawPath(road, roadPaint);

    final chargerPaint = Paint()..color = AppTheme.brandGreen;
    for (var index = 0; index < matches.length; index++) {
      if (index == selectedIndex) continue;
      final station = matches[index].station;
      final point = projection.project(station.latitude, station.longitude);
      canvas.drawCircle(point, 5, chargerPaint);
      canvas.drawCircle(
        point,
        5,
        Paint()
          ..color = colorScheme.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (selectedIndex >= 0 && selectedIndex < matches.length) {
      final station = matches[selectedIndex].station;
      final point = projection.project(station.latitude, station.longitude);
      canvas.drawCircle(point, 13, Paint()..color = AppTheme.brandLime);
      canvas.drawCircle(point, 8, Paint()..color = AppTheme.brandGreen);
      canvas.drawCircle(
        point,
        8,
        Paint()
          ..color = colorScheme.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    final userPoint = projection.project(
      projection.center.latitude,
      projection.center.longitude,
    );
    canvas.drawCircle(
      userPoint,
      15,
      Paint()..color = const Color(0x331A73E8),
    );
    canvas.drawCircle(userPoint, 8, Paint()..color = const Color(0xFF1A73E8));
    canvas.drawCircle(
      userPoint,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _NearbyMapPainter oldDelegate) =>
      oldDelegate.matches != matches ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.projection.size != projection.size ||
      oldDelegate.projection.center.latitude != projection.center.latitude ||
      oldDelegate.projection.center.longitude != projection.center.longitude;
}

class _NearbyChargerPanel extends StatelessWidget {
  const _NearbyChargerPanel({
    required this.result,
    required this.locationLabel,
    required this.selectedIndex,
    required this.onSelected,
    required this.onDirections,
    this.scrollController,
    this.showDragHandle = false,
  });

  final OfficialChargerSearchResult result;
  final String locationLabel;
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
    required this.showDragHandle,
  });

  final OfficialChargerSearchResult result;
  final String locationLabel;
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
            const Icon(Icons.ev_station_rounded, color: AppTheme.brandGreen),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '${result.matches.length} nearby chargers',
                key: const Key('nearbyChargerCount'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Near $locationLabel • within ${result.radiusKm.toStringAsFixed(0)} km',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          'Official BEE inventory, not live availability. All nearby records are listed by distance; verify access before travel.',
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
