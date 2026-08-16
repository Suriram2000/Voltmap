import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/state/app_state.dart';

enum _AppFeedbackCategory {
  general('General feedback'),
  appIssue('App issue'),
  paymentReceipt('Payment or receipt issue'),
  chargerData('Charging-station data issue'),
  featureSuggestion('Feature suggestion');

  const _AppFeedbackCategory(this.label);

  final String label;
}

Future<void> showAppFeedbackDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _AppFeedbackDialog(),
  );
}

class _AppFeedbackDialog extends StatefulWidget {
  const _AppFeedbackDialog();

  @override
  State<_AppFeedbackDialog> createState() => _AppFeedbackDialogState();
}

class _AppFeedbackDialogState extends State<_AppFeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _contactController = TextEditingController();
  _AppFeedbackCategory _category = _AppFeedbackCategory.general;
  bool _openingEmail = false;

  @override
  void dispose() {
    _detailsController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('privateAppFeedbackDialog'),
      icon: const Icon(Icons.feedback_outlined),
      title: const Text('Send private app feedback'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your feedback opens in a private email addressed only to the VoltMapEV administrator. Review it, then press Send in your email app.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<_AppFeedbackCategory>(
                  key: const Key('appFeedbackCategory'),
                  isExpanded: true,
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Feedback type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _AppFeedbackCategory.values
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('appFeedbackDetails'),
                  controller: _detailsController,
                  minLines: 3,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Your feedback',
                    hintText: 'Tell us what happened and what would help.',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 10
                      ? 'Please provide at least 10 characters of useful detail.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('appFeedbackContact'),
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Your email or India mobile +91 (optional)',
                    prefixIcon: Icon(Icons.contact_mail_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _openingEmail ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('sendPrivateAppFeedbackButton'),
          onPressed: _openingEmail ? null : _openPrivateEmail,
          icon: _openingEmail
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_rounded),
          label: const Text('Email privately'),
        ),
      ],
    );
  }

  Future<void> _openPrivateEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _openingEmail = true);
    final now = DateTime.now().toUtc();
    final uri = Uri(
      scheme: 'mailto',
      path: AppState.adminIdentifier,
      queryParameters: {
        'subject': '[VoltMapEV private app feedback] ${_category.label}',
        'body': '''
Private VoltMapEV app feedback

Category: ${_category.label}
Submitted: ${now.toIso8601String()}

Feedback:
${_detailsController.text.trim()}

Optional reporter contact: ${_contactController.text.trim().isEmpty ? 'Not provided' : _contactController.text.trim()}

This message is addressed only to the VoltMapEV administrator.
''',
      },
    );
    var launched = false;
    try {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ).timeout(const Duration(seconds: 4), onTimeout: () => false);
    } catch (_) {
      // A clear manual-delivery fallback is shown below.
    }
    if (!mounted) return;
    setState(() => _openingEmail = false);
    if (launched) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Private admin email opened. Review it and press Send to deliver your feedback.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No email app is available. Send feedback privately to skotla100@gmail.com.',
          ),
        ),
      );
    }
  }
}
