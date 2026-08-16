import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_environment.dart';
import '../../../shared/models/charging_station.dart';
import '../../../shared/services/secure_charging_api.dart';
import '../../../shared/services/secure_identity_api.dart';
import '../../../shared/state/app_state.dart';
import 'charging_receipt_screen.dart';

enum _ReceiptChannel { sms, email }

class ProductionChargingCheckoutScreen extends ConsumerStatefulWidget {
  const ProductionChargingCheckoutScreen({
    super.key,
    required this.station,
    this.identityApi,
    this.chargingApi,
    this.checkoutLauncher,
  });

  final ChargingStation station;
  final SecureIdentityApi? identityApi;
  final SecureChargingApi? chargingApi;
  final Future<bool> Function(Uri url)? checkoutLauncher;

  @override
  ConsumerState<ProductionChargingCheckoutScreen> createState() =>
      _ProductionChargingCheckoutScreenState();
}

class _ProductionChargingCheckoutScreenState
    extends ConsumerState<ProductionChargingCheckoutScreen> {
  static const _serviceFee = 5.0;
  static const _taxRate = 0.0;

  final _destinationController = TextEditingController();
  final _otpController = TextEditingController();
  late final SecureIdentityApi _identityApi;
  late final SecureChargingApi _chargingApi;
  late String _connector;
  _ReceiptChannel _channel = _ReceiptChannel.sms;
  double _energyLimitKwh = 20;
  ContactOtpChallenge? _challenge;
  VerifiedContact? _verifiedContact;
  String? _sessionId;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  double get _energyEstimate => _energyLimitKwh * widget.station.pricePerKwh;
  double get _taxEstimate => _energyEstimate * _taxRate;
  double get _maximumEstimate => _energyEstimate + _taxEstimate + _serviceFee;

  @override
  void initState() {
    super.initState();
    _identityApi = widget.identityApi ?? SecureIdentityApi();
    _chargingApi = widget.chargingApi ?? SecureChargingApi();
    _connector = widget.station.connectorTypes.first;
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppRuntimeConfig.hasSecureIdentityBackend ||
        !AppRuntimeConfig.hasSecurePaymentBackend) {
      return _ProductionServicesUnavailable(station: widget.station);
    }
    if (!widget.station.pricingIsLive || !widget.station.availabilityIsLive) {
      return _StationIntegrationUnavailable(station: widget.station);
    }

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        key: const Key('productionChargingCheckout'),
        appBar: AppBar(title: const Text('Secure charging payment')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
              children: [
                _section(
                  title: widget.station.name,
                  icon: Icons.ev_station_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.station.powerKw} kW • ₹${widget.station.pricePerKwh.toStringAsFixed(2)}/kWh',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.station.connectorTypes
                            .map(
                              (value) => ChoiceChip(
                                label: Text(value),
                                selected: _connector == value,
                                onSelected: _busy
                                    ? null
                                    : (_) => setState(() => _connector = value),
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(child: Text('Approved energy limit')),
                          Text('${_energyLimitKwh.toStringAsFixed(0)} kWh'),
                        ],
                      ),
                      Slider(
                        key: const Key('productionEnergySlider'),
                        value: _energyLimitKwh,
                        min: 5,
                        max: 50,
                        divisions: 9,
                        onChanged: _busy
                            ? null
                            : (value) =>
                                setState(() => _energyLimitKwh = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'Maximum estimate',
                  icon: Icons.receipt_long_outlined,
                  child: Column(
                    children: [
                      _amount('Energy', _energyEstimate),
                      _amount('Taxes', _taxEstimate),
                      _amount('Service fee', _serviceFee),
                      const Divider(height: 24),
                      _amount('Maximum approved amount', _maximumEstimate,
                          emphasized: true),
                      const SizedBox(height: 8),
                      const Text(
                        'The final amount uses the charger network’s confirmed meter reading. Any amount above this estimate requires new approval.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _section(
                  title: 'Verify receipt destination',
                  icon: Icons.verified_user_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<_ReceiptChannel>(
                        segments: const [
                          ButtonSegment(
                            value: _ReceiptChannel.sms,
                            icon: Icon(Icons.sms_outlined),
                            label: Text('SMS'),
                          ),
                          ButtonSegment(
                            value: _ReceiptChannel.email,
                            icon: Icon(Icons.email_outlined),
                            label: Text('Email'),
                          ),
                        ],
                        selected: {_channel},
                        onSelectionChanged: _busy
                            ? null
                            : (value) => _changeChannel(value.single),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        key: const Key('productionReceiptDestination'),
                        controller: _destinationController,
                        enabled: !_busy && _verifiedContact == null,
                        keyboardType: _channel == _ReceiptChannel.sms
                            ? TextInputType.phone
                            : TextInputType.emailAddress,
                        inputFormatters: _channel == _ReceiptChannel.sms
                            ? [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ]
                            : null,
                        decoration: InputDecoration(
                          labelText: _channel == _ReceiptChannel.sms
                              ? 'Mobile number'
                              : 'Email address',
                          prefixIcon: _channel == _ReceiptChannel.sms
                              ? const Icon(Icons.phone_outlined)
                              : const Icon(Icons.email_outlined),
                          prefixText: _channel == _ReceiptChannel.sms
                              ? '${AppState.indiaDialCode} '
                              : null,
                          prefixStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                          helperText: _channel == _ReceiptChannel.sms
                              ? 'India selected. Enter the 10 digits after +91; verification is required.'
                              : 'No signup required. This email must be verified before checkout.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_verifiedContact != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.verified_rounded),
                          title: const Text('Receipt destination verified'),
                          subtitle: Text(_verifiedContact!.destination),
                          trailing: TextButton(
                            onPressed: _busy ? null : _resetVerification,
                            child: const Text('Change'),
                          ),
                        )
                      else if (_challenge == null)
                        FilledButton.tonalIcon(
                          key: const Key('productionSendOtp'),
                          onPressed: _busy ? null : _sendOtp,
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Send verification code'),
                        )
                      else ...[
                        TextField(
                          key: const Key('productionOtpCode'),
                          controller: _otpController,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: const InputDecoration(
                            labelText: '6-digit verification code',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          key: const Key('productionVerifyOtp'),
                          onPressed: _busy ? null : _verifyOtp,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Verify code'),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 14),
                  MaterialBanner(
                    content: Text(_message!),
                    leading: Icon(
                      _messageIsError
                          ? Icons.error_outline_rounded
                          : Icons.info_outline_rounded,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => _message = null),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('productionCheckoutButton'),
                    onPressed: _busy || _verifiedContact == null
                        ? null
                        : _sessionId == null
                            ? _openCheckout
                            : _checkVerifiedReceipt,
                    icon: Icon(
                      _sessionId == null
                          ? Icons.open_in_new_rounded
                          : Icons.verified_outlined,
                    ),
                    label: Text(
                      _sessionId == null
                          ? 'Approve & open secure checkout'
                          : 'Check verified payment & receipt',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _amount(String label, double value, {bool emphasized = false}) {
    final style = emphasized
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w900)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('₹${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  void _changeChannel(_ReceiptChannel channel) {
    setState(() {
      _channel = channel;
      _challenge = null;
      _verifiedContact = null;
      _destinationController.clear();
      _otpController.clear();
      _message = null;
    });
  }

  void _resetVerification() {
    setState(() {
      _challenge = null;
      _verifiedContact = null;
      _otpController.clear();
      _sessionId = null;
      _message = null;
    });
  }

  Future<void> _sendOtp() async {
    final destination = _normalizedDestination();
    if (destination == null) return;
    await _run(() async {
      final challenge = await _identityApi.sendOtp(
        channel: _channel.name,
        destination: destination,
        purpose: 'charging_receipt',
      );
      setState(() {
        _challenge = challenge;
        _message = 'Verification code sent. It expires soon.';
        _messageIsError = false;
      });
    });
  }

  Future<void> _verifyOtp() async {
    final challenge = _challenge;
    if (challenge == null || _otpController.text.trim().length != 6) {
      _showMessage('Enter the complete 6-digit verification code.', true);
      return;
    }
    await _run(() async {
      final contact = await _identityApi.verifyOtp(
        challenge: challenge,
        code: _otpController.text.trim(),
      );
      setState(() {
        _verifiedContact = contact;
        _otpController.clear();
        _message = 'Destination verified. You can continue to checkout.';
        _messageIsError = false;
      });
    });
  }

  Future<void> _openCheckout() async {
    final contact = _verifiedContact;
    if (contact == null) return;
    await _run(() async {
      final idempotencyKey =
          'vm-${widget.station.id}-${DateTime.now().microsecondsSinceEpoch}';
      final authorization = await _chargingApi.authorizeSession(
        stationId: widget.station.id,
        chargerId: _connector,
        approvedEnergyLimitKwh: _energyLimitKwh,
        disclosedRatePerKwh: widget.station.pricePerKwh,
        disclosedTaxRate: _taxRate,
        disclosedServiceFee: _serviceFee,
        verifiedContactToken: contact.token,
        idempotencyKey: idempotencyKey,
      );
      final launched = widget.checkoutLauncher != null
          ? await widget.checkoutLauncher!(authorization.checkoutUrl)
          : await launchUrl(
              authorization.checkoutUrl,
              mode: LaunchMode.externalApplication,
            );
      if (!launched) {
        throw const SecureChargingApiException(
          'Could not open the payment provider checkout.',
          code: 'checkout_launch_failed',
        );
      }
      setState(() {
        _sessionId = authorization.sessionId;
        _message =
            'Checkout opened. Return here after payment and charging, then check the verified receipt.';
        _messageIsError = false;
      });
    });
  }

  Future<void> _checkVerifiedReceipt() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    await _run(() async {
      final receipt = await _chargingApi.verifiedReceipt(sessionId);
      if (receipt == null) {
        _showMessage(
          'Still waiting for both the provider webhook and the charger’s final meter reading. No success has been recorded yet.',
          false,
        );
        return;
      }
      await ref.read(appStateProvider).saveChargingReceipt(receipt);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => ChargingReceiptScreen(
            receipt: receipt,
            station: widget.station,
          ),
        ),
      );
    });
  }

  String? _normalizedDestination() {
    final raw = _destinationController.text.trim();
    if (_channel == _ReceiptChannel.sms) {
      final phone = AppState.normalizeIndianMobile(raw);
      if (phone == null) {
        _showMessage('Enter a valid 10-digit India mobile number.', true);
      }
      return phone;
    }
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(raw);
    if (!valid) {
      _showMessage('Enter a valid email address.', true);
      return null;
    }
    return raw.toLowerCase();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      _showMessage(error.toString(), true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message, bool isError) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }
}

class _ProductionServicesUnavailable extends StatelessWidget {
  const _ProductionServicesUnavailable({required this.station});

  final ChargingStation station;

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (!AppRuntimeConfig.hasSecureIdentityBackend)
        'OTP and verified receipt destination service',
      if (!AppRuntimeConfig.hasSecurePaymentBackend)
        'payment, meter verification, and receipt service',
    ];
    return _ProductionBlocker(
      icon: Icons.lock_clock_outlined,
      title: 'Secure charging services are not connected',
      message:
          '${missing.join(' and ')} ${missing.length == 1 ? 'is' : 'are'} not configured. No OTP, payment, or receipt delivery was attempted.',
    );
  }
}

class _StationIntegrationUnavailable extends StatelessWidget {
  const _StationIntegrationUnavailable({required this.station});

  final ChargingStation station;

  @override
  Widget build(BuildContext context) => _ProductionBlocker(
        icon: Icons.ev_station_outlined,
        title: 'Live charging is not enabled at this station',
        message:
            '${station.name} does not yet provide verified live availability, tariff, and meter data to VoltMapEV. No payment was created.',
      );
}

class _ProductionBlocker extends StatelessWidget {
  const _ProductionBlocker({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Secure charging payment')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 31, child: Icon(icon, size: 31)),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      const Text(
                        'VoltMapEV never collects card numbers, CVVs, UPI PINs, or banking credentials. Payment can become successful only after a provider-signed server webhook and a confirmed meter reading.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back to station'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
