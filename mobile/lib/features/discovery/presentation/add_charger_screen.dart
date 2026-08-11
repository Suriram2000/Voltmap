import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/charger_submission.dart';
import '../../../shared/state/app_state.dart';

class AddChargerScreen extends ConsumerStatefulWidget {
  const AddChargerScreen({super.key});

  @override
  ConsumerState<AddChargerScreen> createState() => _AddChargerScreenState();
}

class _AddChargerScreenState extends ConsumerState<AddChargerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _stationController = TextEditingController();
  final _operatorController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pinController = TextEditingController();
  final _notesController = TextEditingController();
  final _connectors = <String>{'CCS2'};
  String _status = 'Working';
  bool _submitting = false;

  static const _connectorOptions = [
    'CCS2',
    'CHAdeMO',
    'Type 2',
    'Bharat DC-001',
    'Bharat AC-001',
    '15A socket',
  ];

  @override
  void dispose() {
    for (final controller in [
      _stationController,
      _operatorController,
      _addressController,
      _cityController,
      _stateController,
      _pinController,
      _notesController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add a charging station')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.brandNavy, Color(0xFF0B3829)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.add_location_alt_rounded,
                        color: AppTheme.brandLime, size: 34),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DecoratedBox(
                            key: Key('publicAddstationNotice'),
                            decoration: BoxDecoration(
                              color: Color(0x2420C77A),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(999)),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_open_rounded,
                                    color: AppTheme.brandLime,
                                    size: 15,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'NO SIGNUP REQUIRED',
                                    style: TextStyle(
                                      color: Color(0xFFD8FFE9),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Help improve India\'s charger map',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 21,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Save a missing station report without creating an account. Public moderation is optional and no charger appears in the catalog until it is reviewed.',
                            style: TextStyle(color: Color(0xFFC4D8CF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (appState.chargerSubmissions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Card(
                  color: colors.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.pending_actions_rounded),
                    title: Text(
                      '${appState.chargerSubmissions.length} report${appState.chargerSubmissions.length == 1 ? '' : 's'} saved on this device',
                    ),
                    subtitle: const Text(
                      'Latest status: saved locally • public review optional',
                    ),
                    trailing: IconButton(
                      key: const Key('openLatestChargerReportButton'),
                      tooltip: 'Open latest report for public review',
                      onPressed: _submitting
                          ? null
                          : () => _openPublicReview(
                                appState.chargerSubmissions.first,
                              ),
                      icon: const Icon(Icons.rate_review_outlined),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const _SubmissionSteps(),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Charger information',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Complete the location and connector details. Notes are optional.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 18),
                        _field(
                          controller: _stationController,
                          label: 'Station name',
                          icon: Icons.ev_station_rounded,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _operatorController,
                          label: 'Operator or network',
                          icon: Icons.business_rounded,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _addressController,
                          label: 'Street address / landmark',
                          icon: Icons.place_outlined,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 620;
                            final cityField = _field(
                              controller: _cityController,
                              label: 'City / area',
                              icon: Icons.location_city_rounded,
                            );
                            final stateField = _field(
                              controller: _stateController,
                              label: 'State / UT',
                              icon: Icons.map_outlined,
                            );
                            if (compact) {
                              return Column(
                                children: [
                                  cityField,
                                  const SizedBox(height: 14),
                                  stateField,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: cityField),
                                const SizedBox(width: 14),
                                Expanded(child: stateField),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('chargerPinField'),
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: '6-digit Indian PIN code',
                            prefixIcon: Icon(Icons.pin_drop_outlined),
                            counterText: '',
                          ),
                          validator: (value) =>
                              RegExp(r'^[1-9][0-9]{5}$').hasMatch(
                            value?.trim() ?? '',
                          )
                                  ? null
                                  : 'Enter a valid 6-digit Indian PIN',
                        ),
                        const SizedBox(height: 20),
                        Text('Connector types',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final connector in _connectorOptions)
                              FilterChip(
                                label: Text(connector),
                                selected: _connectors.contains(connector),
                                onSelected: (selected) => setState(() {
                                  if (selected) {
                                    _connectors.add(connector);
                                  } else if (_connectors.length > 1) {
                                    _connectors.remove(connector);
                                  }
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Current status',
                            prefixIcon: Icon(Icons.power_settings_new_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'Working', child: Text('Working')),
                            DropdownMenuItem(
                              value: 'Not working / unavailable',
                              child: Text('Not working / unavailable'),
                            ),
                            DropdownMenuItem(
                              value: 'Status unknown',
                              child: Text('Status unknown'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _status = value ?? _status),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _notesController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Notes or verification evidence',
                            hintText:
                                'Add a Maps link, photo link, tariff, hours, or landmark.',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.fact_check_outlined),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('submitChargerReportButton'),
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: const Text('Save station report'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No VoltMapEV signup is required. The report is saved on this device first; sending it for public GitHub review is optional.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                        ),
                      ],
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

  TextFormField _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) =>
          (value?.trim().length ?? 0) < 2 ? 'Please enter $label' : null,
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final now = DateTime.now();
    final submission = ChargerSubmission(
      id: 'CHG-${now.millisecondsSinceEpoch}',
      stationName: _stationController.text.trim(),
      operatorName: _operatorController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      postalCode: _pinController.text.trim(),
      connectorTypes: _connectors.toList(growable: false)..sort(),
      reportedStatus: _status,
      notes: _notesController.text.trim(),
      createdAt: now,
    );
    await ref.read(appStateProvider).saveChargerSubmission(submission);
    if (!mounted) return;
    setState(() => _submitting = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.save_rounded,
          color: Theme.of(dialogContext).colorScheme.primary,
        ),
        title: const Text('Report saved'),
        content: const Text(
          'Your station report is saved on this device without signup. You can finish here or optionally open a prefilled GitHub form for public verification.',
        ),
        actions: [
          TextButton(
            key: const Key('finishChargerReportButton'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
          FilledButton.icon(
            key: const Key('openPublicChargerReviewButton'),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _openPublicReview(submission);
            },
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Open public review'),
          ),
        ],
      ),
    );
    if (mounted) _resetForm();
  }

  Future<void> _openPublicReview(ChargerSubmission submission) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final issueUri = Uri.https(
      'github.com',
      '/Suriram2000/Voltmap/issues/new',
      {
        'title':
            '[Charger report] ${submission.stationName} - ${submission.postalCode}',
        'body': submission.issueBody,
      },
    );
    var launched = false;
    try {
      launched = await launchUrl(
        issueUri,
        mode: LaunchMode.externalApplication,
      ).timeout(const Duration(seconds: 3), onTimeout: () => false);
    } catch (_) {
      // The pending report remains saved if the browser cannot open GitHub.
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The public review page could not be opened. Your report is still saved on this device.',
          ),
        ),
      );
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    for (final controller in [
      _stationController,
      _operatorController,
      _addressController,
      _cityController,
      _stateController,
      _pinController,
      _notesController,
    ]) {
      controller.clear();
    }
    setState(() {
      _connectors
        ..clear()
        ..add('CCS2');
      _status = 'Working';
    });
  }
}

class _SubmissionSteps extends StatelessWidget {
  const _SubmissionSteps();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StepBadge(number: '1', label: 'Location'),
            Icon(Icons.arrow_forward_rounded, size: 17),
            _StepBadge(number: '2', label: 'Connectors'),
            Icon(Icons.arrow_forward_rounded, size: 17),
            _StepBadge(number: '3', label: 'Save report'),
          ],
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            number,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
