import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../shared/models/charging_receipt.dart';
import '../../../shared/models/charging_station.dart';
import '../../../shared/services/charging_billing.dart';
import '../../../shared/services/sandbox_payment_validator.dart';
import '../../../shared/state/app_state.dart';

enum PaymentOption { upi, card, wallet }

enum ReceiptDeliveryOption { app, email, sms }

class ChargingCheckoutScreen extends ConsumerStatefulWidget {
  const ChargingCheckoutScreen({super.key, required this.station});

  final ChargingStation station;

  @override
  ConsumerState<ChargingCheckoutScreen> createState() =>
      _ChargingCheckoutScreenState();
}

class _ChargingCheckoutScreenState
    extends ConsumerState<ChargingCheckoutScreen> {
  static const _platformFee = 5.0;

  final _formKey = GlobalKey<FormState>();
  final _upiController = TextEditingController();
  final _cardholderController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _paymentPhoneController = TextEditingController();
  final _receiptEmailController = TextEditingController();

  late String _connectorType;
  double _energyKwh = 20;
  PaymentOption _paymentOption = PaymentOption.upi;
  ReceiptDeliveryOption _receiptDeliveryOption = ReceiptDeliveryOption.app;
  bool _processing = false;

  double get _energyCharge => _energyKwh * widget.station.pricePerKwh;
  double get _total => _energyCharge + _platformFee;

  @override
  void initState() {
    super.initState();
    _connectorType = widget.station.connectorTypes.first;
  }

  @override
  void dispose() {
    _upiController.dispose();
    _cardholderController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _paymentPhoneController.dispose();
    _receiptEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppRuntimeConfig.isSandbox) {
      return _ProductionPaymentGate(station: widget.station);
    }
    return PopScope(
      canPop: !_processing,
      child: Scaffold(
        appBar: AppBar(title: const Text('Charge & pay')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
                children: [
                  const _CheckoutJourneyHeader(),
                  const SizedBox(height: 14),
                  _DemoNotice(),
                  const SizedBox(height: 14),
                  _CheckoutSection(
                    title: widget.station.name,
                    subtitle:
                        '${widget.station.powerKw} kW • ₹${widget.station.pricePerKwh.toStringAsFixed(2)}/kWh',
                    icon: Icons.ev_station,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Connector'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.station.connectorTypes
                              .map(
                                (connector) => ChoiceChip(
                                  label: Text(connector),
                                  selected: _connectorType == connector,
                                  onSelected: _processing
                                      ? null
                                      : (_) => setState(
                                            () => _connectorType = connector,
                                          ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Expanded(child: Text('Automatic stop limit')),
                            Text(
                              '${_energyKwh.toStringAsFixed(0)} kWh',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Slider(
                          key: const Key('energySlider'),
                          value: _energyKwh,
                          min: 5,
                          max: 50,
                          divisions: 9,
                          label: '${_energyKwh.toStringAsFixed(0)} kWh',
                          onChanged: _processing
                              ? null
                              : (value) => setState(() => _energyKwh = value),
                        ),
                        Text(
                          'Nothing is charged now. Charging stops automatically at this limit, and the final amount uses only the energy actually delivered.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CheckoutSection(
                    title: 'Estimated maximum',
                    subtitle: 'Final payment is calculated after charging',
                    icon: Icons.receipt_long_outlined,
                    child: Column(
                      children: [
                        _AmountRow(
                          label:
                              '${_energyKwh.toStringAsFixed(0)} kWh × ₹${widget.station.pricePerKwh.toStringAsFixed(2)}',
                          value: _currency(_energyCharge),
                        ),
                        const SizedBox(height: 8),
                        const _AmountRow(label: 'Platform fee', value: '₹5.00'),
                        const Divider(height: 24),
                        _AmountRow(
                          label: 'Maximum after charging',
                          value: _currency(_total),
                          emphasized: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CheckoutSection(
                    title: 'Payment contact',
                    subtitle: 'Guest checkout — no signup required',
                    icon: Icons.phone_android_outlined,
                    child: TextFormField(
                      key: const Key('paymentPhoneField'),
                      controller: _paymentPhoneController,
                      enabled: !_processing,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [
                        AutofillHints.telephoneNumberNational,
                      ],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '9876543210',
                        prefixIcon: Icon(Icons.phone_outlined),
                        helperText:
                            'Enter your normal 10-digit mobile number. No country code is needed.',
                      ),
                      validator: _validatePaymentPhone,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CheckoutSection(
                    title: 'Payment method',
                    subtitle: 'Validated now, charged only after the session',
                    icon: Icons.account_balance_wallet_outlined,
                    child: Column(
                      children: [
                        _PaymentMethodTile(
                          key: const Key('paymentMethod_upi'),
                          icon: Icons.qr_code_2,
                          title: 'UPI',
                          subtitle: 'Validate an approved sandbox UPI ID',
                          selected: _paymentOption == PaymentOption.upi,
                          onTap: () => _selectPaymentOption(PaymentOption.upi),
                        ),
                        const SizedBox(height: 8),
                        _PaymentMethodTile(
                          key: const Key('paymentMethod_card'),
                          icon: Icons.credit_card,
                          title: 'Credit / debit card',
                          subtitle: 'Validate a sandbox card before charging',
                          selected: _paymentOption == PaymentOption.card,
                          onTap: () => _selectPaymentOption(PaymentOption.card),
                        ),
                        const SizedBox(height: 8),
                        _PaymentMethodTile(
                          key: const Key('paymentMethod_wallet'),
                          icon: Icons.wallet_outlined,
                          title: 'VoltMapEV wallet',
                          subtitle: 'Authorize the sandbox wallet',
                          selected: _paymentOption == PaymentOption.wallet,
                          onTap: () =>
                              _selectPaymentOption(PaymentOption.wallet),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _paymentFields(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CheckoutSection(
                    title: 'Send receipt',
                    subtitle: 'Choose where to receive the final receipt',
                    icon: Icons.forward_to_inbox_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              key: const Key('receiptDelivery_app'),
                              avatar:
                                  const Icon(Icons.person_outline, size: 18),
                              label: const Text('Save in app'),
                              selected: _receiptDeliveryOption ==
                                  ReceiptDeliveryOption.app,
                              onSelected: _processing
                                  ? null
                                  : (_) => _selectReceiptDelivery(
                                        ReceiptDeliveryOption.app,
                                      ),
                            ),
                            ChoiceChip(
                              key: const Key('receiptDelivery_email'),
                              avatar:
                                  const Icon(Icons.email_outlined, size: 18),
                              label: const Text('Email'),
                              selected: _receiptDeliveryOption ==
                                  ReceiptDeliveryOption.email,
                              onSelected: _processing
                                  ? null
                                  : (_) => _selectReceiptDelivery(
                                        ReceiptDeliveryOption.email,
                                      ),
                            ),
                            ChoiceChip(
                              key: const Key('receiptDelivery_sms'),
                              avatar: const Icon(Icons.sms_outlined, size: 18),
                              label: const Text('Phone SMS'),
                              selected: _receiptDeliveryOption ==
                                  ReceiptDeliveryOption.sms,
                              onSelected: _processing
                                  ? null
                                  : (_) => _selectReceiptDelivery(
                                        ReceiptDeliveryOption.sms,
                                      ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _receiptDeliveryField(),
                        ),
                      ],
                    ),
                  ),
                  if (_processing) ...[
                    const SizedBox(height: 18),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text(
                      'Validating payment method…',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('authorizeButton'),
                    onPressed: _processing ? null : _authorizeAndStart,
                    icon: _processing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_outline),
                    label: Text(
                      _processing
                          ? 'Validating securely…'
                          : 'Validate & start charging',
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

  Widget _paymentFields() {
    switch (_paymentOption) {
      case PaymentOption.upi:
        return TextFormField(
          key: const Key('upiIdField'),
          controller: _upiController,
          enabled: !_processing,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'UPI ID',
            hintText: 'driver@upi',
            helperText:
                'Approved sandbox ID: driver@upi. Real UPI IDs are rejected and nothing is stored.',
            prefixIcon: Icon(Icons.alternate_email),
          ),
          validator: SandboxPaymentValidator.validateUpi,
        );
      case PaymentOption.card:
        return Column(
          key: const ValueKey('cardFields'),
          children: [
            TextFormField(
              key: const Key('cardholderField'),
              controller: _cardholderController,
              enabled: !_processing,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Cardholder name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: SandboxPaymentValidator.validateCardholder,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('cardNumberField'),
              controller: _cardNumberController,
              enabled: !_processing,
              keyboardType: TextInputType.number,
              inputFormatters: [_CardNumberInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Card number',
                hintText: '4242 4242 4242 4242',
                helperText:
                    'Approved sandbox card: 4242 4242 4242 4242. Details are not stored.',
                prefixIcon: Icon(Icons.credit_card),
              ),
              validator: SandboxPaymentValidator.validateCardNumber,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('expiryField'),
                    controller: _expiryController,
                    enabled: !_processing,
                    keyboardType: TextInputType.number,
                    inputFormatters: [_ExpiryInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Expiry',
                      hintText: 'MM/YY',
                    ),
                    validator: SandboxPaymentValidator.validateExpiry,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('cvvField'),
                    controller: _cvvController,
                    enabled: !_processing,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                    ),
                    validator: SandboxPaymentValidator.validateCvv,
                  ),
                ),
              ],
            ),
          ],
        );
      case PaymentOption.wallet:
        return Container(
          key: const ValueKey('walletFields'),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'VoltMapEV demo wallet is ready for authorization. Sandbox balance is unlimited and no real money is used.',
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _receiptDeliveryField() {
    switch (_receiptDeliveryOption) {
      case ReceiptDeliveryOption.app:
        return const Text(
          'The receipt will remain available under Profile → Payments & receipts.',
          key: ValueKey('receiptInAppMessage'),
        );
      case ReceiptDeliveryOption.email:
        return TextFormField(
          key: const Key('receiptEmailField'),
          controller: _receiptEmailController,
          enabled: !_processing,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Receipt email',
            hintText: 'name@example.com',
            prefixIcon: Icon(Icons.email_outlined),
            helperText:
                'No signup required. Live email delivery needs the production messaging service.',
          ),
          validator: _validateReceiptEmail,
        );
      case ReceiptDeliveryOption.sms:
        return Container(
          key: const ValueKey('receiptSmsMessage'),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sms_outlined),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The receipt will use the 10-digit mobile number entered for this payment. Live SMS delivery needs the production messaging service.',
                ),
              ),
            ],
          ),
        );
    }
  }

  void _selectPaymentOption(PaymentOption option) {
    if (_processing || option == _paymentOption) return;
    setState(() => _paymentOption = option);
  }

  void _selectReceiptDelivery(ReceiptDeliveryOption option) {
    if (_processing || option == _receiptDeliveryOption) return;
    setState(() => _receiptDeliveryOption = option);
  }

  Future<void> _authorizeAndStart() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final paymentMethod = _paymentMethodLabel();
    final paymentPhone = _paymentPhoneController.text.trim();
    final receiptDeliveryMethod = _receiptDeliveryMethodLabel();
    final receiptDeliveryDestination =
        _receiptDeliveryOption == ReceiptDeliveryOption.email
            ? _receiptEmailController.text.trim()
            : _receiptDeliveryOption == ReceiptDeliveryOption.sms
                ? paymentPhone
                : null;

    _upiController.clear();
    _cardholderController.clear();
    _cardNumberController.clear();
    _expiryController.clear();
    _cvvController.clear();
    setState(() => _processing = false);

    final receipt = await Navigator.of(context).push<ChargingReceipt>(
      MaterialPageRoute<ChargingReceipt>(
        builder: (_) => ChargingSessionScreen(
          station: widget.station,
          connectorType: _connectorType,
          energyLimitKwh: _energyKwh,
          paymentMethod: paymentMethod,
          customerPhone: paymentPhone,
          receiptDeliveryMethod: receiptDeliveryMethod,
          receiptDeliveryDestination: receiptDeliveryDestination,
        ),
      ),
    );
    if (mounted && receipt != null) {
      Navigator.of(context).pop(receipt);
    }
  }

  String _paymentMethodLabel() {
    switch (_paymentOption) {
      case PaymentOption.upi:
        return SandboxPaymentValidator.maskUpi(_upiController.text);
      case PaymentOption.card:
        return SandboxPaymentValidator.maskCard(_cardNumberController.text);
      case PaymentOption.wallet:
        return 'VoltMapEV demo wallet';
    }
  }

  String _receiptDeliveryMethodLabel() {
    switch (_receiptDeliveryOption) {
      case ReceiptDeliveryOption.app:
        return 'In app';
      case ReceiptDeliveryOption.email:
        return 'Email';
      case ReceiptDeliveryOption.sms:
        return 'SMS';
    }
  }

  String? _validateReceiptEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter an email for the receipt';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    return valid ? null : 'Enter a valid email address';
  }

  String? _validatePaymentPhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Enter a mobile number for payment';
    return RegExp(r'^[6-9]\d{9}$').hasMatch(phone)
        ? null
        : 'Enter a valid 10-digit Indian mobile number';
  }

  static String _currency(double value) => '₹${value.toStringAsFixed(2)}';
}

class ChargingSessionScreen extends ConsumerStatefulWidget {
  const ChargingSessionScreen({
    super.key,
    required this.station,
    required this.connectorType,
    required this.energyLimitKwh,
    required this.paymentMethod,
    required this.customerPhone,
    required this.receiptDeliveryMethod,
    this.receiptDeliveryDestination,
  });

  final ChargingStation station;
  final String connectorType;
  final double energyLimitKwh;
  final String paymentMethod;
  final String customerPhone;
  final String receiptDeliveryMethod;
  final String? receiptDeliveryDestination;

  @override
  ConsumerState<ChargingSessionScreen> createState() =>
      _ChargingSessionScreenState();
}

class _ChargingSessionScreenState extends ConsumerState<ChargingSessionScreen> {
  static const _platformFee = 5.0;
  static const _meterInterval = Duration(milliseconds: 600);
  static const _energyPerTick = 1.25;

  Timer? _meterTimer;
  double _energyDelivered = 0;
  bool _finishing = false;
  bool _stoppedAutomatically = false;
  ChargingReceipt? _receipt;

  double get _energyCharge => _energyDelivered * widget.station.pricePerKwh;
  double get _currentTotal => _energyCharge + _platformFee;
  bool get _complete => _receipt != null;

  @override
  void initState() {
    super.initState();
    _meterTimer = Timer.periodic(_meterInterval, (_) {
      if (!mounted || _finishing || _complete) return;
      final nextEnergy = math.min(
        widget.energyLimitKwh,
        _energyDelivered + _energyPerTick,
      );
      setState(() => _energyDelivered = nextEnergy.toDouble());
      if (_energyDelivered >= widget.energyLimitKwh) {
        _meterTimer?.cancel();
        unawaited(_finishSession(automatic: true));
      }
    });
  }

  @override
  void dispose() {
    _meterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = (_energyDelivered / widget.energyLimitKwh).clamp(0.0, 1.0);
    return PopScope(
      canPop: _complete,
      child: Scaffold(
        appBar: AppBar(title: const Text('Live charging session')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 126),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _complete
                        ? colors.primaryContainer
                        : colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _complete
                            ? Icons.check_circle_rounded
                            : Icons.bolt_rounded,
                        size: 34,
                        color: _complete ? colors.primary : colors.tertiary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _complete
                                  ? 'Charging complete'
                                  : 'Charging in progress',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _complete
                                  ? 'Final payment captured after charging finished.'
                                  : 'Payment method verified. ₹0.00 was charged upfront.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.station.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Chip(
                              avatar: Icon(
                                _complete ? Icons.check : Icons.electric_bolt,
                                size: 17,
                              ),
                              label: Text(_complete ? 'Complete' : 'Live'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_energyDelivered.toStringAsFixed(2)} of ${widget.energyLimitKwh.toStringAsFixed(0)} kWh delivered',
                          key: const Key('meteredEnergyText'),
                        ),
                        const SizedBox(height: 20),
                        _ReceiptRow(
                          label: 'Connector',
                          value: widget.connectorType,
                        ),
                        _ReceiptRow(
                          label: 'Energy rate',
                          value:
                              '₹${widget.station.pricePerKwh.toStringAsFixed(2)}/kWh',
                        ),
                        _ReceiptRow(
                          label: 'Payment method',
                          value: widget.paymentMethod,
                        ),
                        _ReceiptRow(
                          label: 'Mobile number',
                          value: _maskPhone(widget.customerPhone),
                        ),
                        _ReceiptRow(
                          label: 'Receipt delivery',
                          value: _receiptDeliverySummary,
                        ),
                        _ReceiptRow(
                          label: 'Energy cost',
                          value: _ChargingCheckoutScreenState._currency(
                            _energyCharge,
                          ),
                        ),
                        const _ReceiptRow(
                          label: 'Taxes',
                          value: '₹0.00',
                        ),
                        const _ReceiptRow(
                          label: 'Platform fee',
                          value: '₹5.00',
                        ),
                        _ReceiptRow(
                          label:
                              _complete ? 'Final payment' : 'Payable at stop',
                          value: _ChargingCheckoutScreenState._currency(
                            _currentTotal,
                          ),
                          last: !_complete,
                        ),
                        if (_complete) ...[
                          _ReceiptRow(label: 'Receipt', value: _receipt!.id),
                          _ReceiptRow(
                            label: 'Charging session',
                            value: _receipt!.chargingSessionId,
                          ),
                          _ReceiptRow(
                            label: 'Payment reference',
                            value: _receipt!.paymentReference,
                          ),
                          _ReceiptRow(
                            label: 'Delivery status',
                            value: _receipt!.deliveryStatus,
                          ),
                          _ReceiptRow(
                            label: 'Status',
                            value: _stoppedAutomatically
                                ? 'Paid • Automatic stop'
                                : 'Paid • Driver stop',
                            last: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _complete
                      ? _completionReceiptMessage
                      : 'The session stops automatically at ${widget.energyLimitKwh.toStringAsFixed(0)} kWh. You can stop earlier and pay only for the delivered energy plus the ₹5 platform fee.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: Key(
                      _complete ? 'chargingDoneButton' : 'stopChargingButton',
                    ),
                    onPressed: _complete
                        ? () => Navigator.of(context).pop(_receipt)
                        : _energyDelivered > 0 && !_finishing
                            ? () => _finishSession(automatic: false)
                            : null,
                    icon: _finishing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_complete ? Icons.done : Icons.stop_circle),
                    label: Text(
                      _complete
                          ? 'Done'
                          : _finishing
                              ? 'Finalizing payment…'
                              : 'Stop charging & pay ${_ChargingCheckoutScreenState._currency(_currentTotal)}',
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

  Future<void> _finishSession({required bool automatic}) async {
    if (_finishing || _complete || _energyDelivered <= 0) return;
    _meterTimer?.cancel();
    setState(() {
      _finishing = true;
      _stoppedAutomatically = automatic;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final billedEnergy = double.parse(_energyDelivered.toStringAsFixed(2));
    final bill = ChargingBilling.calculate(
      confirmedUnitsKwh: billedEnergy,
      ratePerKwh: widget.station.pricePerKwh,
      taxRate: 0,
      serviceFee: _platformFee,
    );
    final now = DateTime.now();
    final sessionId =
        'SANDBOX-SESSION-${now.microsecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final paymentReference =
        'SANDBOX-PAY-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    final deliveryDestination = _maskReceiptDestination(
      widget.receiptDeliveryMethod,
      widget.receiptDeliveryDestination,
    );
    final deliveryStatus = widget.receiptDeliveryMethod == 'In app'
        ? 'Saved in app'
        : 'Not sent — sandbox contact is not verified';
    final deliveryAttempts = widget.receiptDeliveryMethod == 'In app'
        ? const <ReceiptDeliveryAttempt>[]
        : <ReceiptDeliveryAttempt>[
            ReceiptDeliveryAttempt(
              channel: widget.receiptDeliveryMethod.toLowerCase(),
              destination: deliveryDestination ?? 'masked',
              status: 'blocked_unverified',
              attemptedAt: now,
              attemptNumber: 1,
              errorCode: 'contact_not_verified',
            ),
          ];
    final receipt = ChargingReceipt(
      id: 'VM-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      stationId: widget.station.id,
      stationName: widget.station.name,
      connectorType: widget.connectorType,
      energyKwh: billedEnergy,
      ratePerKwh: bill.ratePerKwh,
      energySubtotal: bill.energySubtotal,
      taxAmount: bill.taxAmount,
      serviceFee: bill.serviceFee,
      amount: bill.total,
      paymentMethod: widget.paymentMethod,
      paymentReference: paymentReference,
      chargingSessionId: sessionId,
      paymentVerified: true,
      meterReadingConfirmed: true,
      environment: 'sandbox',
      customerPhone: _maskPhone(widget.customerPhone),
      customerEmail:
          widget.receiptDeliveryMethod == 'Email' ? deliveryDestination : null,
      phoneVerified: false,
      emailVerified: false,
      createdAt: now,
      deliveryMethod: widget.receiptDeliveryMethod,
      deliveryDestination: deliveryDestination,
      deliveryStatus: deliveryStatus,
      deliveryAttempts: deliveryAttempts,
    );
    await ref.read(appStateProvider).saveChargingReceipt(receipt);
    if (!mounted) return;
    setState(() {
      _receipt = receipt;
      _finishing = false;
    });
  }

  String get _receiptDeliverySummary {
    final destination = _maskReceiptDestination(
      widget.receiptDeliveryMethod,
      widget.receiptDeliveryDestination,
    );
    return destination == null
        ? widget.receiptDeliveryMethod
        : '${widget.receiptDeliveryMethod} • $destination';
  }

  String get _completionReceiptMessage {
    if (widget.receiptDeliveryMethod == 'In app') {
      return 'The receipt is saved under Profile → Payments & receipts. No full UPI ID, card number, expiry, or CVV was stored.';
    }
    return 'The receipt is saved under Profile → Payments & receipts. Sandbox contacts are not verified, so no ${widget.receiptDeliveryMethod} message was sent.';
  }

  static String? _maskReceiptDestination(
    String method,
    String? destination,
  ) {
    if (destination == null || destination.isEmpty) return null;
    if (method == 'Email') {
      final parts = destination.split('@');
      if (parts.length != 2) return '••••';
      final local = parts.first;
      final visible = local.isEmpty ? '' : local.substring(0, 1);
      return '$visible•••@${parts.last}';
    }
    final digits = destination.replaceAll(RegExp(r'\D'), '');
    return _maskPhone(digits);
  }

  static String _maskPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return '••••••••••';
    return '••••••${digits.substring(digits.length - 4)}';
  }
}

class _ProductionPaymentGate extends StatelessWidget {
  const _ProductionPaymentGate({required this.station});

  final ChargingStation station;

  @override
  Widget build(BuildContext context) {
    final backendConfigured = AppRuntimeConfig.hasSecurePaymentBackend;
    return Scaffold(
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
                    CircleAvatar(
                      radius: 31,
                      child: Icon(
                        backendConfigured
                            ? Icons.ev_station_rounded
                            : Icons.lock_clock_outlined,
                        size: 31,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      backendConfigured
                          ? 'Charging is not enabled at this station'
                          : 'Payments are temporarily unavailable',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      backendConfigured
                          ? '${station.name} does not yet have a verified live charger-session integration. No payment was created.'
                          : 'The secure production payment and meter-verification service is not configured. No payment details were requested and no charge was attempted.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    const _ProductionSafetyItem(
                      icon: Icons.credit_card_off_outlined,
                      text:
                          'VoltMapEV never collects card numbers, CVVs, UPI PINs or banking credentials.',
                    ),
                    const _ProductionSafetyItem(
                      icon: Icons.verified_user_outlined,
                      text:
                          'A payment becomes successful only after a provider-signed server webhook and confirmed meter reading.',
                    ),
                    const _ProductionSafetyItem(
                      icon: Icons.receipt_long_outlined,
                      text:
                          'Receipts are created only for verified payments and verified contact destinations.',
                    ),
                    const SizedBox(height: 14),
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
}

class _ProductionSafetyItem extends StatelessWidget {
  const _ProductionSafetyItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 11),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _CheckoutJourneyHeader extends StatelessWidget {
  const _CheckoutJourneyHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('chargePayJourneyHeader'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF073D34), Color(0xFF061B31)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Charge. Pay. Get your receipt.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Confirm the charger and spending limit before the session starts.',
            style: TextStyle(color: Color(0xFFB8CED6)),
          ),
          SizedBox(height: 18),
          Row(
            children: [
              _JourneyStep(
                icon: Icons.check_rounded,
                label: 'Charger',
                active: false,
                complete: true,
              ),
              _JourneyLine(active: true),
              _JourneyStep(
                icon: Icons.bolt_rounded,
                label: 'Charge',
                active: true,
                complete: false,
              ),
              _JourneyLine(active: false),
              _JourneyStep(
                icon: Icons.receipt_long_outlined,
                label: 'Receipt',
                active: false,
                complete: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JourneyStep extends StatelessWidget {
  const _JourneyStep({
    required this.icon,
    required this.label,
    required this.active,
    required this.complete,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || complete
                  ? const Color(0xFF57DE80)
                  : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: active || complete
                    ? const Color(0xFF57DE80)
                    : Colors.white38,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color:
                  active || complete ? const Color(0xFF05271D) : Colors.white70,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: active || complete ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      );
}

class _JourneyLine extends StatelessWidget {
  const _JourneyLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 20),
          color: active ? const Color(0xFF57DE80) : Colors.white24,
        ),
      );
}

class _DemoNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'SANDBOX BUILD — test data only. No money is collected. driver@upi and the test card work only here; never enter real payment credentials.',
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutSection extends StatelessWidget {
  const _CheckoutSection({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
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
                      if (subtitle != null) Text(subtitle!),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : colors.surface,
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(subtitle),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? colors.primary : colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : null;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(
      0,
      digits.length > 16 ? 16 : digits.length,
    );
    final chunks = <String>[];
    for (var index = 0; index < limited.length; index += 4) {
      chunks.add(
        limited.substring(
          index,
          index + 4 > limited.length ? limited.length : index + 4,
        ),
      );
    }
    final formatted = chunks.join(' ');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, digits.length > 4 ? 4 : digits.length);
    final formatted = limited.length <= 2
        ? limited
        : '${limited.substring(0, 2)}/${limited.substring(2)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
