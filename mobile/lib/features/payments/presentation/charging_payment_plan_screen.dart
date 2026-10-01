import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/charging_payment_plan.dart';
import '../../../shared/state/app_state.dart';

/// Lets a driver choose an authorization preference before a real operator
/// payment integration is available. This screen never collects payment data.
class ChargingPaymentPlanScreen extends ConsumerStatefulWidget {
  const ChargingPaymentPlanScreen({super.key});

  @override
  ConsumerState<ChargingPaymentPlanScreen> createState() =>
      _ChargingPaymentPlanScreenState();
}

class _ChargingPaymentPlanScreenState
    extends ConsumerState<ChargingPaymentPlanScreen> {
  late ChargingPaymentPlanKind _kind;
  late double _maximumAmount;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = ref.read(appStateProvider).chargingPaymentPlan;
    _kind = plan.kind;
    _maximumAmount = plan.maximumAmountInr.clamp(250, 2000).toDouble();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Charging payment plan')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Decide how you want to approve a charge',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This saves a preference for VoltMapEV. It is not a subscription, wallet balance, stored card, or payment authorization.',
                ),
                const SizedBox(height: 20),
                _PlanOption(
                  title: 'Pay after charging',
                  description:
                      'Approve the session maximum, then pay only for energy confirmed by the charger and provider.',
                  icon: Icons.receipt_long_outlined,
                  selected: _kind == ChargingPaymentPlanKind.payAsYouCharge,
                  onTap: _saving
                      ? null
                      : () => setState(
                            () =>
                                _kind = ChargingPaymentPlanKind.payAsYouCharge,
                          ),
                ),
                const SizedBox(height: 12),
                _PlanOption(
                  title: 'Charging budget guard',
                  description:
                      'Use a preferred maximum for each charging authorization. Your selected operator must support the final limit.',
                  icon: Icons.savings_outlined,
                  selected: _kind == ChargingPaymentPlanKind.budgetGuard,
                  onTap: _saving
                      ? null
                      : () => setState(
                            () => _kind = ChargingPaymentPlanKind.budgetGuard,
                          ),
                ),
                if (_kind == ChargingPaymentPlanKind.budgetGuard) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preferred authorization maximum',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${_maximumAmount.toStringAsFixed(0)} per charging session',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Slider(
                            key: const Key('paymentPlanBudgetSlider'),
                            value: _maximumAmount,
                            min: 250,
                            max: 2000,
                            divisions: 7,
                            label: '₹${_maximumAmount.toStringAsFixed(0)}',
                            onChanged: _saving
                                ? null
                                : (value) => setState(
                                      () => _maximumAmount = value,
                                    ),
                          ),
                          const Text(
                            'The final total can be lower because you pay only for verified delivered energy and disclosed fees. VoltMapEV will never increase this preference without you selecting a new amount.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline_rounded),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Live payment becomes available only after a connected operator, payment provider, verified meter readings, and provider-signed confirmation. Never share a UPI PIN, card number, or CVV with VoltMapEV.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('savePaymentPlanButton'),
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Save payment plan'),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(appStateProvider).setChargingPaymentPlan(
          ChargingPaymentPlan(
            kind: _kind,
            maximumAmountInr: _maximumAmount,
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.all(18),
          leading: Icon(icon),
          title: Text(title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(description),
          ),
          trailing: Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      );
}
