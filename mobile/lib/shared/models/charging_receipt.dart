class ChargingReceipt {
  const ChargingReceipt({
    required this.id,
    required this.stationId,
    required this.stationName,
    required this.connectorType,
    required this.energyKwh,
    required this.amount,
    required this.paymentMethod,
    required this.createdAt,
  });

  final String id;
  final String stationId;
  final String stationName;
  final String connectorType;
  final double energyKwh;
  final double amount;
  final String paymentMethod;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'stationId': stationId,
    'stationName': stationName,
    'connectorType': connectorType,
    'energyKwh': energyKwh,
    'amount': amount,
    'paymentMethod': paymentMethod,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChargingReceipt.fromJson(Map<String, dynamic> json) {
    return ChargingReceipt(
      id: json['id'] as String,
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String,
      connectorType: json['connectorType'] as String,
      energyKwh: (json['energyKwh'] as num).toDouble(),
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
