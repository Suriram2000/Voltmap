enum ChargingWalletTransactionType {
  topUp,
  authorizationHold,
  chargingDebit,
  refund,
  adjustment,
}

/// A server-authoritative wallet record. This model deliberately carries no
/// payment instrument data: card numbers, UPI PINs, and provider secrets stay
/// with the payment provider and VoltMapEV payment service.
class ChargingWalletTransaction {
  const ChargingWalletTransaction({
    required this.id,
    required this.type,
    required this.amountInr,
    required this.createdAt,
    required this.status,
    this.description,
    this.chargingSessionId,
  });

  final String id;
  final ChargingWalletTransactionType type;
  final double amountInr;
  final DateTime createdAt;
  final String status;
  final String? description;
  final String? chargingSessionId;

  bool get isCredit =>
      type == ChargingWalletTransactionType.topUp ||
      type == ChargingWalletTransactionType.refund ||
      type == ChargingWalletTransactionType.adjustment && amountInr >= 0;

  factory ChargingWalletTransaction.fromJson(Map<String, dynamic> json) {
    final type = ChargingWalletTransactionType.values.where(
      (value) => value.name == json['type'],
    );
    final amount = (json['amountInr'] as num?)?.toDouble();
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final id = json['id'] as String?;
    final status = json['status'] as String?;
    if (type.isEmpty ||
        amount == null ||
        !amount.isFinite ||
        createdAt == null ||
        id == null ||
        id.isEmpty ||
        status == null ||
        status.isEmpty) {
      throw const FormatException('Invalid wallet transaction.');
    }
    return ChargingWalletTransaction(
      id: id,
      type: type.first,
      amountInr: amount,
      createdAt: createdAt,
      status: status,
      description: json['description'] as String?,
      chargingSessionId: json['chargingSessionId'] as String?,
    );
  }
}

class ChargingWalletSnapshot {
  const ChargingWalletSnapshot({
    required this.currency,
    required this.availableBalanceInr,
    required this.reservedBalanceInr,
    required this.updatedAt,
    required this.transactions,
  });

  final String currency;
  final double availableBalanceInr;
  final double reservedBalanceInr;
  final DateTime updatedAt;
  final List<ChargingWalletTransaction> transactions;

  double get totalBalanceInr => availableBalanceInr + reservedBalanceInr;

  factory ChargingWalletSnapshot.fromJson(Map<String, dynamic> json) {
    final currency = json['currency'] as String?;
    final available = (json['availableBalanceInr'] as num?)?.toDouble();
    final reserved = (json['reservedBalanceInr'] as num?)?.toDouble();
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    final transactionsJson = json['transactions'];
    if (currency != 'INR' ||
        available == null ||
        reserved == null ||
        !available.isFinite ||
        !reserved.isFinite ||
        available < 0 ||
        reserved < 0 ||
        updatedAt == null ||
        transactionsJson is! List) {
      throw const FormatException('Invalid wallet balance.');
    }
    return ChargingWalletSnapshot(
      currency: 'INR',
      availableBalanceInr: available,
      reservedBalanceInr: reserved,
      updatedAt: updatedAt,
      transactions: transactionsJson
          .map((item) => ChargingWalletTransaction.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(growable: false),
    );
  }
}

class ChargingWalletTopUp {
  const ChargingWalletTopUp({
    required this.id,
    required this.checkoutUrl,
    required this.expiresAt,
  });

  final String id;
  final Uri checkoutUrl;
  final DateTime expiresAt;
}
