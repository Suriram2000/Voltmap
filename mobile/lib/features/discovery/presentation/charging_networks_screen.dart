import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/state/app_state.dart';

class ChargingNetworksScreen extends StatelessWidget {
  const ChargingNetworksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Charging networks')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text('Your charging connections',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'VoltMapEV keeps discovery, route planning, session records, and arrival plans in one place. Live network controls appear here only after their operator has connected and verified them.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          _NetworkStatusCard(
            icon: Icons.public_rounded,
            title: 'India charging inventory',
            detail: 'Searchable published station records are available now.',
            state: 'Available',
            color: colors.primary,
          ),
          _NetworkStatusCard(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scan or enter charger code',
            detail: 'Waiting for a verified operator remote-start connection.',
            state: 'Provider connection needed',
            color: colors.tertiary,
          ),
          _NetworkStatusCard(
            icon: Icons.event_available_rounded,
            title: 'Confirmed connector reservations',
            detail: 'Arrival plans are available; a confirmed bay requires the operator reservation API.',
            state: 'Provider connection needed',
            color: colors.tertiary,
          ),
          _NetworkStatusCard(
            icon: Icons.hub_outlined,
            title: 'Roaming networks',
            detail: 'OCPI partner records and unified start/payment require roaming agreements.',
            state: 'No roaming partner connected',
            color: colors.tertiary,
          ),
          _NetworkStatusCard(
            icon: Icons.bolt_rounded,
            title: 'Live charger session',
            detail: 'Meter values and remote stop controls require an OCPP-capable operator connection.',
            state: 'Provider connection needed',
            color: colors.tertiary,
          ),
          _NetworkStatusCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Wallet and payment settlement',
            detail: 'VoltMapEV can show a checkout flow; real settlement requires a verified payment provider and operator meter reading.',
            state: 'Provider connection needed',
            color: colors.tertiary,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('chargingSupportButton'),
            onPressed: () => _contactSupport(context),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Get charging support'),
          ),
        ],
      ),
    );
  }

  Future<void> _contactSupport(BuildContext context) async {
    final opened = await launchUrl(
      Uri(scheme: 'mailto', path: AppState.contactEmail, query: 'subject=VoltMapEV%20charging%20support'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email support.')),
      );
    }
  }
}

class _NetworkStatusCard extends StatelessWidget {
  const _NetworkStatusCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.state,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String state;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.all(18),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.14),
            foregroundColor: color,
            child: Icon(icon),
          ),
          title: Text(title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('$state\n$detail'),
          ),
        ),
      );
}
