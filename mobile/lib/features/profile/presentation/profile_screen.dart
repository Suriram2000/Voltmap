import 'package:flutter/material.dart';
import '../../modules/presentation/modules_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          const CircleAvatar(radius: 42, child: Icon(Icons.person, size: 42)),
          const ListTile(leading: Icon(Icons.directions_car), title: Text('My Vehicle'), subtitle: Text('Not configured')),
          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text('Enterprise Modules'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModulesScreen())),
          ),
        ],
      ),
    );
  }
}
