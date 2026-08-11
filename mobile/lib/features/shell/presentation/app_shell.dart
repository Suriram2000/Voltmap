import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../discovery/presentation/discovery_screen.dart';
import '../../discovery/presentation/add_charger_screen.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../map/presentation/map_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../trips/presentation/trip_planner_screen.dart';
import '../../../shared/state/app_state.dart';
import '../../../shared/widgets/registered_account_gate.dart';
import '../../../shared/widgets/site_footer.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int index = 0;

  static const screens = [
    DiscoveryScreen(),
    MapScreen(),
    TripPlannerScreen(),
    FavoritesScreen(),
    AddChargerScreen(),
    ProfileScreen(),
  ];

  static const destinations = [
    _Destination('Discover', Icons.explore_outlined, Icons.explore),
    _Destination('Map', Icons.map_outlined, Icons.map),
    _Destination('Trips', Icons.route_outlined, Icons.route),
    _Destination('Favorites', Icons.favorite_border, Icons.favorite),
    _Destination(
      'Add',
      Icons.add_location_alt_outlined,
      Icons.add_location_alt_rounded,
    ),
    _Destination('Profile', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final body = Column(
          children: [
            Expanded(child: IndexedStack(index: index, children: screens)),
            const SiteFooter(),
          ],
        );
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                _DesktopNavigation(
                  compact: constraints.maxWidth < 1140,
                  selectedIndex: index,
                  destinations: destinations,
                  onSelected: _selectDestination,
                ),
                Expanded(
                  child: ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: SafeArea(left: false, child: body),
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 24,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: NavigationBar(
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              selectedIndex: index,
              onDestinationSelected: _selectDestination,
              destinations: destinations
                  .map(
                    (destination) => NavigationDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: destination.label,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDestination(int value) async {
    final appState = ref.read(appStateProvider);
    final requiresRegisteredAccount = value == 3 || value == 4;
    if (requiresRegisteredAccount &&
        !await requireRegisteredAccount(
          context,
          appState,
          destinations[value].label,
        )) {
      return;
    }
    if (mounted) setState(() => index = value);
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.compact,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
  });

  final bool compact;
  final int selectedIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 92 : 252,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brandNavy, Color(0xFF0A2B21)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 18,
            22,
            compact ? 14 : 18,
            20,
          ),
          child: Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              _BrandLockup(compact: compact),
              const SizedBox(height: 34),
              for (var itemIndex = 0;
                  itemIndex < destinations.length;
                  itemIndex++) ...[
                _NavItem(
                  compact: compact,
                  destination: destinations[itemIndex],
                  position: itemIndex,
                  total: destinations.length,
                  selected: itemIndex == selectedIndex,
                  onTap: () => onSelected(itemIndex),
                ),
                const SizedBox(height: 8),
              ],
              const Spacer(),
              if (!compact)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.09),
                    ),
                  ),
                  child: const Row(
                    children: [
                      _LiveDot(),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Demo network online',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'India-wide demo coverage',
                              style: TextStyle(
                                color: Color(0xFF9FB7AD),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
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

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brandLime, AppTheme.brandGreen],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x5520C77A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.bolt_rounded, color: AppTheme.brandNavy),
    );
    if (compact) return mark;
    return Row(
      children: [
        mark,
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VoltMapEV',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Charge forward',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Color(0xFF9FB7AD), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.compact,
    required this.destination,
    required this.position,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final bool compact;
  final _Destination destination;
  final int position;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${destination.label} Tab ${position + 1} of $total',
      child: Tooltip(
        message: compact ? destination.label : '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 54,
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 16),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.brandGreen.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppTheme.brandGreen.withValues(alpha: 0.24)
                    : Colors.transparent,
              ),
            ),
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    color:
                        selected ? AppTheme.brandLime : const Color(0xFFA9BCB3),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 14),
                    Text(
                      destination.label,
                      style: TextStyle(
                        color:
                            selected ? Colors.white : const Color(0xFFC1D0C9),
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
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
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: AppTheme.brandGreen,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppTheme.brandGreen, blurRadius: 8)],
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
