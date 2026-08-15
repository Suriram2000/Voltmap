import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/state/app_state.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About VoltMapEV')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.brandNavy, Color(0xFF0B3829)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: AppTheme.brandLime,
                      size: 42,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Charge forward with confidence',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'VoltMapEV helps drivers discover EV charging stations across India and plan range-aware trips with relevant chargers along the route.',
                      style: TextStyle(
                        color: Color(0xFFC4D8CF),
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _InfoCard(
                icon: Icons.public_rounded,
                title: 'What is public',
                text:
                    'Anyone can search charging stations, browse the map, inspect charger details, and plan a trip without signing in.',
              ),
              const SizedBox(height: 12),
              const _InfoCard(
                icon: Icons.lock_outline_rounded,
                title: 'What needs an account',
                text:
                    'Signup is required only to save favorites or trips and view personal history. Searching, trip planning, station corrections, and guest checkout where supported remain public.',
              ),
              const SizedBox(height: 12),
              const _InfoCard(
                icon: Icons.verified_outlined,
                title: 'Data transparency',
                text:
                    'Official search results show their government source and data date. Bundled station availability, prices, ratings, route stops, and payments are demonstration data and are clearly labelled for verification before travel.',
              ),
              const SizedBox(height: 24),
              Text(
                'Contact us',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      key: const Key('contactEmailTile'),
                      leading: const Icon(Icons.email_outlined),
                      title: const Text(AppState.contactEmail),
                      subtitle: const Text('Email VoltMapEV support'),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: () => _open(
                        Uri(
                          scheme: 'mailto',
                          path: AppState.contactEmail,
                          queryParameters: {
                            'subject': 'VoltMapEV support request',
                          },
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('contactPhoneTile'),
                      leading: const Icon(Icons.phone_outlined),
                      title: const Text(AppState.contactPhone),
                      subtitle: const Text('Call VoltMapEV support'),
                      trailing: const Icon(Icons.call_rounded),
                      onTap: () => _open(
                        Uri(scheme: 'tel', path: AppState.contactPhone),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Legal & privacy',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    _WebLinkTile(
                      key: const Key('privacyPolicyTile'),
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy policy',
                      uri: Uri.parse(
                        'https://voltmapev.com/privacy-policy.html',
                      ),
                    ),
                    const Divider(height: 1),
                    _WebLinkTile(
                      key: const Key('termsTile'),
                      icon: Icons.gavel_outlined,
                      title: 'Terms of use',
                      uri: Uri.parse('https://voltmapev.com/terms.html'),
                    ),
                    const Divider(height: 1),
                    _WebLinkTile(
                      key: const Key('refundPolicyTile'),
                      icon: Icons.currency_rupee_outlined,
                      title: 'Refund & cancellation policy',
                      uri: Uri.parse(
                        'https://voltmapev.com/refund-policy.html',
                      ),
                    ),
                    const Divider(height: 1),
                    _WebLinkTile(
                      key: const Key('accountDeletionTile'),
                      icon: Icons.delete_outline_rounded,
                      title: 'Account deletion instructions',
                      uri: Uri.parse(
                        'https://voltmapev.com/account-deletion.html',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                '© 2026 VoltMapEV. All rights reserved.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _WebLinkTile extends StatelessWidget {
  const _WebLinkTile({
    super.key,
    required this.icon,
    required this.title,
    required this.uri,
  });

  final IconData icon;
  final String title;
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.open_in_new_rounded),
      onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
