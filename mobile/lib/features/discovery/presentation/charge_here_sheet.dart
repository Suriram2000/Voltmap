import 'package:flutter/material.dart';

/// Operator charging guidance when in-app checkout is not available.
Future<void> showChargeHereSheet({
  required BuildContext context,
  required String stationName,
  required String operatorName,
  required String address,
  required Future<void> Function() onDirections,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Charge at this station',
                style: Theme.of(sheetContext).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(stationName,
                key: const Key('chargeHereStationName'),
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(operatorName),
            Text(address),
            const SizedBox(height: 20),
            const Text(
                '1. Check the connector, availability and final price at the station.'),
            const SizedBox(height: 12),
            const Text(
                '2. Use the operator’s app or scan the QR code on the charger.'),
            const SizedBox(height: 12),
            const Text(
                '3. Follow the operator’s instructions to connect your vehicle, pay and start charging.'),
            const SizedBox(height: 20),
            const Text(
                'Starting and paying for this session happens with the charging operator. VoltMapEV has not started a session or taken payment.'),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('chargeHereDirectionsButton'),
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await onDirections();
              },
              icon: const Icon(Icons.navigation_rounded),
              label: const Text('Get directions'),
            ),
          ],
        ),
      ),
    ),
  );
}
