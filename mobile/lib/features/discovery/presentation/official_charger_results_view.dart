import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/place_suggestion.dart';
import '../data/official_charger_search_service.dart';
import '../data/official_charger_station.dart';
import 'official_charger_details_screen.dart';

class OfficialChargerResultsView extends StatefulWidget {
  const OfficialChargerResultsView({
    super.key,
    required this.query,
    this.center,
    this.embedded = false,
  });

  final String query;
  final PlaceSuggestion? center;
  final bool embedded;

  @override
  State<OfficialChargerResultsView> createState() =>
      _OfficialChargerResultsViewState();
}

class _OfficialChargerResultsViewState
    extends State<OfficialChargerResultsView> {
  static const _resultPageSize = 15;
  final _service = const OfficialChargerSearchService();
  late Future<OfficialChargerSearchResult> _result;
  int _visibleCount = _resultPageSize;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(covariant OfficialChargerResultsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query ||
        oldWidget.center?.identity != widget.center?.identity) {
      _visibleCount = _resultPageSize;
      _search();
    }
  }

  void _search() {
    _result = _service.search(query: widget.query, center: widget.center);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OfficialChargerSearchResult>(
      future: _result,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('Loading official charger records...'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return _LoadError(onRetry: () => setState(_search));
        }

        final result = snapshot.requireData;
        if (widget.embedded) {
          final visibleCount =
              _visibleCount.clamp(0, result.matches.length).toInt();
          final remaining = result.matches.length - visibleCount;
          return Column(
            key: const Key('embeddedOfficialChargerList'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ResultsHeader(
                result: result,
                onVerify: () => _openGoogleMaps(context),
              ),
              for (var index = 0; index < visibleCount; index++)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _OfficialStationCard(
                    match: result.matches[index],
                    onTap: () => _openStationDetails(result.matches[index]),
                  ),
                ),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: OutlinedButton.icon(
                    key: const Key('showMoreOfficialChargersButton'),
                    onPressed: () => setState(() {
                      _visibleCount = (_visibleCount + _resultPageSize)
                          .clamp(0, result.matches.length)
                          .toInt();
                    }),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text('Show more chargers ($remaining remaining)'),
                  ),
                ),
            ],
          );
        }
        return ListView.builder(
          key: const PageStorageKey('officialChargerResultsList'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          itemCount: result.matches.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _ResultsHeader(
                result: result,
                onVerify: () => _openGoogleMaps(context),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _OfficialStationCard(
                match: result.matches[index - 1],
                onTap: () => _openStationDetails(result.matches[index - 1]),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openGoogleMaps(BuildContext context) async {
    final opened = await launchUrl(
      buildGoogleChargerVerificationUri(
        query: widget.query,
        center: widget.center,
      ),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  void _openStationDetails(OfficialChargerMatch match) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OfficialChargerDetailsScreen(
          station: match.station,
          distanceKm: match.distanceKm,
          distanceContext: 'from the searched location',
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.result, required this.onVerify});

  final OfficialChargerSearchResult result;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final date = result.asOf;
    final dateLabel = '${date.day.toString().padLeft(2, '0')} '
        '${_monthNames[date.month - 1]} ${date.year}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE9FCE9), Color(0xFFF8FFF1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB9E6C5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, color: AppTheme.brandGreen),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'OFFICIAL BEE STATION LIST',
                  style: TextStyle(
                    color: AppTheme.brandNavy,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${result.matches.length} stations found within '
            '${result.radiusKm.toStringAsFixed(0)} km',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.brandNavy,
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (result.exactPostcodeCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${result.exactPostcodeCount} match the searched PIN exactly; '
              'nearby stations follow by distance.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Government of India data updated $dateLabel. This is an official '
            'location inventory, not live availability; confirm working status '
            'and access with the operator before travel.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('verifyLiveResultsOnGoogleButton'),
              onPressed: onVerify,
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text('Verify on Google Maps'),
            ),
          ),
        ],
      ),
    );
  }
}

Uri buildGoogleChargerVerificationUri({
  required String query,
  PlaceSuggestion? center,
}) {
  final location = center?.primaryText.trim().isNotEmpty == true
      ? center!.primaryText.trim()
      : query.trim();
  return Uri.https(
    'www.google.com',
    '/maps/search/',
    {
      'api': '1',
      'query':
          'EV charging stations near ${location.isEmpty ? 'India' : location}, India',
    },
  );
}

class _OfficialStationCard extends StatelessWidget {
  const _OfficialStationCard({required this.match, required this.onTap});

  final OfficialChargerMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final station = match.station;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('officialStationCard_${station.feedbackStationId}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F7E8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.ev_station_rounded,
                      color: AppTheme.brandGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.displayName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          station.areaLabel,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (match.distanceKm != null)
                    _DistanceBadge(distanceKm: match.distanceKm!),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 13),
              Text(station.address),
              if (match.exactPostcode) ...[
                const SizedBox(height: 10),
                const _ExactPinBadge(),
              ],
              if (station.connectors.isNotEmpty) ...[
                const SizedBox(height: 13),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final connectors = station.connectors
                        .map(
                          (connector) => _ConnectorBadge(
                            label: connector.label,
                            expanded: constraints.maxWidth < 480,
                          ),
                        )
                        .toList(growable: false);
                    if (constraints.maxWidth < 480) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: connectors
                            .map(
                              (connector) => Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: connector,
                              ),
                            )
                            .toList(growable: false),
                      );
                    }
                    return Wrap(
                        spacing: 7, runSpacing: 7, children: connectors);
                  },
                ),
              ],
              const SizedBox(height: 10),
              Text(
                '${station.ownership.isEmpty ? 'Operator' : station.ownership} - '
                '${station.latitude.toStringAsFixed(6)}, '
                '${station.longitude.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View charger details',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.brandGreen,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppTheme.brandGreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectorBadge extends StatelessWidget {
  const _ConnectorBadge({required this.label, required this.expanded});

  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expanded ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          const Icon(Icons.electrical_services, size: 16),
          const SizedBox(width: 7),
          if (expanded) Expanded(child: Text(label)) else Text(label),
        ],
      ),
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({required this.distanceKm});

  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${distanceKm.toStringAsFixed(1)} km',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _ExactPinBadge extends StatelessWidget {
  const _ExactPinBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFDFF8E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'EXACT PIN MATCH',
        style: TextStyle(
          color: Color(0xFF09623F),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            const Text('Official charger records could not be loaded.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

const _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
