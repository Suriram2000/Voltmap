import 'package:flutter/material.dart';
import '../data/sample_stations.dart';

class DiscoveryScreen extends StatelessWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VoltMap')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Find the right charger, faster.', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const SearchBar(hintText: 'Search station, city, highway, or network', leading: Icon(Icons.search)),
          const SizedBox(height: 24),
          const Text('Nearby chargers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (final station in sampleStations)
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.ev_station)),
                title: Text(station.name),
                subtitle: Text('${station.network} • ${station.powerKw} kW • ${station.distanceKm} km'),
                trailing: Text('${station.availableConnectors}/${station.totalConnectors}'),
              ),
            ),
        ],
      ),
    );
  }
}
