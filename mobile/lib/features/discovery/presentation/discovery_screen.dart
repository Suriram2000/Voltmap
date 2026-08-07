import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
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
    final matches = sampleStations.where((station) {
      return _matchesSearch(station, query) &&
          (!availableOnly || station.available) &&
          (!fastOnly || station.isFast);
    }).toList(growable: false);

    if (query.trim().isNotEmpty) {
      matches.sort((a, b) {
        final pinComparison = a.postalCode.compareTo(b.postalCode);
        return pinComparison != 0 ? pinComparison : a.name.compareTo(b.name);
      });
    }
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final stations = filteredStations;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 28.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              constraints.maxWidth < 600 ? 14 : 26,
              horizontalPadding,
              36,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DiscoveryHero(
                        searchController: searchController,
                        query: query,
                        onSearchChanged: (value) =>
                            setState(() => query = value),
                        onClear: _clearSearch,
                      ),
                      const SizedBox(height: 22),
                      _FilterRow(
                        availableOnly: availableOnly,
                        fastOnly: fastOnly,
                        onAvailableChanged: (value) =>
                            setState(() => availableOnly = value),
                        onFastChanged: (value) =>
                            setState(() => fastOnly = value),
                      ),
                      const SizedBox(height: 30),
                      _ResultsHeader(count: stations.length, query: query),
                      const SizedBox(height: 14),
                      if (stations.isEmpty)
                        _EmptySearch(onReset: _resetFilters)
                      else
                        LayoutBuilder(
                          builder: (context, gridConstraints) {
                            final twoColumns = gridConstraints.maxWidth >= 760;
                            final cardWidth = twoColumns
                                ? (gridConstraints.maxWidth - 16) / 2
                                : gridConstraints.maxWidth;
                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                for (final station in stations)
                                  SizedBox(
                                    width: cardWidth,
                                    child: StationCard(
                                      station: station,
                                      isFavorite: appState.isFavorite(
                                        station.id,
                                      ),
                                      onFavorite: () => appState.toggleFavorite(
                                        station.id,
                                      ),
                                      onTap: () => _openDetails(station),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _clearSearch() {
    searchController.clear();
    setState(() => query = '');
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

class _DiscoveryHero extends StatelessWidget {
  const _DiscoveryHero({
    required this.searchController,
    required this.query,
    required this.onSearchChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final availableConnectors = sampleStations.fold<int>(
      0,
      (total, station) => total + station.availableConnectors,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.brandNavy, Color(0xFF0B3829)],
            ),
            borderRadius: BorderRadius.circular(compact ? 26 : 34),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26071D17),
                blurRadius: 34,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned(
                right: -90,
                top: -120,
                child: _GlowOrb(size: 310, color: Color(0x3320C77A)),
              ),
              const Positioned(
                right: 170,
                bottom: -110,
                child: _GlowOrb(size: 230, color: Color(0x20C8F45B)),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 22 : 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.brandGreen.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color:
                                  AppTheme.brandGreen.withValues(alpha: 0.28),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PulseDot(),
                              SizedBox(width: 8),
                              Text(
                                'LIVE DEMO NETWORK',
                                style: TextStyle(
                                  color: Color(0xFFD8FFE9),
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                color: AppTheme.brandLime,
                                size: 17,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Across India',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 28 : 38),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Text(
                        'Find the right charger, faster.',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontSize: compact ? 34 : 52,
                                  letterSpacing: compact ? -1.1 : -1.8,
                                ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        'Search representative charging stations across India by PIN code, city, state, area, network, or connector.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFFB8CEC4),
                              fontSize: compact ? 15 : 17,
                            ),
                      ),
                    ),
                    SizedBox(height: compact ? 24 : 30),
                    Wrap(
                      spacing: 20,
                      runSpacing: 12,
                      children: [
                        _HeroMetric(
                          value: '${sampleStations.length}',
                          label: 'demo stations',
                        ),
                        _HeroMetric(
                          value: '$availableConnectors',
                          label: 'connectors available',
                        ),
                        _HeroMetric(
                          value:
                              '${sampleStations.map((station) => station.city).toSet().length}',
                          label: 'cities covered',
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 26 : 34),
                    Container(
                      padding: EdgeInsets.all(compact ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: SearchBar(
                        controller: searchController,
                        hintText: 'Station, area, connector, or PIN code',
                        leading: const Icon(Icons.search_rounded),
                        trailing: [
                          if (query.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear search',
                              onPressed: onClear,
                              icon: const Icon(Icons.close),
                            ),
                        ],
                        onChanged: onSearchChanged,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Try 110001, Mumbai, Whitefield, Tamil Nadu, or 500-081.',
                        style: TextStyle(
                          color: Color(0xFF9FB8AD),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.availableOnly,
    required this.fastOnly,
    required this.onAvailableChanged,
    required this.onFastChanged,
  });

  final bool availableOnly;
  final bool fastOnly;
  final ValueChanged<bool> onAvailableChanged;
  final ValueChanged<bool> onFastChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Quick filters',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        FilterChip(
          selected: availableOnly,
          onSelected: onAvailableChanged,
          avatar: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Available now'),
        ),
        FilterChip(
          selected: fastOnly,
          onSelected: onFastChanged,
          avatar: const Icon(Icons.bolt_rounded, size: 18),
          label: const Text('100+ kW'),
        ),
        Chip(
          avatar: const Icon(Icons.tune_rounded, size: 17),
          label: const Text('India-wide demo'),
          side: BorderSide.none,
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
      ],
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.count, required this.query});

  final int count;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                query.trim().isEmpty
                    ? 'Charging network across India'
                    : 'Search results',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                query.trim().isEmpty
                    ? 'Explore the bundled demo network by city, state, area, or PIN'
                    : 'Matching "${query.trim()}" across area, city, state, PIN, and network',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count ${count == 1 ? 'result' : 'results'}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
        ),
      ],
    );
  }
}

bool _matchesSearch(ChargingStation station, String rawQuery) {
  final terms = rawQuery
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((term) => term.replaceAll(RegExp(r'[^a-z0-9]'), ''))
      .where((term) => term.isNotEmpty)
      .toList(growable: false);

  if (terms.isEmpty) return true;

  final searchableText = [
    station.name,
    station.network,
    station.address,
    station.city,
    station.state,
    station.postalCode,
    ...station.connectorTypes,
    ...station.searchAliases,
  ].join(' ').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  return terms.every(searchableText.contains);
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(38),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              'No demo stations match that search',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Try another city, state, area, or PIN code. The bundled catalog is representative and does not yet include every charger in India.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
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

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppTheme.brandGreen,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppTheme.brandGreen, blurRadius: 7)],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.brandLime,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFACC2B8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
