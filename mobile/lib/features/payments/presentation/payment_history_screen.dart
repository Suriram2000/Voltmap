import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../shared/models/charging_receipt.dart';
import '../../../shared/services/receipt_download_service.dart';
import '../../../shared/services/secure_charging_api.dart';
import '../../../shared/state/app_state.dart';
import 'charging_receipt_screen.dart';

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(appStateProvider).chargingReceipts;
    return Scaffold(
      appBar: AppBar(title: const Text('Payments & receipts')),
      body: receipts.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 52),
                    SizedBox(height: 14),
                    Text(
                      'No charging payments yet',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Verified charging receipts will appear here. No raw card, UPI PIN, CVV, or banking credentials are stored.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                  itemCount: receipts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _ReceiptCard(receipt: receipts[index]);
                  },
                ),
              ),
            ),
    );
  }
}

class _ReceiptCard extends StatefulWidget {
  const _ReceiptCard({required this.receipt});

  final ChargingReceipt receipt;

  @override
  State<_ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends State<_ReceiptCard> {
  bool _exporting = false;
  bool _retrying = false;

  ChargingReceipt get receipt => widget.receipt;

  Future<void> _download() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final message = await const ReceiptDownloadService().download(receipt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export this receipt.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _retryDelivery() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      final method = receipt.deliveryMethod.toLowerCase();
      final channel = method.contains('email') ? 'email' : 'whatsapp';
      await SecureChargingApi().retryReceiptDelivery(
        receiptId: receipt.id,
        channel: channel,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Receipt delivery retry queued. Updated delivery status will be recorded by the server.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not retry delivery: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: receipt.isVerifiedSuccessful
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.tertiaryContainer,
          child: Icon(
            receipt.isVerifiedSuccessful
                ? Icons.verified_rounded
                : Icons.science_outlined,
          ),
        ),
        title: Text(
          receipt.stationName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${receipt.energyKwh.toStringAsFixed(2)} kWh • ₹${receipt.amount.toStringAsFixed(2)} • ${_formatDate(receipt.createdAt)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        children: [
          const Divider(),
          _detail('Receipt', receipt.id),
          _detail('Charging session', receipt.chargingSessionId),
          _detail('Station', '${receipt.stationName} (${receipt.stationId})'),
          _detail('Charger', receipt.connectorType),
          _detail(
              'Units consumed', '${receipt.energyKwh.toStringAsFixed(2)} kWh'),
          _detail(
              'Rate per unit', '₹${receipt.ratePerKwh.toStringAsFixed(2)}/kWh'),
          _detail('Energy subtotal', '₹${receipt.subtotal.toStringAsFixed(2)}'),
          _detail('Taxes', '₹${receipt.taxAmount.toStringAsFixed(2)}'),
          _detail('Service fee', '₹${receipt.serviceFee.toStringAsFixed(2)}'),
          _detail('Total', '₹${receipt.amount.toStringAsFixed(2)}'),
          _detail('Payment reference', receipt.paymentReference),
          _detail('Payment method', receipt.paymentMethod),
          _detail('Delivery', receipt.deliveryStatus),
          if (receipt.deliveryAttempts.isNotEmpty)
            _detail(
              'Delivery attempts',
              receipt.deliveryAttempts
                  .map((attempt) =>
                      '${attempt.channel} #${attempt.attemptNumber}: ${attempt.status}')
                  .join('\n'),
            ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_canRetryDelivery)
                OutlinedButton.icon(
                  key: ValueKey('retryReceipt_${receipt.id}'),
                  onPressed: _retrying ? null : _retryDelivery,
                  icon: _retrying
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Retry delivery'),
                ),
              OutlinedButton.icon(
                key: ValueKey('viewReceipt_${receipt.id}'),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ChargingReceiptScreen(receipt: receipt),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View receipt'),
              ),
              FilledButton.tonalIcon(
                key: ValueKey('downloadReceipt_${receipt.id}'),
                onPressed: _exporting ? null : _download,
                icon: _exporting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: const Text('Download'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _canRetryDelivery =>
      AppRuntimeConfig.hasSecurePaymentBackend &&
      receipt.isVerifiedSuccessful &&
      receipt.deliveryMethod.toLowerCase() != 'in app' &&
      !receipt.deliveryAttempts.any((attempt) => attempt.delivered);

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 145,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(value.isEmpty ? 'Not available' : value)),
          ],
        ),
      );

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} $hour:$minute $period';
  }
}
