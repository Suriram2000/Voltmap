import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/station_feedback.dart';
import '../../../shared/state/app_state.dart';

Future<void> showStationFeedbackDialog({
  required BuildContext context,
  required String stationId,
  required String stationName,
  required String operatorName,
  required String address,
  required double latitude,
  required double longitude,
  List<String> sourceNames = const [],
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _StationFeedbackDialog(
      stationId: stationId,
      stationName: stationName,
      operatorName: operatorName,
      address: address,
      latitude: latitude,
      longitude: longitude,
      sourceNames: sourceNames,
    ),
  );
}

class _StationFeedbackDialog extends StatefulWidget {
  const _StationFeedbackDialog({
    required this.stationId,
    required this.stationName,
    required this.operatorName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.sourceNames,
  });

  final String stationId;
  final String stationName;
  final String operatorName;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> sourceNames;

  @override
  State<_StationFeedbackDialog> createState() => _StationFeedbackDialogState();
}

class _StationFeedbackDialogState extends State<_StationFeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _contactController = TextEditingController();
  StationFeedbackCategory _category = StationFeedbackCategory.notWorking;
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
      key: const Key('privateStationFeedbackDialog'),
      icon: const Icon(Icons.private_connectivity_rounded),
      title: const Text('Send private station feedback'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.stationName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'This report opens a private email addressed only to the VoltMapEV administrator. It is never posted to GitHub or shown publicly. Review the message, attach a photo if useful, then press Send in your email app.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<StationFeedbackCategory>(
                  key: const Key('stationFeedbackCategory'),
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'What needs correction?',
                    prefixIcon: Icon(Icons.fact_check_outlined),
                  ),
                  items: StationFeedbackCategory.values
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
                  key: const Key('stationFeedbackDetails'),
                  controller: _detailsController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Correct information and evidence',
                    hintText:
                        'Example: visited today; charger removed, or operator app shows CCS2 60 kW.',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 10
                      ? 'Please provide at least 10 characters of useful detail.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('stationFeedbackContact'),
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Your email or phone (optional)',
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
          key: const Key('sendPrivateStationFeedbackButton'),
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
    final now = DateTime.now();
    final feedback = StationFeedbackDraft(
      feedbackId: 'FB-${now.microsecondsSinceEpoch}',
      stationId: widget.stationId,
      stationName: widget.stationName,
      operatorName: widget.operatorName,
      address: widget.address,
      latitude: widget.latitude,
      longitude: widget.longitude,
      category: _category,
      details: _detailsController.text.trim(),
      observedAt: now,
      createdAt: now,
      sourceNames: widget.sourceNames,
      contact: _contactController.text.trim(),
    );
    var launched = false;
    try {
      launched = await launchUrl(
        feedback.privateAdminEmailUri(AppState.adminIdentifier),
        mode: LaunchMode.externalApplication,
      ).timeout(const Duration(seconds: 4), onTimeout: () => false);
    } catch (_) {
      // The user receives a clear retry message below.
    }
    if (!mounted) return;
    setState(() => _openingEmail = false);
    if (launched) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Private admin email opened. Review it and press Send to deliver the feedback.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No email app is available. Send the correction privately to skotla100@gmail.com.',
          ),
        ),
      );
    }
  }
}
