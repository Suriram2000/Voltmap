import 'package:flutter/material.dart';

import '../../../shared/models/charging_receipt.dart';
import '../../../shared/models/charging_station.dart';
import '../../../shared/services/receipt_download_service.dart';
import '../../discovery/presentation/station_feedback_dialog.dart';

class ChargingReceiptScreen extends StatefulWidget {
  const ChargingReceiptScreen({
    super.key,
    required this.receipt,
    this.station,
  });

  final ChargingReceipt receipt;
  final ChargingStation? station;

  @override
  State<ChargingReceiptScreen> createState() => _ChargingReceiptScreenState();
}

class _ChargingReceiptScreenState extends State<ChargingReceiptScreen> {
  bool _exporting = false;

  ChargingReceipt get receipt => widget.receipt;
  bool get _isProductionVerified => receipt.isVerifiedSuccessful;
  bool get _isSandbox => receipt.environment == 'sandbox';

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

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF031429);
    const panel = Color(0xFF073349);
    const green = Color(0xFF57DE80);
    const muted = Color(0xFFB9C8D8);

    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: green,
          surface: panel,
          onSurface: Colors.white,
        ),
      ),
      child: Scaffold(
        key: const Key('chargingReceiptScreen'),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Charging receipt'),
          actions: [
            IconButton(
              key: const Key('downloadReceiptButton'),
              tooltip: 'Download receipt',
              onPressed: _exporting ? null : _download,
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
            ),
          ],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.35,
              colors: [Color(0xFF084A56), background],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
                children: [
                  const _SuccessSeal(),
                  const SizedBox(height: 14),
                  Text(
                    'Session completed',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isProductionVerified
                        ? 'Payment and meter reading verified'
                        : _isSandbox
                            ? 'Sandbox payment and meter flow completed'
                            : 'Charging session summary',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 22),
                  _ReceiptPanel(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _StationIllustration(),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                receipt.stationName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 7),
                              if (widget.station != null)
                                _IconText(
                                  icon: Icons.location_on_outlined,
                                  text: widget.station!.formattedAddress,
                                ),
                              _IconText(
                                icon: Icons.electrical_services_outlined,
                                text: receipt.connectorType,
                              ),
                              _IconText(
                                icon: Icons.calendar_today_outlined,
                                text: _formatDate(receipt.createdAt),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ReceiptPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: green),
                            SizedBox(width: 8),
                            Text(
                              'Energy delivered',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: receipt.energyKwh.toStringAsFixed(2),
                                style: const TextStyle(
                                  color: green,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const TextSpan(
                                text: ' kWh',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 30),
                        _BillingRow(
                          label: 'Rate per unit',
                          value: _currency(receipt.ratePerKwh, suffix: '/kWh'),
                        ),
                        _BillingRow(
                          label: 'Energy charges',
                          value: _currency(receipt.subtotal),
                        ),
                        _BillingRow(
                          label: 'Taxes',
                          value: _currency(receipt.taxAmount),
                        ),
                        _BillingRow(
                          label: 'Service fee',
                          value: _currency(receipt.serviceFee),
                        ),
                        const Divider(height: 28),
                        _BillingRow(
                          label: 'Total amount',
                          value: _currency(receipt.amount),
                          emphasized: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ReceiptPanel(
                    child: Column(
                      children: [
                        _StatusRow(
                          icon: receipt.paymentVerified
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          title: 'Payment status',
                          value: receipt.paymentVerified
                              ? 'Paid'
                              : 'Verification unavailable',
                          positive: receipt.paymentVerified,
                        ),
                        const Divider(height: 28),
                        _ReceiptDetail(
                          label: 'Payment reference',
                          value: receipt.paymentReference,
                        ),
                        _ReceiptDetail(
                          label: 'Charging-session ID',
                          value: receipt.chargingSessionId,
                        ),
                        _ReceiptDetail(
                          label: 'Receipt ID',
                          value: receipt.id,
                        ),
                        _ReceiptDetail(
                          label: 'Payment method',
                          value: receipt.paymentMethod,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ReceiptPanel(
                    child: _StatusRow(
                      icon: _deliveryIcon,
                      title: 'Receipt delivery',
                      value: receipt.deliveryStatus,
                      positive: _deliverySucceeded,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isProductionVerified
                            ? Icons.verified_user_rounded
                            : Icons.science_outlined,
                        color: green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _isProductionVerified
                              ? 'Verified digital receipt'
                              : _isSandbox
                                  ? 'Sandbox receipt — no real payment was collected'
                                  : 'Saved charging receipt',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.station case final station?) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const Key('receiptStationFeedbackButton'),
                          onPressed: () => showStationFeedbackDialog(
                            context: context,
                            stationId: station.id,
                            stationName: station.name,
                            operatorName: station.network,
                            address: station.formattedAddress,
                            latitude: station.latitude,
                            longitude: station.longitude,
                            sourceNames: [station.dataSource],
                          ),
                          icon: const Icon(Icons.rate_review_outlined),
                          label: const Text(
                            'Share station feedback (optional)',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('receiptDoneButton'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Done'),
                      ),
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

  bool get _deliverySucceeded => receipt.deliveryAttempts.any(
        (attempt) => attempt.delivered,
      );

  IconData get _deliveryIcon {
    if (_deliverySucceeded) return Icons.mark_email_read_outlined;
    if (receipt.deliveryMethod == 'In app') return Icons.save_outlined;
    return Icons.schedule_send_outlined;
  }

  static String _currency(double value, {String suffix = ''}) =>
      '₹${value.toStringAsFixed(2)}$suffix';

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/${local.year} • $hour:$minute $period';
  }
}

class _SuccessSeal extends StatelessWidget {
  const _SuccessSeal();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF57DE80).withValues(alpha: 0.14),
            border: Border.all(color: const Color(0xFF57DE80), width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF57DE80).withValues(alpha: 0.25),
                blurRadius: 28,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 42,
            color: Color(0xFF57DE80),
          ),
        ),
      );
}

class _ReceiptPanel extends StatelessWidget {
  const _ReceiptPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF073349).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF2B6A70)),
        ),
        child: child,
      );
}

class _StationIllustration extends StatelessWidget {
  const _StationIllustration();

  @override
  Widget build(BuildContext context) => Container(
        width: 82,
        height: 96,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D6970), Color(0xFF052138)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.ev_station_rounded,
          size: 48,
          color: Color(0xFF57DE80),
        ),
      );
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: const Color(0xFF57DE80)),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFFB9C8D8)),
              ),
            ),
          ],
        ),
      );
}

class _BillingRow extends StatelessWidget {
  const _BillingRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: emphasized ? Colors.white : const Color(0xFFB9C8D8),
                  fontWeight: emphasized ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: emphasized ? const Color(0xFF57DE80) : Colors.white,
                fontSize: emphasized ? 20 : 15,
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _ReceiptDetail extends StatelessWidget {
  const _ReceiptDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 145,
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFFB9C8D8)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value.isEmpty ? 'Not available' : value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.positive,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  (positive ? const Color(0xFF57DE80) : const Color(0xFFFFC857))
                      .withValues(alpha: 0.14),
            ),
            child: Icon(
              icon,
              color:
                  positive ? const Color(0xFF57DE80) : const Color(0xFFFFC857),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Color(0xFFB9C8D8)),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: positive ? const Color(0xFF57DE80) : Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
