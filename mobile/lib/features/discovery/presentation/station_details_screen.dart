import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/charging_receipt.dart';
import '../../../shared/models/charging_station.dart';
import '../../../shared/state/app_state.dart';
import '../../../shared/widgets/registered_account_gate.dart';
import '../../payments/presentation/charging_checkout_screen.dart';

class StationDetailsScreen extends ConsumerWidget {
  const StationDetailsScreen({super.key, required this.station});

  final ChargingStation station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final isFavorite = appState.isFavorite(station.id);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Charger details'),
        actions: [
          IconButton(
            tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () async {
              if (await requireRegisteredAccount(
                context,
                appState,
                'Favorites',
              )) {
                await appState.toggleFavorite(station.id);
              }
            },
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              if (!station.available) ...[
                Container(
                  key: const Key('unavailableStationBanner'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.error, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.power_off_rounded, color: colors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'NOT WORKING / UNAVAILABLE\nDo not travel to this charger for an active session.',
                          style: TextStyle(
                            color: colors.error,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.ev_station,
                      size: 32,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.name,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(station.network),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 18, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text('${station.rating.toStringAsFixed(1)} rating'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Available',
                        value:
                            '${station.availableConnectors}/${station.totalConnectors}',
                        icon: Icons.power,
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: 'Up to',
                        value: '${station.powerKw} kW',
                        icon: Icons.bolt,
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        label: 'Price',
                        value: '₹${station.pricePerKwh.toStringAsFixed(1)}/kWh',
                        icon: Icons.currency_rupee,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(station.formattedAddress),
                    const SizedBox(height: 6),
                    Text(
                      '${station.distanceKm.toStringAsFixed(1)} km from your location',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connectors',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: station.connectorTypes
                          .map(
                            (connector) => Chip(
                              avatar: const Icon(
                                Icons.electrical_services,
                                size: 18,
                              ),
                              label: Text(connector),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amenities',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: station.amenities
                          .map((amenity) => Chip(label: Text(amenity)))
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDirections(context),
                      icon: const Icon(Icons.navigation),
                      label: const Text('Directions'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('openCheckoutButton'),
                      onPressed: station.available
                          ? () async {
                              if (await requireRegisteredAccount(
                                context,
                                appState,
                                'Payments',
                              )) {
                                await _startSession(context);
                              }
                            }
                          : null,
                      icon: const Icon(Icons.ev_station_rounded),
                      label: Text(
                        station.available ? 'Set up charging' : 'Unavailable',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDirections(BuildContext context) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${station.latitude},${station.longitude}',
    });
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open directions.')),
      );
    }
  }

  Future<void> _startSession(BuildContext context) async {
    final receipt = await Navigator.of(context).push<ChargingReceipt>(
      MaterialPageRoute<ChargingReceipt>(
        builder: (_) => ChargingCheckoutScreen(station: station),
      ),
    );
    if (!context.mounted || receipt == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.bolt, size: 40),
        title: const Text('Charging session complete'),
        content: Text(
          '${receipt.energyKwh.toStringAsFixed(2)} kWh was delivered through '
          '${receipt.connectorType} at ${station.name}.\n\n'
          'Final payment: ₹${receipt.amount.toStringAsFixed(2)}\n'
          'Method: ${receipt.paymentMethod}\nReceipt: ${receipt.id}',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
