import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/charging_receipt.dart';
import '../../../shared/models/charging_station.dart';
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
        appBar: AppBar(title: const Text('Charging checkout')),
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
                            const Expanded(child: Text('Charging limit')),
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
                          'You authorize up to this amount. The demo session stops at the selected energy limit.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CheckoutSection(
                    title: 'Amount summary',
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
                          label: 'Maximum payable',
                          value: _currency(_total),
                          emphasized: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CheckoutSection(
                    title: 'Payment method',
                    subtitle: 'Choose one secure demo method',
                    icon: Icons.account_balance_wallet_outlined,
                    child: Column(
                      children: [
                        _PaymentMethodTile(
                          key: const Key('paymentMethod_upi'),
                          icon: Icons.qr_code_2,
                          title: 'UPI',
                          subtitle: 'Pay using a test UPI ID',
                          selected: _paymentOption == PaymentOption.upi,
                          onTap: () => _selectPaymentOption(PaymentOption.upi),
                        ),
                        const SizedBox(height: 8),
                        _PaymentMethodTile(
                          key: const Key('paymentMethod_card'),
                          icon: Icons.credit_card,
                          title: 'Credit / debit card',
                          subtitle: 'Visa, Mastercard, or RuPay test card',
                          selected: _paymentOption == PaymentOption.card,
                          onTap: () => _selectPaymentOption(PaymentOption.card),
                        ),
                        const SizedBox(height: 8),
                        _PaymentMethodTile(
                          key: const Key('paymentMethod_wallet'),
                          icon: Icons.wallet_outlined,
                          title: 'VoltMap wallet',
                          subtitle: 'Instant sandbox wallet payment',
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
                      'Authorizing demo payment…',
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
                    key: const Key('payButton'),
                    onPressed: _processing ? null : _pay,
                    icon: _processing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_outline),
                    label: Text(
                      _processing
                          ? 'Processing securely…'
                          : 'Pay ${_currency(_total)}',
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
            helperText: 'Use a test ID such as driver@upi. It is not stored.',
            prefixIcon: Icon(Icons.alternate_email),
          ),
          validator: _validateUpi,
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
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Enter the cardholder name'
                  : null,
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
                    'Use a test card number. Card details are not stored.',
                prefixIcon: Icon(Icons.credit_card),
              ),
              validator: _validateCardNumber,
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
                    validator: _validateExpiry,
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
                    validator: (value) =>
                        RegExp(r'^\d{3,4}$').hasMatch(value ?? '')
                            ? null
                            : 'Enter 3 or 4 digits',
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
                  'VoltMap demo wallet is ready. Sandbox balance is unlimited and no real money is used.',
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

  Future<void> _pay() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _processing = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final now = DateTime.now();
    final receipt = ChargingReceipt(
      id: 'VM-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      stationId: widget.station.id,
      stationName: widget.station.name,
      connectorType: _connectorType,
      energyKwh: _energyKwh,
      amount: _total,
      paymentMethod: _paymentMethodLabel(),
      createdAt: now,
    );

    _upiController.clear();
    _cardholderController.clear();
    _cardNumberController.clear();
    _expiryController.clear();
    _cvvController.clear();
    await ref.read(appStateProvider).saveChargingReceipt(receipt);
    if (!mounted) return;
    setState(() => _processing = false);

    final startCharging = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ChargingReceiptScreen(receipt: receipt),
      ),
    );
    if (mounted && startCharging == true) {
      Navigator.of(context).pop(receipt);
    }
  }

  String _paymentMethodLabel() {
    switch (_paymentOption) {
      case PaymentOption.upi:
        final parts = _upiController.text.trim().split('@');
        final handle = parts.first;
        final masked =
            handle.length <= 2 ? '••' : '${handle.substring(0, 2)}••';
        return 'UPI $masked@${parts.last}';
      case PaymentOption.card:
        final digits = _digits(_cardNumberController.text);
        return 'Card ending ${digits.substring(digits.length - 4)}';
      case PaymentOption.wallet:
        return 'VoltMap demo wallet';
    }
  }

  static String? _validateUpi(String? value) {
    final trimmed = value?.trim() ?? '';
    return RegExp(r'^[a-zA-Z0-9._-]{2,}@[a-zA-Z]{2,}$').hasMatch(trimmed)
        ? null
        : 'Enter a valid test UPI ID';
  }

  static String? _validateCardNumber(String? value) {
    final digits = _digits(value ?? '');
    return digits.length == 16 && _passesLuhn(digits)
        ? null
        : 'Enter a valid 16-digit test card';
  }

  static String? _validateExpiry(String? value) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(value ?? '');
    if (match == null) return 'Use MM/YY';
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    if (month < 1 || month > 12) return 'Invalid month';
    final now = DateTime.now();
    if (year < now.year || (year == now.year && month < now.month)) {
      return 'Card is expired';
    }
    return null;
  }

  static bool _passesLuhn(String digits) {
    var sum = 0;
    var doubleDigit = false;
    for (var index = digits.length - 1; index >= 0; index--) {
      var digit = int.parse(digits[index]);
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      doubleDigit = !doubleDigit;
    }
    return sum % 10 == 0;
  }

  static String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  static String _currency(double value) => '₹${value.toStringAsFixed(2)}';
}

class ChargingReceiptScreen extends StatelessWidget {
  const ChargingReceiptScreen({super.key, required this.receipt});

  final ChargingReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment receipt')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Icon(Icons.check_circle, color: colors.primary, size: 76),
              const SizedBox(height: 12),
              Text(
                'Payment successful',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                )
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _ChargingCheckoutScreenState._currency(receipt.amount),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                )
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _ReceiptRow(label: 'Station', value: receipt.stationName),
                      _ReceiptRow(
                        label: 'Charging limit',
                        value: '${receipt.energyKwh.toStringAsFixed(0)} kWh',
                      ),
                      _ReceiptRow(
                          label: 'Connector', value: receipt.connectorType),
                      _ReceiptRow(
                          label: 'Payment', value: receipt.paymentMethod),
                      _ReceiptRow(label: 'Transaction', value: receipt.id),
                      _ReceiptRow(
                        label: 'Status',
                        value: 'Paid • Demo',
                        last: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'This receipt is saved locally under Profile → Payments & receipts. No card number, CVV, or full UPI ID is stored.',
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
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('startChargingButton'),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.bolt),
                  label: const Text('Start charging'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
              'Demo checkout — no real money is charged. Use only the test details shown below, never real payment credentials.',
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
