import 'secure_identity_api.dart';

class PhoneOtpChallenge {
  const PhoneOtpChallenge({
    required this.id,
    required this.phoneNumber,
    required this.expiresAt,
    required this.resendAt,
    required this.attemptsRemaining,
    this.previewCode,
  });

  final String id;
  final String phoneNumber;
  final DateTime expiresAt;
  final DateTime resendAt;
  final int attemptsRemaining;
  final String? previewCode;
}

abstract interface class PhoneOtpController {
  Future<PhoneOtpChallenge> sendCode(String phoneNumber);

  Future<bool> verifyCode({
    required PhoneOtpChallenge challenge,
    required String code,
  });
}

/// Local preview used until a hosted SMS authentication provider is connected.
/// It never claims to send a real text message and must not be treated as
/// production identity verification.
class PreviewPhoneOtpService implements PhoneOtpController {
  const PreviewPhoneOtpService();

  static const previewCode = '123456';

  @override
  Future<PhoneOtpChallenge> sendCode(String phoneNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final now = DateTime.now();
    return PhoneOtpChallenge(
      id: 'preview-$phoneNumber',
      phoneNumber: phoneNumber,
      expiresAt: now.add(const Duration(minutes: 5)),
      resendAt: now.add(const Duration(seconds: 30)),
      attemptsRemaining: 5,
      previewCode: previewCode,
    );
  }

  @override
  Future<bool> verifyCode({
    required PhoneOtpChallenge challenge,
    required String code,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return challenge.id == 'preview-${challenge.phoneNumber}' &&
        code.trim() == previewCode;
  }
}

/// Production adapter for real, server-issued India phone OTP challenges.
class ProductionPhoneOtpService implements PhoneOtpController {
  ProductionPhoneOtpService({SecureIdentityApi? api})
      : _api = api ?? SecureIdentityApi();

  final SecureIdentityApi _api;
  final Map<String, ContactOtpChallenge> _challenges = {};

  @override
  Future<PhoneOtpChallenge> sendCode(String phoneNumber) async {
    final secureChallenge = await _api.sendOtp(
      channel: 'sms',
      destination: phoneNumber,
      purpose: 'account_sign_in',
    );
    _challenges[secureChallenge.id] = secureChallenge;
    return PhoneOtpChallenge(
      id: secureChallenge.id,
      phoneNumber: secureChallenge.destination,
      expiresAt: secureChallenge.expiresAt,
      resendAt: secureChallenge.resendAt,
      attemptsRemaining: secureChallenge.attemptsRemaining,
    );
  }

  @override
  Future<bool> verifyCode({
    required PhoneOtpChallenge challenge,
    required String code,
  }) async {
    final secureChallenge = _challenges[challenge.id];
    if (secureChallenge == null) return false;
    await _api.verifyOtp(challenge: secureChallenge, code: code);
    _challenges.remove(challenge.id);
    return true;
  }
}
