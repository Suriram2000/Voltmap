import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/charging_receipt.dart';
import '../../../shared/models/charging_station.dart';
import '../../../shared/services/sandbox_payment_validator.dart';
import '../../../shared/state/app_state.dart';

enum PaymentOption { upi, card, wallet }

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

  late String _connectorType;
  double _energyKwh = 20;
  PaymentOption _paymentOption = PaymentOption.upi;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_processing,
      child: Scaffold(
        appBar: AppBar(title: const Text('Set up charging')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
                children: [
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
                              style: Theme.of(context).textTheme.titleMedium
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

  void _selectPaymentOption(PaymentOption option) {
    if (_processing || option == _paymentOption) return;
    setState(() => _paymentOption = option);
    _formKey.currentState?.reset();
  }

  Future<void> _authorizeAndStart() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final paymentMethod = _paymentMethodLabel();

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

  static String _currency(double value) => '₹${value.toStringAsFixed(2)}';
}

class ChargingSessionScreen extends ConsumerStatefulWidget {
  const ChargingSessionScreen({
    super.key,
    required this.station,
    required this.connectorType,
    required this.energyLimitKwh,
    required this.paymentMethod,
  });

  final ChargingStation station;
  final String connectorType;
  final double energyLimitKwh;
  final String paymentMethod;

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
                              style: Theme.of(context).textTheme.titleLarge
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
                                style: Theme.of(context).textTheme.titleMedium
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
                          label: 'Energy cost',
                          value: _ChargingCheckoutScreenState._currency(
                            _energyCharge,
                          ),
                        ),
                        const _ReceiptRow(
                          label: 'Platform fee',
                          value: '₹5.00',
                        ),
                        _ReceiptRow(
                          label: _complete
                              ? 'Final payment'
                              : 'Payable at stop',
                          value: _ChargingCheckoutScreenState._currency(
                            _currentTotal,
                          ),
                          last: !_complete,
                        ),
                        if (_complete) ...[
                          _ReceiptRow(label: 'Receipt', value: _receipt!.id),
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
                      ? 'The receipt is saved under Profile → Payments & receipts. No full UPI ID, card number, expiry, or CVV was stored.'
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
    final amount = double.parse(
      (billedEnergy * widget.station.pricePerKwh + _platformFee)
          .toStringAsFixed(2),
    );
    final now = DateTime.now();
    final receipt = ChargingReceipt(
      id: 'VM-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      stationId: widget.station.id,
      stationName: widget.station.name,
      connectorType: widget.connectorType,
      energyKwh: billedEnergy,
      amount: amount,
      paymentMethod: widget.paymentMethod,
      createdAt: now,
    );
    await ref.read(appStateProvider).saveChargingReceipt(receipt);
    if (!mounted) return;
    setState(() {
      _receipt = receipt;
      _finishing = false;
    });
  }
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
              'Postpaid demo — no money is collected before charging. Only the approved sandbox UPI ID, card, or wallet can authorize a session; never enter real payment credentials.',
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
                        style: Theme.of(context).textTheme.titleMedium
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
