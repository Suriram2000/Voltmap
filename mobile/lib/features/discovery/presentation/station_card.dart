import 'package:flutter/material.dart';

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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: station.available
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.ev_station,
                  color: station.available
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            station.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: isFavorite
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                          onPressed: onFavorite,
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? colors.error : null,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      station.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _InfoPill(icon: Icons.bolt, label: '${station.powerKw} kW'),
                        _InfoPill(
                          icon: Icons.near_me,
                          label: '${station.distanceKm.toStringAsFixed(1)} km',
                        ),
                        _InfoPill(
                          icon: Icons.star,
                          label: station.rating.toStringAsFixed(1),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: station.available
                                ? colors.primaryContainer
                                : colors.errorContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            station.available
                                ? '${station.availableConnectors} available'
                                : 'Currently full',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: station.available
                                      ? colors.onPrimaryContainer
                                      : colors.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
