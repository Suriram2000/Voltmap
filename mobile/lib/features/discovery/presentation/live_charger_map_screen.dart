import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/place_suggestion.dart';
import 'live_charger_view.dart';
import 'official_charger_results_view.dart';

class LiveChargerMapScreen extends StatelessWidget {
  const LiveChargerMapScreen({
    super.key,
    required this.query,
    this.center,
  });

  final String query;
  final PlaceSuggestion? center;

  @override
  Widget build(BuildContext context) {
    final locationLabel =
        center?.primaryText ?? (query.trim().isEmpty ? 'India' : query.trim());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Chargers near $locationLabel'),
          bottom: const TabBar(
            tabs: [
              Tab(
                key: Key('officialChargerListTab'),
                icon: Icon(Icons.format_list_bulleted_rounded),
                text: 'Official list',
              ),
              Tab(
                key: Key('communityChargerMapTab'),
                icon: Icon(Icons.map_rounded),
                text: 'Community map',
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              OfficialChargerResultsView(query: query, center: center),
              _CommunityChargerMap(center: center),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityChargerMap extends StatelessWidget {
  const _CommunityChargerMap({required this.center});

  final PlaceSuggestion? center;

  @override
  Widget build(BuildContext context) {
    final embeddedUri = buildLiveChargerMapUri(center: center);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final description = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDFF8E8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LiveDot(),
                            SizedBox(width: 7),
                            Text(
                              'LIVE COMMUNITY MAP',
                              style: TextStyle(
                                color: Color(0xFF09623F),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        'Open Charge Map + OpenStreetMap',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    center == null
                        ? 'Explore community-maintained charging locations across India without leaving VoltMapEV.'
                        : 'Centered on ${center!.displayName}. Tap a marker for the details supplied by the community source.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              );
              if (compact) return description;
              return Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.brandLime, AppTheme.brandGreen],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.ev_station_rounded,
                      color: AppTheme.brandNavy,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: description),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: LiveChargerPlatformView(uri: embeddedUri),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          color: Theme.of(context).colorScheme.surface,
          child: Text(
            'Community data can be incomplete or stale. Compare it with the Official list tab and confirm connector, working status, access, and price with the operator before travel.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

Uri buildLiveChargerMapUri({PlaceSuggestion? center}) {
  final parameters = <String, String>{'mode': 'embedded'};
  if (center == null) {
    parameters.addAll({
      'latitude': '20.5937',
      'longitude': '78.9629',
      'zoom': '5',
    });
  } else {
    parameters.addAll({
      'latitude': center.latitude.toStringAsFixed(6),
      'longitude': center.longitude.toStringAsFixed(6),
      'zoom': center.type == 'postcode' ? '13' : '12',
    });
  }
  return Uri.https('map.openchargemap.io', '/', parameters);
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: AppTheme.brandGreen,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppTheme.brandGreen, blurRadius: 6)],
      ),
    );
  }
}
