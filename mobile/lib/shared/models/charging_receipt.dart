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
    this.customerPhone,
    this.deliveryMethod = 'In app',
    this.deliveryDestination,
    this.deliveryStatus = 'Saved in app',
  });

  final String id;
  final String stationId;
  final String stationName;
  final String connectorType;
  final double energyKwh;
  final double amount;
  final String paymentMethod;
  final DateTime createdAt;
  final String? customerPhone;
  final String deliveryMethod;
  final String? deliveryDestination;
  final String deliveryStatus;

  Map<String, dynamic> toJson() => {
        'id': id,
        'stationId': stationId,
        'stationName': stationName,
        'connectorType': connectorType,
        'energyKwh': energyKwh,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'createdAt': createdAt.toIso8601String(),
        if (customerPhone != null) 'customerPhone': customerPhone,
        'deliveryMethod': deliveryMethod,
        if (deliveryDestination != null)
          'deliveryDestination': deliveryDestination,
        'deliveryStatus': deliveryStatus,
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
      customerPhone: json['customerPhone'] as String?,
      deliveryMethod: json['deliveryMethod'] as String? ?? 'In app',
      deliveryDestination: json['deliveryDestination'] as String?,
      deliveryStatus: json['deliveryStatus'] as String? ?? 'Saved in app',
    );
  }
}
