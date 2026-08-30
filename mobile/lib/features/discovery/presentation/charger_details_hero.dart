import 'package:flutter/material.dart';

class ChargerDetailsHero extends StatelessWidget {
  const ChargerDetailsHero({
    super.key,
    required this.stationName,
    required this.statusLabel,
    required this.statusPositive,
    this.onFavorite,
    this.isFavorite = false,
    this.onShare,
  });

  static const assetPath = 'assets/images/charger_details_hero.png';

  final String stationName;
  final String statusLabel;
  final bool statusPositive;
  final VoidCallback? onFavorite;
  final bool isFavorite;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 24 : 30),
          child: SizedBox(
            key: const Key('chargerDetailsPhoto'),
            height: compact ? 232 : 330,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.2, 0),
                  semanticLabel:
                      'Representative electric vehicle fast charger photograph',
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x5C001A15),
                        Colors.transparent,
                        Color(0xC9002019),
                      ],
                      stops: [0, 0.48, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: compact && (onFavorite != null || onShare != null)
                      ? 70
                      : 14,
                  child: const _PhotoPill(
                    icon: Icons.photo_camera_outlined,
                    label: 'Representative station image',
                  ),
                ),
                if (onFavorite != null || onShare != null)
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Row(
                      children: [
                        if (onFavorite != null)
                          _HeroAction(
                            tooltip: isFavorite
                                ? 'Remove from favorites'
                                : 'Add to favorites',
                            icon: isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            onPressed: onFavorite!,
                            iconColor: isFavorite
                                ? const Color(0xFFE84A67)
                                : const Color(0xFF073D34),
                          ),
                        if (onFavorite != null && onShare != null)
                          const SizedBox(width: 8),
                        if (onShare != null)
                          _HeroAction(
                            tooltip: 'Share charger',
                            icon: Icons.ios_share_rounded,
                            onPressed: onShare!,
                          ),
                      ],
                    ),
                  ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 17,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          stationName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusPill(
                        label: statusLabel,
                        positive: statusPositive,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconColor = const Color(0xFF073D34),
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      elevation: 4,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        color: iconColor,
        icon: Icon(icon),
      ),
    );
  }
}

class _PhotoPill extends StatelessWidget {
  const _PhotoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDE062D26),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: positive ? const Color(0xFFE2FAE9) : const Color(0xFFF2F6F4),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: positive
                    ? const Color(0xFF16A45D)
                    : const Color(0xFF66756F),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF073D34),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
