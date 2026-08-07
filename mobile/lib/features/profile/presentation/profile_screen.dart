import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/state/app_state.dart';
import '../../modules/presentation/modules_screen.dart';
import '../../payments/presentation/payment_history_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Card(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.brandNavy, Color(0xFF0B3829)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.brandLime, AppTheme.brandGreen],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          _initials(appState.userName),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppTheme.brandNavy,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DRIVER PROFILE',
                              style: TextStyle(
                                color: AppTheme.brandLime,
                                fontSize: 10,
                                letterSpacing: 1.3,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              appState.userName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              appState.userEmail,
                              style: const TextStyle(color: Color(0xFFB8CEC4)),
                            ),
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
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.directions_car_filled_outlined),
                  ),
                  title: Text(appState.vehicleName),
                  subtitle: Text(
                    'Estimated range: ${appState.vehicleRangeKm.round()} km',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _editVehicle(context, appState),
                ),
              ),
              const SizedBox(height: 28),
              Text('Preferences',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      secondary: const Icon(Icons.notifications_outlined),
                      title: const Text('Charging notifications'),
                      subtitle: const Text('Session and saved-trip reminders'),
                      value: appState.notificationsEnabled,
                      onChanged: appState.setNotificationsEnabled,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
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
                      key: const Key('paymentHistoryTile'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: const Text('Payments & receipts'),
                      subtitle: Text(
                        appState.chargingReceipts.isEmpty
                            ? 'No demo charging payments yet'
                            : '${appState.chargingReceipts.length} saved demo receipt${appState.chargingReceipts.length == 1 ? '' : 's'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const PaymentHistoryScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      leading: const Icon(Icons.apps),
                      title: const Text('Enterprise roadmap'),
                      subtitle: const Text(
                        'Provider, fleet, payments, and roaming modules',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ModulesScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      leading: Icon(Icons.info_outline),
                      title: Text('VoltMap demo'),
                      subtitle: Text(
                        'Premium browser build • Version 1.3.0',
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
                Text(
                  'My vehicle',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Vehicle model'),
                ),
                const SizedBox(height: 18),
                Text(
                  'Estimated full-charge range: ${selectedRange.round()} km',
                ),
                Slider(
                  value: selectedRange,
                  min: 120,
                  max: 600,
                  divisions: 24,
                  label: '${selectedRange.round()} km',
                  onChanged: (value) =>
                      setSheetState(() => selectedRange = value),
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
