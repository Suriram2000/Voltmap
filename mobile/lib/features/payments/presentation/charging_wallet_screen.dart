import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/state/app_state.dart';

/// The customer wallet entry point. It never invents a spendable balance: a
/// balance, top-up, debit, and refund become visible only after the server-side
/// payment ledger and provider webhooks are connected.
class ChargingWalletScreen extends ConsumerWidget {
  const ChargingWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final connected = AppRuntimeConfig.hasChargingWalletBackend;
    return Scaffold(
      appBar: AppBar(title: const Text('VoltMap Wallet')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            children: [
              _BalanceCard(connected: connected),
              if (!connected) ...[
                const SizedBox(height: 16),
                Text(
                  'Wallet payments are not connected in this build. No money can be added, reserved, debited, or refunded here yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Wallet controls',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    _WalletFeature(
                      icon: Icons.add_card_outlined,
                      title: 'Add money securely',
                      detail: connected
                          ? 'Open your payment provider to add money.'
                          : 'Available when a verified provider is connected.',
                      enabled: connected,
                    ),
                    const Divider(height: 1),
                    _WalletFeature(
                      icon: Icons.ev_station_outlined,
                      title: 'Charge from wallet',
                      detail:
                          'Reserve the maximum first, then debit only the verified final charge.',
                      enabled: connected,
                    ),
                    const Divider(height: 1),
                    _WalletFeature(
                      icon: Icons.currency_exchange_outlined,
                      title: 'Refunds and adjustments',
                      detail:
                          'Completed refunds appear in your wallet activity and receipt history.',
                      enabled: connected,
                    ),
                    const Divider(height: 1),
                    _WalletFeature(
                      icon: Icons.notifications_active_outlined,
                      title: 'Low-balance reminder',
                      detail: appState.notificationsEnabled
                          ? 'Charging notifications are enabled.'
                          : 'Turn on charging notifications in Profile to receive reminders.',
                      enabled: connected,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'VoltMapEV never stores card numbers, CVVs, UPI PINs, or bank passwords. A wallet balance is created only from payment-provider webhooks and a double-entry server ledger.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.brandNavy, Color(0xFF0B3829)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded,
                      color: AppTheme.brandLime),
                  SizedBox(width: 10),
                  Text('VOLTMAP WALLET',
                      style: TextStyle(
                        color: AppTheme.brandLime,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      )),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                connected
                    ? 'Balance loads after verification'
                    : 'Not connected',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Available balance • charging holds • receipts • refunds',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
}

class _WalletFeature extends StatelessWidget {
  const _WalletFeature({
    required this.icon,
    required this.title,
    required this.detail,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(detail),
        trailing: Icon(
          enabled ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
        ),
      );
}
