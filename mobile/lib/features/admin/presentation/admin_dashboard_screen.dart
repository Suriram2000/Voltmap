import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/state/app_state.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    if (!appState.isAdminAccount) {
      return const Scaffold(
        body: Center(child: Text('Admin access is not available.')),
      );
    }

    final totalDemoPayments = appState.chargingReceipts.fold<double>(
      0,
      (total, receipt) => total + receipt.amount,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('VoltMapEV admin')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.admin_panel_settings_rounded),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Private admin view',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Only skotla100@gmail.com can open this page. The current release reports data stored in this browser only; a hosted backend is required for a global user list.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _AdminStat(
                    label: 'Local users',
                    value: '${appState.localAccountSummaries.length}',
                    icon: Icons.people_outline_rounded,
                  ),
                  _AdminStat(
                    label: 'Favorites',
                    value: '${appState.favoriteStationIds.length}',
                    icon: Icons.favorite_outline_rounded,
                  ),
                  _AdminStat(
                    label: 'Saved trips',
                    value: '${appState.savedTrips.length}',
                    icon: Icons.route_outlined,
                  ),
                  _AdminStat(
                    label: 'Charger reports',
                    value: '${appState.chargerSubmissions.length}',
                    icon: Icons.add_location_alt_outlined,
                  ),
                  _AdminStat(
                    label: 'Demo payments',
                    value: '${appState.chargingReceipts.length}',
                    icon: Icons.receipt_long_outlined,
                  ),
                  _AdminStat(
                    label: 'Demo volume',
                    value: '₹${totalDemoPayments.toStringAsFixed(2)}',
                    icon: Icons.payments_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Card(
                key: Key('privateStationFeedbackInboxCard'),
                child: ListTile(
                  leading: Icon(Icons.mark_email_unread_outlined),
                  title: Text('Private station feedback inbox'),
                  subtitle: Text(
                    'Station corrections and missing-station reports are addressed only to skotla100@gmail.com. They are no longer sent to public GitHub issues. Review evidence before changing the published catalog.',
                  ),
                  trailing: Chip(label: Text('ADMIN ONLY')),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Registered users on this browser',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              for (final account in appState.localAccountSummaries)
                Card(
                  child: ListTile(
                    key: const Key('adminUserRecord'),
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline_rounded),
                    ),
                    title: Text(account.name),
                    subtitle: Text(
                      '${account.identifier}\nCreated: ${_date(account.createdAt)} • Last sign-in: ${_date(account.lastSignInAt)}',
                    ),
                    isThreeLine: true,
                    trailing: account.identifier == AppState.adminIdentifier
                        ? const Chip(label: Text('Admin'))
                        : const Chip(label: Text('User')),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Payment activity',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (appState.chargingReceipts.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.receipt_long_outlined),
                    title: Text('No demo payments on this browser'),
                    subtitle: Text(
                      'VoltMapEV never displays or saves card numbers, CVVs, or real payment credentials here.',
                    ),
                  ),
                )
              else
                for (final receipt in appState.chargingReceipts)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline_rounded),
                      title: Text(receipt.stationName),
                      subtitle: Text(
                        '${receipt.paymentMethod} • ${receipt.energyKwh.toStringAsFixed(2)} kWh • ${_date(receipt.createdAt)}',
                      ),
                      trailing: Text(
                        '₹${receipt.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              const SizedBox(height: 20),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.security_rounded),
                  title: Text('Security boundary'),
                  subtitle: Text(
                    'Password salts and hashes are never exposed in this dashboard. Global users, cross-device data, and real payment reporting require secure server-side authentication and database access controls.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _date(DateTime? value) {
    if (value == null) return 'legacy account';
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _AdminStat extends StatelessWidget {
  const _AdminStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
