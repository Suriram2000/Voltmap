import 'package:flutter/material.dart';

class TripPlannerScreen extends StatelessWidget {
  const TripPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Planner')),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: 'Starting point')),
            SizedBox(height: 14),
            TextField(decoration: InputDecoration(labelText: 'Destination')),
            SizedBox(height: 24),
            Text('Real routing requires Google Routes API or another routing backend.'),
          ],
        ),
      ),
    );
  }
}
