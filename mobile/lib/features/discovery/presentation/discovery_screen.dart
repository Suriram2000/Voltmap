import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/charging_station.dart';
import '../../../shared/state/app_state.dart';
import '../data/sample_stations.dart';
import 'station_card.dart';
import 'station_details_screen.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final searchController = TextEditingController();
  String query = '';
  bool availableOnly = false;
  bool fastOnly = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<ChargingStation> get filteredStations {
    final normalized = query.trim().toLowerCase();
    return sampleStations
        .where((station) {
          final matchesQuery =
              normalized.isEmpty ||
              station.name.toLowerCase().contains(normalized) ||
              station.network.toLowerCase().contains(normalized) ||
              station.address.toLowerCase().contains(normalized) ||
              station.connectorTypes.any(
                (connector) => connector.toLowerCase().contains(normalized),
              );
          return matchesQuery &&
              (!availableOnly || station.available) &&
              (!fastOnly || station.isFast);
        })
        .toList(growable: false)
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final stations = filteredStations;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(Icons.bolt), SizedBox(width: 6), Text('VoltMap')],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              avatar: const Icon(Icons.location_on, size: 18),
              label: const Text('Hyderabad'),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Find the right charger, faster.',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Search ${sampleStations.length} verified demo locations and save your favorites.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          SearchBar(
            controller: searchController,
            hintText: 'Station, area, network, or connector',
            leading: const Icon(Icons.search),
            trailing: [
              if (query.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    searchController.clear();
                    setState(() => query = '');
                  },
                  icon: const Icon(Icons.close),
                ),
            ],
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                selected: availableOnly,
                onSelected: (value) => setState(() => availableOnly = value),
                avatar: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Available now'),
              ),
              FilterChip(
                selected: fastOnly,
                onSelected: (value) => setState(() => fastOnly = value),
                avatar: const Icon(Icons.bolt, size: 18),
                label: const Text('100+ kW'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'Nearby chargers',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text('${stations.length} results'),
            ],
          ),
          const SizedBox(height: 12),
          if (stations.isEmpty)
            _EmptySearch(onReset: _resetFilters)
          else
            for (final station in stations) ...[
              StationCard(
                station: station,
                isFavorite: appState.isFavorite(station.id),
                onFavorite: () => appState.toggleFavorite(station.id),
                onTap: () => _openDetails(station),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  void _resetFilters() {
    searchController.clear();
    setState(() {
      query = '';
      availableOnly = false;
      fastOnly = false;
    });
  }

  void _openDetails(ChargingStation station) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StationDetailsScreen(station: station),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 44),
            const SizedBox(height: 12),
            Text(
              'No chargers match those filters',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onReset,
              child: const Text('Reset filters'),
            ),
          ],
        ),
      ),
    );
  }
}
