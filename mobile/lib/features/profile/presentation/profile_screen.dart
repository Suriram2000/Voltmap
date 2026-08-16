import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/state/app_state.dart';
import '../../about/presentation/about_screen.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../install/presentation/install_app_screen.dart';
import '../../modules/presentation/modules_screen.dart';
import '../../payments/presentation/payment_history_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    if (!appState.isRegisteredAccount) {
      return _buildGuestProfile(context);
    }
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
                              appState.userIdentifier,
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
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_done_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your saved workspace',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  'Available after login on this device',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _WorkspaceStat(
                            icon: Icons.favorite_rounded,
                            value: '${appState.favoriteStationIds.length}',
                            label: 'Favorites',
                          ),
                          _WorkspaceStat(
                            icon: Icons.route_rounded,
                            value: '${appState.savedTrips.length}',
                            label: 'Trips',
                          ),
                          _WorkspaceStat(
                            icon: Icons.receipt_long_rounded,
                            value: '${appState.chargingReceipts.length}',
                            label: 'Bills',
                          ),
                          _WorkspaceStat(
                            icon: Icons.add_location_alt_rounded,
                            value: '${appState.chargerSubmissions.length}',
                            label: 'Reports',
                          ),
                        ],
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
                    if (appState.isAdminAccount) ...[
                      ListTile(
                        key: const Key('adminDashboardTile'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        leading:
                            const Icon(Icons.admin_panel_settings_outlined),
                        title: const Text('Admin dashboard'),
                        subtitle: const Text(
                          'Local users, activity, reports, and demo payments',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const AdminDashboardScreen(),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
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
                      key: const Key('installVoltMapEVTile'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      leading: const Icon(Icons.install_mobile_rounded),
                      title: const Text('Install VoltMapEV'),
                      subtitle: const Text(
                        'Add the app to your iPhone, iPad, or Android home screen',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const InstallAppScreen(),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('aboutVoltMapEVTile'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('About & contact VoltMapEV'),
                      subtitle: const Text(
                        '${AppState.contactEmail} • ${AppState.contactPhone}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AboutScreen(),
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
                    ListTile(
                      key: const Key('signOutTile'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Sign out'),
                      subtitle: const Text(
                        'Your local favorites, trips, and receipts stay saved',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _confirmSignOut(context, appState),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('deleteAccountTile'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      leading: Icon(
                        Icons.delete_forever_outlined,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Delete account & local data',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      subtitle: const Text(
                        'Permanently removes this device’s profile, favorites, trips, receipts, and reports',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _confirmDeleteAccount(context, appState),
                    ),
                    const Divider(height: 1),
                    const ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      leading: Icon(Icons.info_outline),
                      title: Text('VoltMapEV demo'),
                      subtitle: Text(
                        'Android, iOS & browser-ready • Version 1.12.0',
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

  Widget _buildGuestProfile(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 58,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Explore first. Sign up when you save.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'Charger lookup, maps, charger details, and trip planning are public. Create a browser-local account only for favorites, saved trips, charger reports, and demo payments.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('profileSignUpButton'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const AuthScreen(initialSignUp: true),
                            ),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Create account'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const Key('profileSignInButton'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AuthScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Sign in'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  key: const Key('guestInstallVoltMapEVTile'),
                  leading: const Icon(Icons.install_mobile_rounded),
                  title: const Text('Install VoltMapEV'),
                  subtitle: const Text(
                    'Add the app to your iPhone, iPad, or Android home screen',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const InstallAppScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  key: const Key('guestAboutTile'),
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About & contact VoltMapEV'),
                  subtitle: const Text(
                    '${AppState.contactEmail} • ${AppState.contactPhone}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  ),
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
    final identifierController =
        TextEditingController(text: appState.userIdentifier);
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
                controller: identifierController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Email or India mobile (+91)',
                  hintText: 'name@example.com or +91 9392788714',
                ),
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
                  AppState.normalizeAccountIdentifier(
                        identifierController.text,
                      ) ==
                      null) {
                return;
              }
              appState.updateProfile(
                name: nameController.text,
                identifier: identifierController.text,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    identifierController.dispose();
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

  Future<void> _confirmSignOut(
    BuildContext context,
    AppState appState,
  ) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of VoltMapEV?'),
        content: const Text(
          'Your browser keeps this demo account and saved app data so you can sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirmSignOutButton'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldSignOut ?? false) await appState.signOut();
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AppState appState,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(dialogContext).colorScheme.error,
        ),
        title: const Text('Delete account and all local data?'),
        content: const Text(
          'This permanently removes your VoltMapEV profile, favorites, saved trips, receipts, charger reports, and preferences from this device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirmDeleteAccountButton'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (!(shouldDelete ?? false)) return;
    await appState.deleteLocalAccountAndData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account and local data deleted.')),
    );
  }
}

class _WorkspaceStat extends StatelessWidget {
  const _WorkspaceStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
