import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/app_state.dart';
import '../../modules/presentation/modules_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    child: Text(
                      _initials(appState.userName),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appState.userName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(appState.userEmail),
                        if (!appState.isReady) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: () => _editProfile(context, appState),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: const CircleAvatar(child: Icon(Icons.directions_car)),
              title: Text(appState.vehicleName),
              subtitle: Text('Estimated range: ${appState.vehicleRangeKm.round()} km'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _editVehicle(context, appState),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Preferences',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Charging notifications'),
                  subtitle: const Text('Session and saved-trip reminders'),
                  value: appState.notificationsEnabled,
                  onChanged: appState.setNotificationsEnabled,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark mode'),
                  subtitle: const Text('Use a darker color theme'),
                  value: appState.darkMode,
                  onChanged: appState.setDarkMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.apps),
                  title: const Text('Enterprise roadmap'),
                  subtitle: const Text('Provider, fleet, payments, and roaming modules'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ModulesScreen()),
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('VoltMap demo'),
                  subtitle: Text('Offline-first browser build • Version 1.1'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'VM';
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }

  Future<void> _editProfile(BuildContext context, AppState appState) async {
    final nameController = TextEditingController(text: appState.userName);
    final emailController = TextEditingController(text: appState.userEmail);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit profile'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Display name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  !emailController.text.contains('@')) {
                return;
              }
              appState.updateProfile(
                name: nameController.text,
                email: emailController.text,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    emailController.dispose();
  }

  Future<void> _editVehicle(BuildContext context, AppState appState) async {
    final nameController = TextEditingController(text: appState.vehicleName);
    var selectedRange = appState.vehicleRangeKm;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My vehicle', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Vehicle model'),
                ),
                const SizedBox(height: 18),
                Text('Estimated full-charge range: ${selectedRange.round()} km'),
                Slider(
                  value: selectedRange,
                  min: 120,
                  max: 600,
                  divisions: 24,
                  label: '${selectedRange.round()} km',
                  onChanged: (value) => setSheetState(() => selectedRange = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      if (nameController.text.trim().isEmpty) return;
                      appState.updateVehicle(
                        name: nameController.text,
                        rangeKm: selectedRange,
                      );
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Save vehicle'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    nameController.dispose();
  }
}
