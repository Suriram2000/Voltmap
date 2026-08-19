import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_environment.dart';
import '../../../shared/models/charging_receipt.dart';
import '../../../shared/models/charging_station.dart';
import '../../../shared/state/app_state.dart';
import '../../../shared/widgets/registered_account_gate.dart';
import '../../payments/presentation/charging_checkout_screen.dart';
import '../../payments/presentation/charging_receipt_screen.dart';
import 'station_feedback_dialog.dart';

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
              Text(
                'Choose the right charger',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Check connector, speed, price and availability before you arrive.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Container(
                key: const Key('chargerDetailsHero'),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF073D34), Color(0xFF061B31)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 76,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Icon(
                        Icons.ev_station_rounded,
                        size: 46,
                        color: Color(0xFF62E98A),
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
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            station.network,
                            style: const TextStyle(color: Color(0xFFB8CED6)),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _HeroBadge(
                                icon: station.available
                                    ? Icons.check_circle_outline
                                    : Icons.power_off_rounded,
                                label: station.available
                                    ? station.availabilityIsLive
                                        ? 'Available now'
                                        : 'Listed • not live'
                                    : 'Unavailable',
                                positive: station.available,
                              ),
                              _HeroBadge(
                                icon: Icons.star_rounded,
                                label:
                                    '${station.rating.toStringAsFixed(1)} rating',
                                positive: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                key: const Key('stationDataTransparencyBanner'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.fact_check_outlined, color: colors.tertiary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Check live details before travel',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${station.dataSource} • ${station.dataUpdatedLabel}. '
                            'Availability, rating, distance, and price are not live operator data. '
                            'Confirm the charger status and final tariff with the operator.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 520 ? 2 : 4;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 10) / columns;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MetricTile(
                          width: width,
                          label: 'Charging speed',
                          value: '${station.powerKw} kW',
                          icon: Icons.bolt_rounded,
                        ),
                        _MetricTile(
                          width: width,
                          label: 'Connector',
                          value: station.connectorTypes.first,
                          icon: Icons.electrical_services_rounded,
                        ),
                        _MetricTile(
                          width: width,
                          label: station.pricingIsLive
                              ? 'Price'
                              : 'Estimated price',
                          value:
                              '₹${station.pricePerKwh.toStringAsFixed(1)}/kWh',
                          icon: Icons.currency_rupee_rounded,
                        ),
                        _MetricTile(
                          width: width,
                          label: station.availabilityIsLive
                              ? 'Availability'
                              : 'Listed ports',
                          value:
                              '${station.availableConnectors}/${station.totalConnectors}',
                          icon: Icons.power_rounded,
                        ),
                      ],
                    );
                  },
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
                      'Connector details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: station.connectorTypes
                          .map(
                            (connector) => Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer.withValues(
                                  alpha: 0.55,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.electrical_services_rounded,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        connector,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text('${station.powerKw} kW max power'),
                                    ],
                                  ),
                                ],
                              ),
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
              const SizedBox(height: 16),
              TextButton.icon(
                key: const Key('reportStationCorrectionButton'),
                onPressed: () => _reportCorrection(context),
                icon: const Icon(Icons.report_outlined),
                label: const Text('Report incorrect station information'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDirections(context),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Navigate'),
                    ),
                  ),
                  if (AppRuntimeConfig.canOfferChargingPayment) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('openCheckoutButton'),
                        onPressed: station.available
                            ? () => _startSession(context)
                            : null,
                        icon: const Icon(Icons.bolt_rounded),
                        label: Text(
                          station.available ? 'Charge & pay' : 'Unavailable',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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

  Future<void> _reportCorrection(BuildContext context) async {
    await showStationFeedbackDialog(
      context: context,
      stationId: station.id,
      stationName: station.name,
      operatorName: station.network,
      address: station.formattedAddress,
      latitude: station.latitude,
      longitude: station.longitude,
      sourceNames: [station.dataSource],
    );
  }

  Future<void> _startSession(BuildContext context) async {
    final receipt = await Navigator.of(context).push<ChargingReceipt>(
      MaterialPageRoute<ChargingReceipt>(
        builder: (_) => ChargingCheckoutScreen(station: station),
      ),
    );
    if (!context.mounted || receipt == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChargingReceiptScreen(
          receipt: receipt,
          station: station,
        ),
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

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
    required this.positive,
  });

  final IconData icon;
  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: (positive ? const Color(0xFF62E98A) : const Color(0xFFFF8B8B))
              .withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  positive ? const Color(0xFF62E98A) : const Color(0xFFFF8B8B),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
