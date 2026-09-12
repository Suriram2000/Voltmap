import 'package:flutter/material.dart';
import '../../../shared/models/charging_session_status.dart';

class ChargingProgressCard extends StatelessWidget {
  const ChargingProgressCard({super.key, required this.snapshot, this.now});
  final ChargingSessionStatus? snapshot;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    final stale = data?.isStale(now ?? DateTime.now()) ?? false;
    return Card(
      key: const Key('chargingProgressCard'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                data == null
                    ? 'Waiting for operator update'
                    : stale
                        ? 'Last reported: ${data.label}'
                        : data.label,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (data == null)
              const Text(
                  'No live meter reading has been received. Check the operator app or charger; do not assume charging has started.')
            else ...[
              const Text('1 unit = 1 kWh'),
              _line('Price per unit',
                  '₹${data.ratePerKwh.toStringAsFixed(2)}/kWh'),
              _line('Units delivered',
                  '${data.energyKwh.toStringAsFixed(3)} kWh'),
              _line(
                  'Energy cost', '₹${data.energySubtotal.toStringAsFixed(2)}'),
              _line('Taxes', '₹${data.taxAmount.toStringAsFixed(2)}'),
              _line('Fees', '₹${data.serviceFee.toStringAsFixed(2)}'),
              const Divider(),
              _line(data.isComplete ? 'Final metered total' : 'Running total',
                  '₹${data.totalAmount.toStringAsFixed(2)}'),
              Text('Operator update: ${data.updatedAt.toLocal()}'),
              if (stale)
                const Text(
                    'Update delayed. These are the last reported values; current energy and cost may be higher.'),
              const SizedBox(height: 8),
              Text(data.isComplete
                  ? 'Charging has ended. Payment confirmation and the final receipt are checked separately.'
                  : 'Stop charging using the operator app or charger controls. Wait for the operator to confirm the session has ended.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(label),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
          ],
        ),
      );
}
