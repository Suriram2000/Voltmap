import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/charging_station.dart';

class StationCard extends StatelessWidget {
  const StationCard({
    super.key,
    required this.station,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTap,
  });

  final ChargingStation station;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final occupancy = station.totalConnectors == 0
        ? 0.0
        : station.availableConnectors / station.totalConnectors;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: station.available ? colors.outlineVariant : colors.error,
          width: station.available ? 1 : 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 244),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: station.available
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFCBF9D8),
                                  Color(0xFF8FEAAF),
                                ],
                              )
                            : null,
                        color: station.available ? null : colors.errorContainer,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        station.isFast
                            ? Icons.bolt_rounded
                            : Icons.ev_station_rounded,
                        color: station.available
                            ? const Color(0xFF075D3E)
                            : colors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.network.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            station.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isFavorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      onPressed: onFavorite,
                      style: IconButton.styleFrom(
                        backgroundColor: isFavorite
                            ? colors.errorContainer
                            : colors.surfaceContainerLow,
                      ),
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite ? colors.error : colors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 38,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 17,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          station.formattedAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: ExcludeSemantics(
                          child: LinearProgressIndicator(
                            value: occupancy,
                            minHeight: 7,
                            backgroundColor: colors.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(
                              station.available
                                  ? AppTheme.brandGreen
                                  : colors.error,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _AvailabilityBadge(station: station),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        icon: Icons.bolt_rounded,
                        value: '${station.powerKw} kW',
                        label: 'Power',
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        icon: Icons.currency_rupee_rounded,
                        value: station.pricePerKwh.toStringAsFixed(1),
                        label: 'per kWh',
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        icon: Icons.near_me_outlined,
                        value: '${station.distanceKm.toStringAsFixed(1)} km',
                        label: 'Distance',
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        icon: Icons.star_rounded,
                        value: station.rating.toStringAsFixed(1),
                        label: 'Rating',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.station});

  final ChargingStation station;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            station.available ? const Color(0xFFDFF8E8) : colors.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        station.available
            ? '${station.availableConnectors} available'
            : 'NOT WORKING / UNAVAILABLE',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: station.available
                  ? const Color(0xFF09623F)
                  : colors.onErrorContainer,
              fontWeight: FontWeight.w900,
              letterSpacing: station.available ? 0 : 0.35,
            ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: colors.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}
