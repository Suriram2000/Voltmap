import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/place_suggestion.dart';
import 'live_charger_view.dart';

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
    final embeddedUri = buildLiveChargerMapUri(center: center);

    return Scaffold(
      appBar: AppBar(
        title: Text('Live chargers near $locationLabel'),
        actions: [
          IconButton(
            key: const Key('verifyLiveResultsOnGoogleButton'),
            tooltip: 'Verify on Google Maps',
            onPressed: () => _openGoogle(context, locationLabel),
            icon: const Icon(Icons.travel_explore_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
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
                            : 'Centered on ${center!.displayName}. Tap a map marker for the station information available from the source.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
                            colors: [
                              AppTheme.brandLime,
                              AppTheme.brandGreen,
                            ],
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
                'Community data can be incomplete or stale. Confirm connector, working status, access, and price with the operator or Google Maps before travel.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openGoogle(
    BuildContext context,
    String location,
  ) async {
    final url = Uri.https(
      'www.google.com',
      '/maps/search/',
      {'api': '1', 'query': 'EV charging stations near $location, India'},
    );
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
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
