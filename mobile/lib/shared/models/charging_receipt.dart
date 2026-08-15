class ReceiptDeliveryAttempt {
  const ReceiptDeliveryAttempt({
    required this.channel,
    required this.destination,
    required this.status,
    required this.attemptedAt,
    required this.attemptNumber,
    this.errorCode,
  });

  final String channel;
  final String destination;
  final String status;
  final DateTime attemptedAt;
  final int attemptNumber;
  final String? errorCode;

  bool get delivered => status == 'delivered';

  Map<String, dynamic> toJson() => {
        'channel': channel,
        'destination': destination,
        'status': status,
        'attemptedAt': attemptedAt.toIso8601String(),
        'attemptNumber': attemptNumber,
        if (errorCode != null) 'errorCode': errorCode,
      };

  factory ReceiptDeliveryAttempt.fromJson(Map<String, dynamic> json) {
    return ReceiptDeliveryAttempt(
      channel: json['channel'] as String? ?? 'app',
      destination: json['destination'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      attemptedAt: DateTime.tryParse(json['attemptedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      attemptNumber: (json['attemptNumber'] as num?)?.toInt() ?? 1,
      errorCode: json['errorCode'] as String?,
    );
  }
}

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
    this.ratePerKwh = 0,
    this.energySubtotal,
    this.taxAmount = 0,
    this.serviceFee = 0,
    this.paymentReference = '',
    this.chargingSessionId = '',
    this.paymentVerified = false,
    this.meterReadingConfirmed = false,
    this.environment = 'legacy',
    this.customerPhone,
    this.customerEmail,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.deliveryMethod = 'In app',
    this.deliveryDestination,
    this.deliveryStatus = 'Saved in app',
    this.deliveryAttempts = const [],
  });

  final String id;
  final String stationId;
  final String stationName;
  final String connectorType;
  final double energyKwh;
  final double ratePerKwh;
  final double? energySubtotal;
  final double taxAmount;
  final double serviceFee;
  final double amount;
  final String paymentMethod;
  final String paymentReference;
  final String chargingSessionId;
  final bool paymentVerified;
  final bool meterReadingConfirmed;
  final String environment;
  final DateTime createdAt;
  final String? customerPhone;
  final String? customerEmail;
  final bool phoneVerified;
  final bool emailVerified;
  final String deliveryMethod;
  final String? deliveryDestination;
  final String deliveryStatus;
  final List<ReceiptDeliveryAttempt> deliveryAttempts;

  double get subtotal => energySubtotal ?? energyKwh * ratePerKwh;

  bool get isVerifiedSuccessful =>
      environment == 'production' &&
      paymentVerified &&
      meterReadingConfirmed &&
      paymentReference.isNotEmpty;

  String toPlainText() {
    final buffer = StringBuffer()
      ..writeln('VoltMapEV payment receipt')
      ..writeln('Receipt: $id')
      ..writeln('Charging session: $chargingSessionId')
      ..writeln('Environment: $environment')
      ..writeln('Date: ${createdAt.toUtc().toIso8601String()}')
      ..writeln('Station: $stationName ($stationId)')
      ..writeln('Charger: $connectorType')
      ..writeln('Units consumed: ${energyKwh.toStringAsFixed(2)} kWh')
      ..writeln('Rate per unit: INR ${ratePerKwh.toStringAsFixed(2)}/kWh')
      ..writeln('Energy subtotal: INR ${subtotal.toStringAsFixed(2)}')
      ..writeln('Taxes: INR ${taxAmount.toStringAsFixed(2)}')
      ..writeln('Service fee: INR ${serviceFee.toStringAsFixed(2)}')
      ..writeln('Total amount: INR ${amount.toStringAsFixed(2)}')
      ..writeln('Payment reference: $paymentReference')
      ..writeln('Payment method: $paymentMethod')
      ..writeln('Payment verified: ${paymentVerified ? 'Yes' : 'No'}')
      ..writeln(
          'Meter reading confirmed: ${meterReadingConfirmed ? 'Yes' : 'No'}')
      ..writeln('Delivery: $deliveryStatus');
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stationId': stationId,
        'stationName': stationName,
        'connectorType': connectorType,
        'energyKwh': energyKwh,
        'ratePerKwh': ratePerKwh,
        'energySubtotal': subtotal,
        'taxAmount': taxAmount,
        'serviceFee': serviceFee,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
        'chargingSessionId': chargingSessionId,
        'paymentVerified': paymentVerified,
        'meterReadingConfirmed': meterReadingConfirmed,
        'environment': environment,
        'createdAt': createdAt.toIso8601String(),
        if (customerPhone != null) 'customerPhone': customerPhone,
        if (customerEmail != null) 'customerEmail': customerEmail,
        'phoneVerified': phoneVerified,
        'emailVerified': emailVerified,
        'deliveryMethod': deliveryMethod,
        if (deliveryDestination != null)
          'deliveryDestination': deliveryDestination,
        'deliveryStatus': deliveryStatus,
        'deliveryAttempts': deliveryAttempts
            .map((attempt) => attempt.toJson())
            .toList(growable: false),
      };

  factory ChargingReceipt.fromJson(Map<String, dynamic> json) {
    final attempts = (json['deliveryAttempts'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ReceiptDeliveryAttempt.fromJson)
        .toList(growable: false);
    return ChargingReceipt(
      id: json['id'] as String,
      stationId: json['stationId'] as String,
      stationName: json['stationName'] as String,
      connectorType: json['connectorType'] as String,
      energyKwh: (json['energyKwh'] as num).toDouble(),
      ratePerKwh: (json['ratePerKwh'] as num?)?.toDouble() ?? 0,
      energySubtotal: (json['energySubtotal'] as num?)?.toDouble(),
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      serviceFee: (json['serviceFee'] as num?)?.toDouble() ?? 0,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String,
      paymentReference: json['paymentReference'] as String? ?? '',
      chargingSessionId: json['chargingSessionId'] as String? ?? '',
      paymentVerified: json['paymentVerified'] as bool? ?? false,
      meterReadingConfirmed: json['meterReadingConfirmed'] as bool? ?? false,
      environment: json['environment'] as String? ?? 'legacy',
      createdAt: DateTime.parse(json['createdAt'] as String),
      customerPhone: json['customerPhone'] as String?,
      customerEmail: json['customerEmail'] as String?,
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      emailVerified: json['emailVerified'] as bool? ?? false,
      deliveryMethod: json['deliveryMethod'] as String? ?? 'In app',
      deliveryDestination: json['deliveryDestination'] as String?,
      deliveryStatus: json['deliveryStatus'] as String? ?? 'Saved in app',
      deliveryAttempts: attempts,
    );
  }
}
