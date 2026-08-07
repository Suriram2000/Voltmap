import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/charging_station.dart';
import '../../../shared/state/app_state.dart';
import '../../discovery/data/sample_stations.dart';
import '../../discovery/presentation/station_details_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  ChargingStation selected = sampleStations.first;
  bool availableOnly = false;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final stations = availableOnly
        ? sampleStations
            .where((station) => station.available)
            .toList(growable: false)
        : sampleStations;

    if (!stations.contains(selected)) selected = stations.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('India Charger Map'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              selected: availableOnly,
              onSelected: (value) => setState(() => availableOnly = value),
              label: const Text('Available'),
              avatar: const Icon(Icons.power, size: 18),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _StreetMapPainter(
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                ),
              ),
              ...stations.map((station) => _buildMarker(station, constraints)),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _SelectedStationCard(
                  station: selected,
                  isFavorite: appState.isFavorite(selected.id),
                  onFavorite: () => appState.toggleFavorite(selected.id),
                  onDetails: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StationDetailsScreen(station: selected),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMarker(ChargingStation station, BoxConstraints constraints) {
    const minLat = 7.5;
    const maxLat = 32.5;
    const minLng = 68.5;
    const maxLng = 97.5;
    final usableWidth = constraints.maxWidth - 64;
    final usableHeight = constraints.maxHeight - 220;
    final left =
        20 + ((station.longitude - minLng) / (maxLng - minLng)) * usableWidth;
    final top = 18 +
        (1 - (station.latitude - minLat) / (maxLat - minLat)) * usableHeight;
    final isSelected = station.id == selected.id;
    final colors = Theme.of(context).colorScheme;

    return Positioned(
      left: left,
      top: top,
      child: Semantics(
        button: true,
        label: station.available
            ? '${station.name}, ${station.availableConnectors} connectors available'
            : '${station.name}, not working or unavailable',
        child: Tooltip(
          message: station.name,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => setState(() => selected = station),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isSelected ? 48 : 34,
              height: isSelected ? 48 : 34,
              decoration: BoxDecoration(
                color: station.available ? colors.primary : colors.error,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                station.isFast ? Icons.bolt : Icons.ev_station,
                size: isSelected ? 24 : 18,
                color: station.available ? colors.onPrimary : colors.onError,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedStationCard extends StatelessWidget {
  const _SelectedStationCard({
    required this.station,
    required this.isFavorite,
    required this.onFavorite,
    required this.onDetails,
  });

  final ChargingStation station;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(
                station.available ? Icons.ev_station : Icons.power_off,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    station.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${station.city}, ${station.state} • PIN ${station.postalCode} • ${station.powerKw} kW',
                    maxLines: 2,
                  ),
                  if (!station.available) ...[
                    const SizedBox(height: 5),
                    Text(
                      'NOT WORKING / UNAVAILABLE',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: isFavorite ? 'Remove favorite' : 'Save favorite',
              onPressed: onFavorite,
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
            ),
            FilledButton(onPressed: onDetails, child: const Text('Details')),
          ],
        ),
      ),
    );
  }
}

class _StreetMapPainter extends CustomPainter {
  const _StreetMapPainter({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colorScheme.surfaceContainerLowest,
    );

    final blockPaint = Paint()..color = colorScheme.surfaceContainerLow;
    for (var row = 0; row < 5; row++) {
      for (var column = 0; column < 7; column++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            18 + column * (size.width / 7),
            18 + row * 92,
            size.width / 9,
            54,
          ),
          const Radius.circular(8),
        );
        canvas.drawRRect(rect, blockPaint);
      }
    }

    final roadPaint = Paint()
      ..color = colorScheme.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final mainRoad = Path()
      ..moveTo(-20, size.height * 0.25)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.1,
        size.width * 0.58,
        size.height * 0.52,
        size.width + 20,
        size.height * 0.35,
      );
    canvas.drawPath(mainRoad, roadPaint);

    final crossRoad = Path()
      ..moveTo(size.width * 0.18, -20)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.33,
        size.width * 0.65,
        size.height * 0.55,
        size.width * 0.72,
        size.height + 20,
      );
    canvas.drawPath(crossRoad, roadPaint..strokeWidth = 7);

    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.18),
      54,
      Paint()..color = colorScheme.primaryContainer.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _StreetMapPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme;
}
