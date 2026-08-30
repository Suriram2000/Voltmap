import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_environment.dart';
import '../../../shared/models/charging_station.dart';
import '../../payments/presentation/production_charging_checkout_screen.dart';
import '../data/official_charger_station.dart';
import 'station_feedback_dialog.dart';

class OfficialChargerDetailsScreen extends StatelessWidget {
  const OfficialChargerDetailsScreen({
    super.key,
    required this.station,
    this.distanceKm,
    this.distanceContext = 'from the planned route',
  });

  final OfficialChargerStation station;
  final double? distanceKm;
  final String distanceContext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxPowerKw = station.connectors
        .map((connector) => connector.ratingKw)
        .whereType<double>()
        .fold<double?>(null, (current, value) {
      if (current == null || value > current) return value;
      return current;
    });
    final connectorCount = station.connectors.fold<int>(
      0,
      (sum, connector) => sum + (connector.count ?? 0),
    );
    final hasLiveAvailability = station.hasLiveAvailability;
    final availableNow =
        hasLiveAvailability && (station.availableConnectors ?? 0) > 0;

    return Scaffold(
      key: const Key('officialChargerDetailsScreen'),
      backgroundColor: const Color(0xFFF4FBF8),
      appBar: AppBar(
        title: const Text(
          'Charger details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF032A25),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Report station information',
            onPressed: () => _reportCorrection(context),
            icon: const Icon(Icons.outlined_flag_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
            children: [
              Text(
                'Choose the right charger',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF032A25),
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Check connector, power, source and status before you arrive.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 18),
              Container(
                key: const Key('officialChargerDetailsHero'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF062F2A),
                      Color(0xFF075C4A),
                      Color(0xFF061B31),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF7BF39E).withValues(alpha: 0.3),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44052C25),
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 158,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.16),
                            Colors.white.withValues(alpha: 0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: 20,
                            bottom: 22,
                            child: Icon(
                              Icons.electric_car_rounded,
                              size: 72,
                              color: Color(0xFFD9FFF0),
                            ),
                          ),
                          Positioned(
                            right: 24,
                            bottom: 19,
                            child: Icon(
                              Icons.ev_station_rounded,
                              size: 96,
                              color: Colors.white,
                            ),
                          ),
                          Positioned(
                            right: 53,
                            top: 23,
                            child: Icon(
                              Icons.bolt_rounded,
                              size: 44,
                              color: Color(0xFFA6FF62),
                            ),
                          ),
                          Positioned(
                            left: 18,
                            top: 16,
                            child: _HeroVerifiedPill(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      station.displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.35,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      station.ownership.isEmpty
                          ? station.operatorName
                          : '${station.operatorName} · ${station.ownership}',
                      style: const TextStyle(color: Color(0xFFB8CED6)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusBadge(
                          label: hasLiveAvailability
                              ? availableNow
                                  ? '${station.availableConnectors}/${station.totalConnectors} available now'
                                  : 'Busy or offline'
                              : 'Published station · verify status',
                          positive: hasLiveAvailability && availableNow,
                        ),
                        if (distanceKm != null) ...[
                          _StatusBadge(
                            label: '${distanceKm!.toStringAsFixed(1)} km away',
                            positive: false,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                key: const Key('officialStationDataTransparencyBanner'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F8EF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFCDEBDA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.fact_check_outlined,
                      color: Color(0xFF0A8D50),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasLiveAvailability
                            ? 'Fresh operator-verified availability is shown. Confirm access and final tariff before travel.'
                            : 'This is a published location record, not a live availability claim. Confirm working status, access and final tariff with the operator before travel.',
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
                          label: 'Maximum power',
                          value: maxPowerKw == null
                              ? 'Not published'
                              : '${_formatNumber(maxPowerKw)} kW',
                          icon: Icons.bolt_rounded,
                        ),
                        _MetricTile(
                          width: width,
                          label: 'Connector types',
                          value: station.connectors.isEmpty
                              ? 'Not published'
                              : '${station.connectors.length}',
                          icon: Icons.electrical_services_rounded,
                        ),
                        _MetricTile(
                          width: width,
                          label: 'Listed ports',
                          value: connectorCount == 0
                              ? 'Not published'
                              : '$connectorCount',
                          icon: Icons.power_rounded,
                        ),
                        _MetricTile(
                          width: width,
                          label: station.hasLivePrice ? 'Live price' : 'Price',
                          value: station.hasLivePrice
                              ? '₹${station.pricePerKwh!.toStringAsFixed(2)}/kWh'
                              : 'Verify tariff',
                          icon: Icons.currency_rupee_rounded,
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      station.address.isEmpty
                          ? station.areaLabel
                          : station.address,
                    ),
                    if (station.postcodes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('PIN: ${station.postcodes.join(', ')}'),
                    ],
                    if (distanceKm != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${distanceKm!.toStringAsFixed(1)} km $distanceContext',
                      ),
                    ],
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    if (station.connectors.isEmpty)
                      const Text('Connector details were not published.')
                    else
                      for (final connector in station.connectors)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.electrical_services_rounded),
                          title: Text(connector.type),
                          subtitle: Text(connector.label),
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
                      'Data source',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(station.sourceLabel),
                    if (station.liveStatusUpdatedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Status updated: ${station.liveStatusUpdatedAt!.toLocal()}',
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${station.latitude.toStringAsFixed(6)}, ${station.longitude.toStringAsFixed(6)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('reportOfficialStationCorrectionButton'),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final verifyButton = OutlinedButton.icon(
                    onPressed: () => _verifyOnGoogleMaps(context),
                    icon: const Icon(Icons.travel_explore_rounded),
                    label: const Text('Verify on Google Maps'),
                  );
                  final navigateButton = FilledButton.icon(
                    key: const Key('navigateToOfficialStationButton'),
                    onPressed: () => _openDirections(context),
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Navigate'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF079653),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                  final showCharge = AppRuntimeConfig.canOfferChargingPayment;
                  if (constraints.maxWidth < 520) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        verifyButton,
                        const SizedBox(height: 8),
                        navigateButton,
                        if (showCharge) ...[
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            key: const Key('chargeOfficialStationButton'),
                            onPressed: () => _openSecureCheckout(context),
                            icon: const Icon(Icons.bolt_rounded),
                            label: const Text('Charge & pay'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF032A25),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: verifyButton),
                      const SizedBox(width: 12),
                      Expanded(child: navigateButton),
                      if (showCharge) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('chargeOfficialStationButton'),
                            onPressed: () => _openSecureCheckout(context),
                            icon: const Icon(Icons.bolt_rounded),
                            label: const Text('Charge & pay'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDirections(BuildContext context) async {
    await _launch(
      context,
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '${station.latitude},${station.longitude}',
      }),
    );
  }

  Future<void> _verifyOnGoogleMaps(BuildContext context) async {
    await _launch(
      context,
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query':
            '${station.operatorName} EV charging station ${station.latitude},${station.longitude}',
      }),
    );
  }

  Future<void> _openSecureCheckout(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductionChargingCheckoutScreen(
          station: _asChargingStation(),
        ),
      ),
    );
  }

  ChargingStation _asChargingStation() {
    final publishedPower = station.connectors
        .map((connector) => connector.ratingKw)
        .whereType<double>()
        .fold<double>(0, (current, value) => value > current ? value : current);
    final publishedPorts = station.connectors.fold<int>(
      0,
      (total, connector) => total + (connector.count ?? 0),
    );
    final connectorTypes = station.connectors
        .map((connector) => connector.type.trim())
        .where((connector) => connector.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return ChargingStation(
      id: station.feedbackStationId,
      name: station.displayName,
      network: station.operatorName,
      address: station.address.isEmpty ? station.areaLabel : station.address,
      city: station.city,
      state: station.state,
      postalCode: station.postcodes.isEmpty ? '' : station.postcodes.first,
      distanceKm: distanceKm ?? 0,
      powerKw: publishedPower.round(),
      availableConnectors:
          station.hasLiveAvailability ? station.availableConnectors! : 0,
      totalConnectors: station.hasLiveAvailability
          ? station.totalConnectors!
          : publishedPorts,
      latitude: station.latitude,
      longitude: station.longitude,
      connectorTypes: connectorTypes.isEmpty
          ? const ['Connector details pending']
          : connectorTypes,
      pricePerKwh: station.hasLivePrice ? station.pricePerKwh! : 0,
      rating: 0,
      amenities: const [],
      dataSource: station.sourceLabel,
      dataUpdatedLabel: station.liveStatusUpdatedAt == null
          ? 'Published inventory — not live'
          : 'Live status updated ${station.liveStatusUpdatedAt!.toLocal()}',
      availabilityIsLive: station.hasLiveAvailability,
      pricingIsLive: station.hasLivePrice,
    );
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  Future<void> _reportCorrection(BuildContext context) async {
    await showStationFeedbackDialog(
      context: context,
      stationId: station.feedbackStationId,
      stationName: station.displayName,
      operatorName: station.operatorName,
      address: station.address.isEmpty ? station.areaLabel : station.address,
      latitude: station.latitude,
      longitude: station.longitude,
      sourceNames: station.sourceNames,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDFECE7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10052B24),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
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
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3FAF7), Color(0xFFEAF7F0)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCECE5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F7E9),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF078B4E), size: 19),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF062D26),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroVerifiedPill extends StatelessWidget {
  const _HeroVerifiedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF08231F).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 14, color: Color(0xFFA6FF62)),
          SizedBox(width: 5),
          Text(
            'VoltMapEV station record',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: positive
            ? const Color(0xFF1D6F4A)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}
