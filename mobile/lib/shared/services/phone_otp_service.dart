class PhoneOtpChallenge {
  const PhoneOtpChallenge({
    required this.id,
    required this.phoneNumber,
    this.previewCode,
  });

  final String id;
  final String phoneNumber;
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
    return PhoneOtpChallenge(
      id: 'preview-$phoneNumber',
      phoneNumber: phoneNumber,
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
