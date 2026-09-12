/// A production session snapshot supplied by the charging server, never a
/// locally simulated timer or a payment-provider redirect.
class ChargingSessionStatus {
  const ChargingSessionStatus({
    required this.sessionId,
    required this.stationId,
    required this.status,
    required this.energyKwh,
    required this.ratePerKwh,
    required this.energySubtotal,
    required this.taxAmount,
    required this.serviceFee,
    required this.totalAmount,
    required this.updatedAt,
  });

  final String sessionId;
  final String stationId;
  final String status;
  final double energyKwh;
  final double ratePerKwh;
  final double energySubtotal;
  final double taxAmount;
  final double serviceFee;
  final double totalAmount;
  final DateTime updatedAt;

  bool get isComplete => status == 'completed';
  bool isStale(DateTime now) => now.difference(updatedAt).inSeconds > 60;

  String get label => switch (status) {
        'awaiting_payment' => 'Waiting for payment confirmation',
        'ready' => 'Ready at the charger',
        'charging' => 'Charging in progress',
        'stopping' => 'Waiting for charger to stop',
        'completed' => 'Charging complete',
        'failed' => 'Charging interrupted',
        _ => 'Waiting for operator update',
      };

  factory ChargingSessionStatus.fromJson(Map<String, dynamic> json) {
    const states = {
      'awaiting_payment',
      'ready',
      'charging',
      'stopping',
      'completed',
      'failed',
    };
    final status = json['status'];
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (json['environment'] != 'production' ||
        json['currency'] != 'INR' ||
        !states.contains(status) ||
        updatedAt == null ||
        updatedAt.isAfter(DateTime.now().add(const Duration(minutes: 1))) ||
        json['sessionId'] is! String ||
        (json['sessionId'] as String).isEmpty ||
        json['stationId'] is! String ||
        (json['stationId'] as String).isEmpty ||
        ({'charging', 'stopping', 'completed'}.contains(status) &&
            json['meterReadingConfirmed'] != true)) {
      throw const FormatException('Unverified charging session update.');
    }
    double number(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite || value < 0) {
        throw FormatException('Invalid session $key.');
      }
      return value.toDouble();
    }

    final energy = number('energyKwh');
    final rate = number('ratePerKwh');
    final subtotal = number('energySubtotal');
    final tax = number('taxAmount');
    final fee = number('serviceFee');
    final total = number('totalAmount');
    if ((subtotal - energy * rate).abs() > 0.02 ||
        (total - subtotal - tax - fee).abs() > 0.02) {
      throw const FormatException(
          'Session totals do not match the meter and tariff.');
    }
    return ChargingSessionStatus(
      sessionId: json['sessionId'] as String,
      stationId: json['stationId'] as String,
      status: status as String,
      energyKwh: energy,
      ratePerKwh: rate,
      energySubtotal: subtotal,
      taxAmount: tax,
      serviceFee: fee,
      totalAmount: total,
      updatedAt: updatedAt,
    );
  }
}
