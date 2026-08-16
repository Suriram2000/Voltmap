import 'package:flutter/material.dart';

import '../../features/about/presentation/about_screen.dart';
import '../../features/feedback/presentation/app_feedback_dialog.dart';

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    return Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              compact
                  ? '© 2026 VoltMapEV'
                  : '© 2026 VoltMapEV. All rights reserved.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          TextButton.icon(
            key: const Key('footerFeedbackButton'),
            onPressed: () => showAppFeedbackDialog(context),
            icon: const Icon(Icons.feedback_outlined, size: 17),
            label: const Text('Feedback'),
          ),
          if (compact)
            IconButton(
              key: const Key('footerAboutButton'),
              tooltip: 'About & contact',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
              icon: const Icon(Icons.info_outline_rounded, size: 19),
            )
          else
            TextButton.icon(
              key: const Key('footerAboutButton'),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
              icon: const Icon(Icons.info_outline_rounded, size: 17),
              label: const Text('About & contact'),
            ),
        ],
      ),
    );
  }
}
