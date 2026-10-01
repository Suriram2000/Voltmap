enum ChargingPaymentPlanKind {
  payAsYouCharge,
  budgetGuard,
}

/// A local driver preference for deciding the maximum amount to authorize for
/// one charging session. It is never a stored payment method or a recurring
/// billing agreement.
class ChargingPaymentPlan {
  const ChargingPaymentPlan({
    required this.kind,
    required this.maximumAmountInr,
  });

  static const defaultPlan = ChargingPaymentPlan(
    kind: ChargingPaymentPlanKind.payAsYouCharge,
    maximumAmountInr: 1000,
  );

  final ChargingPaymentPlanKind kind;
  final double maximumAmountInr;

  String get title => switch (kind) {
        ChargingPaymentPlanKind.payAsYouCharge => 'Pay after charging',
        ChargingPaymentPlanKind.budgetGuard => 'Charging budget guard',
      };

  String get summary => switch (kind) {
        ChargingPaymentPlanKind.payAsYouCharge =>
          'Pay only for verified energy delivered',
        ChargingPaymentPlanKind.budgetGuard =>
          'Keep each charging authorization within ₹${maximumAmountInr.toStringAsFixed(0)}',
      };

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'maximumAmountInr': maximumAmountInr,
      };

  factory ChargingPaymentPlan.fromJson(Map<String, dynamic> json) {
    final parsedKind = ChargingPaymentPlanKind.values.where(
      (value) => value.name == json['kind'],
    );
    final amount = (json['maximumAmountInr'] as num?)?.toDouble();
    if (parsedKind.isEmpty ||
        amount == null ||
        !amount.isFinite ||
        amount < 100) {
      return ChargingPaymentPlan.defaultPlan;
    }
    return ChargingPaymentPlan(
      kind: parsedKind.first,
      maximumAmountInr: amount,
    );
  }
}
