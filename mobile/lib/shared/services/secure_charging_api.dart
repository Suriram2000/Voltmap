import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_environment.dart';
import '../models/charging_receipt.dart';

class SecureChargingApiException implements Exception {
  const SecureChargingApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class ChargingAuthorization {
  const ChargingAuthorization({
    required this.sessionId,
    required this.checkoutUrl,
    required this.expiresAt,
    required this.idempotencyKey,
  });

  final String sessionId;
  final Uri checkoutUrl;
  final DateTime expiresAt;
  final String idempotencyKey;
}

/// Client for the VoltMapEV server. Provider secrets, raw card data, CVVs, UPI
/// PINs and webhook signing secrets must exist only behind this API.
class SecureChargingApi {
  SecureChargingApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUri = Uri.parse(
          baseUrl ?? AppRuntimeConfig.paymentApiBaseUrl,
        );

  final http.Client _client;
  final Uri _baseUri;

  Future<ChargingAuthorization> authorizeSession({
    required String stationId,
    required String chargerId,
    required double approvedEnergyLimitKwh,
    required double disclosedRatePerKwh,
    required double disclosedTaxRate,
    required double disclosedServiceFee,
    required String verifiedContactToken,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      _endpoint('/v1/charging-sessions/authorize'),
      headers: _headers(idempotencyKey),
      body: jsonEncode({
        'stationId': stationId,
        'chargerId': chargerId,
        'approvedEnergyLimitKwh': approvedEnergyLimitKwh,
        'disclosedRatePerKwh': disclosedRatePerKwh,
        'disclosedTaxRate': disclosedTaxRate,
        'disclosedServiceFee': disclosedServiceFee,
        'verifiedContactToken': verifiedContactToken,
      }),
    );
    final body = _validatedBody(response);
    final checkoutUrl = Uri.tryParse(body['checkoutUrl'] as String? ?? '');
    if (checkoutUrl == null || checkoutUrl.scheme != 'https') {
      throw const SecureChargingApiException(
        'The secure payment provider returned an invalid checkout URL.',
        code: 'invalid_checkout_url',
      );
    }
    return ChargingAuthorization(
      sessionId: _requiredString(body, 'sessionId'),
      checkoutUrl: checkoutUrl,
      expiresAt: DateTime.parse(_requiredString(body, 'expiresAt')),
      idempotencyKey: idempotencyKey,
    );
  }

  /// Returns a receipt only after the server confirms the final meter reading
  /// and a provider-signed webhook. A client redirect is never proof of payment.
  Future<ChargingReceipt?> verifiedReceipt(String sessionId) async {
    final response = await _client.get(
      _endpoint('/v1/charging-sessions/$sessionId/receipt'),
      headers: const {'accept': 'application/json'},
    );
    if (response.statusCode == 202 || response.statusCode == 404) return null;
    final body = _validatedBody(response);
    final receipt = ChargingReceipt.fromJson(body);
    if (!receipt.isVerifiedSuccessful || receipt.environment != 'production') {
      throw const SecureChargingApiException(
        'The server did not provide a verified production receipt.',
        code: 'unverified_receipt',
      );
    }
    return receipt;
  }

  Future<void> retryReceiptDelivery({
    required String receiptId,
    required String channel,
  }) async {
    final response = await _client.post(
      _endpoint('/v1/receipts/$receiptId/deliveries/retry'),
      headers: _headers('receipt-retry-$receiptId-$channel'),
      body: jsonEncode({'channel': channel}),
    );
    _validatedBody(response);
  }

  Future<void> requestRefund({
    required String paymentReference,
    required String reason,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      _endpoint('/v1/payments/$paymentReference/refunds'),
      headers: _headers(idempotencyKey),
      body: jsonEncode({'reason': reason}),
    );
    _validatedBody(response);
  }

  Uri _endpoint(String path) {
    if (_baseUri.scheme != 'https' || _baseUri.host.isEmpty) {
      throw const SecureChargingApiException(
        'Secure payment service is not configured.',
        code: 'payment_backend_unavailable',
      );
    }
    return _baseUri.resolve(path);
  }

  static Map<String, String> _headers(String idempotencyKey) => {
        'accept': 'application/json',
        'content-type': 'application/json',
        'idempotency-key': idempotencyKey,
      };

  static Map<String, dynamic> _validatedBody(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const SecureChargingApiException(
        'The payment service returned an unreadable response.',
        code: 'invalid_response',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SecureChargingApiException(
        body['message'] as String? ??
            'The payment service rejected the request.',
        code: body['code'] as String?,
      );
    }
    return body;
  }

  static String _requiredString(Map<String, dynamic> body, String key) {
    final value = body[key] as String?;
    if (value == null || value.isEmpty) {
      throw SecureChargingApiException(
        'The payment service response is missing $key.',
        code: 'invalid_response',
      );
    }
    return value;
  }
}
