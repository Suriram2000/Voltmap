class ChargingBill {
  const ChargingBill({
    required this.unitsKwh,
    required this.ratePerKwh,
    required this.energySubtotal,
    required this.taxAmount,
    required this.serviceFee,
    required this.total,
  });

  final double unitsKwh;
  final double ratePerKwh;
  final double energySubtotal;
  final double taxAmount;
  final double serviceFee;
  final double total;
}

abstract final class ChargingBilling {
  static ChargingBill calculate({
    required double confirmedUnitsKwh,
    required double ratePerKwh,
    required double taxRate,
    required double serviceFee,
  }) {
    if (confirmedUnitsKwh < 0 ||
        ratePerKwh < 0 ||
        taxRate < 0 ||
        serviceFee < 0) {
      throw ArgumentError('Billing inputs cannot be negative.');
    }
    final units = _round(confirmedUnitsKwh, 3);
    final subtotal = _money(units * ratePerKwh);
    final tax = _money(subtotal * taxRate);
    final fee = _money(serviceFee);
    return ChargingBill(
      unitsKwh: units,
      ratePerKwh: _money(ratePerKwh),
      energySubtotal: subtotal,
      taxAmount: tax,
      serviceFee: fee,
      total: _money(subtotal + tax + fee),
    );
  }

  static double _money(double value) => _round(value, 2);

  static double _round(double value, int decimals) {
    final factor = switch (decimals) { 2 => 100, 3 => 1000, _ => 1 };
    return (value * factor).round() / factor;
  }
}
