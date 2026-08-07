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
      appBar: AppBar(title: const Text('Add a missing charger')),
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
                            'Reports are saved as pending and opened for public review. VoltMap verifies a charger before adding it to the catalog.',
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
                      'Latest status: pending public verification',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Charger information',
                            style: Theme.of(context).textTheme.titleLarge),
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
                            label: const Text('Save & submit for review'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'A GitHub sign-in is required to finish the public report. No charger is published until it is reviewed.',
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          launched ? Icons.open_in_new_rounded : Icons.save_rounded,
          color: Theme.of(dialogContext).colorScheme.primary,
        ),
        title: Text(launched ? 'Report ready for review' : 'Report saved'),
        content: Text(
          launched
              ? 'Complete the prefilled GitHub form to send this charger for public verification. A pending copy is saved on this device.'
              : 'A pending copy is saved on this device, but the public review page could not be opened. Please try again when you are online.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
