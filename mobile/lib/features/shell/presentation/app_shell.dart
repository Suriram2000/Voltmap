import 'package:flutter/material.dart';
import '../../discovery/presentation/discovery_screen.dart';
import '../../favorites/presentation/favorites_screen.dart';
import '../../map/presentation/map_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../trips/presentation/trip_planner_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  static const screens = [
    DiscoveryScreen(),
    MapScreen(),
    TripPlannerScreen(),
    FavoritesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final body = IndexedStack(index: index, children: screens);
        if (wide) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    extended: constraints.maxWidth >= 1180,
                    selectedIndex: index,
                    onDestinationSelected: _selectDestination,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Icon(
                        Icons.electric_bolt,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.search),
                        label: Text('Discover'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.map),
                        label: Text('Map'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.route),
                        label: Text('Trips'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.favorite),
                        label: Text('Favorites'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person),
                        label: Text('Profile'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: _selectDestination,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.search), label: 'Discover'),
              NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
              NavigationDestination(icon: Icon(Icons.route), label: 'Trips'),
              NavigationDestination(icon: Icon(Icons.favorite), label: 'Favorites'),
              NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        );
      },
    );
  }

  void _selectDestination(int value) => setState(() => index = value);
}
