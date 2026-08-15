import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_environment.dart';

class SecureIdentityApiException implements Exception {
  const SecureIdentityApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class ContactOtpChallenge {
  const ContactOtpChallenge({
    required this.id,
    required this.channel,
    required this.destination,
    required this.expiresAt,
  });

  final String id;
  final String channel;
  final String destination;
  final DateTime expiresAt;
}

class VerifiedContact {
  const VerifiedContact({
    required this.token,
    required this.channel,
    required this.destination,
  });

  final String token;
  final String channel;
  final String destination;
}

/// Calls the VoltMapEV identity server. SMS and email provider credentials,
/// OTP values, rate limits and abuse controls live only behind this API.
class SecureIdentityApi {
  SecureIdentityApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUri = Uri.parse(baseUrl ?? AppRuntimeConfig.identityApiBaseUrl);

  final http.Client _client;
  final Uri _baseUri;

  Future<ContactOtpChallenge> sendOtp({
    required String channel,
    required String destination,
    required String purpose,
  }) async {
    final response = await _client.post(
      _endpoint('/v1/identity/otp/challenges'),
      headers: const {
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'channel': channel,
        'destination': destination,
        'purpose': purpose,
      }),
    );
    final body = _validatedBody(response);
    return ContactOtpChallenge(
      id: _requiredString(body, 'challengeId'),
      channel: channel,
      destination: _requiredString(body, 'destination'),
      expiresAt: DateTime.parse(_requiredString(body, 'expiresAt')),
    );
  }

  Future<VerifiedContact> verifyOtp({
    required ContactOtpChallenge challenge,
    required String code,
  }) async {
    final response = await _client.post(
      _endpoint('/v1/identity/otp/challenges/${challenge.id}/verify'),
      headers: const {
        'accept': 'application/json',
        'content-type': 'application/json',
      },
      body: jsonEncode({'code': code}),
    );
    final body = _validatedBody(response);
    if (body['verified'] != true) {
      throw const SecureIdentityApiException(
        'The verification code was not accepted.',
        code: 'otp_not_verified',
      );
    }
    return VerifiedContact(
      token: _requiredString(body, 'verifiedContactToken'),
      channel: challenge.channel,
      destination: _requiredString(body, 'destination'),
    );
  }

  Uri _endpoint(String path) {
    if (_baseUri.scheme != 'https' || _baseUri.host.isEmpty) {
      throw const SecureIdentityApiException(
        'Phone and email verification is not configured.',
        code: 'identity_backend_unavailable',
      );
    }
    return _baseUri.resolve(path);
  }

  static Map<String, dynamic> _validatedBody(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const SecureIdentityApiException(
        'The verification service returned an unreadable response.',
        code: 'invalid_response',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SecureIdentityApiException(
        body['message'] as String? ?? 'The verification request failed.',
        code: body['code'] as String?,
      );
    }
    return body;
  }

  static String _requiredString(Map<String, dynamic> body, String key) {
    final value = body[key] as String?;
    if (value == null || value.isEmpty) {
      throw SecureIdentityApiException(
        'The verification response is missing $key.',
        code: 'invalid_response',
      );
    }
    return value;
  }
}
