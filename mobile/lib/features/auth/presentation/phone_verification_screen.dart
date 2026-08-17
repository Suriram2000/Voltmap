import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/phone_otp_service.dart';
import '../../../shared/state/app_state.dart';

class PhoneVerificationScreen extends ConsumerStatefulWidget {
  const PhoneVerificationScreen({
    super.key,
    required this.feature,
    this.controller,
  });

  final String feature;
  final PhoneOtpController? controller;

  @override
  ConsumerState<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState
    extends ConsumerState<PhoneVerificationScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  late final PhoneOtpController _service;
  PhoneOtpChallenge? _challenge;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.controller ??
        (AppRuntimeConfig.isSandbox
            ? const PreviewPhoneOtpService()
            : ProductionPhoneOtpService());
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    return Scaffold(
      key: const Key('phoneVerificationScreen'),
      appBar: AppBar(title: const Text('Verify phone')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFECF8F1), Color(0xFFF7F9F5)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: challenge == null
                        ? _buildPhoneStep()
                        : _buildOtpStep(challenge),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Form(
      key: _phoneFormKey,
      child: Column(
        key: const ValueKey('phoneStep'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Icons.phone_android_rounded, 'Continue with phone'),
          const SizedBox(height: 12),
          Text(
            'India (${AppState.indiaDialCode}) is selected. Enter your 10-digit mobile number to use ${widget.feature}.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          TextFormField(
            key: const Key('otpPhoneField'),
            controller: _phoneController,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              hintText: '9392788714',
              prefixIcon: Icon(Icons.phone_outlined),
              prefixText: '${AppState.indiaDialCode} ',
              prefixStyle: TextStyle(fontWeight: FontWeight.w800),
              helperText: 'India selected. Enter the 10 digits after +91.',
            ),
            validator: (value) =>
                AppState.normalizeIndianMobile(value ?? '') == null
                    ? 'Enter a valid 10-digit India mobile number'
                    : null,
            onFieldSubmitted: (_) => _sendCode(),
          ),
          if (_error != null) _errorMessage(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('sendOtpButton'),
              onPressed: _submitting ? null : _sendCode,
              icon: _progressOr(const Icon(Icons.sms_outlined)),
              label: Text(_submitting ? 'Preparing code…' : 'Send OTP'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('appReviewDemoButton'),
              onPressed: _submitting ? null : _enterDemoAccount,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Explore with demo account'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'For App Review and feature evaluation. No SMS, real payment, or private account data is used.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          _OtpDisclosure(isPreview: AppRuntimeConfig.isSandbox),
        ],
      ),
    );
  }

  Widget _buildOtpStep(PhoneOtpChallenge challenge) {
    return Form(
      key: _otpFormKey,
      child: Column(
        key: const ValueKey('otpStep'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Icons.verified_user_outlined, 'Enter verification code'),
          const SizedBox(height: 12),
          Text(
            'Code for ${_maskedPhone(challenge.phoneNumber)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (challenge.previewCode != null) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('previewOtpNotice'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Preview code: ${challenge.previewCode}. SMS delivery is not connected in this static preview.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('otpCodeField'),
            controller: _otpController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: '6-digit OTP',
              hintText: '123456',
              prefixIcon: Icon(Icons.password_rounded),
            ),
            validator: (value) =>
                value?.length == 6 ? null : 'Enter the complete 6-digit code',
            onFieldSubmitted: (_) => _verifyCode(challenge),
          ),
          if (_error != null) _errorMessage(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('verifyOtpButton'),
              onPressed: _submitting ? null : () => _verifyCode(challenge),
              icon: _progressOr(const Icon(Icons.check_circle_outline)),
              label: Text(_submitting ? 'Verifying…' : 'Verify & continue'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              key: const Key('changeOtpPhoneButton'),
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                        _challenge = null;
                        _otpController.clear();
                        _error = null;
                      }),
              child: const Text('Change phone number'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppTheme.brandLime,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(icon, color: AppTheme.brandNavy),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
      ],
    );
  }

  Widget _progressOr(Widget icon) => _submitting
      ? const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : icon;

  Widget _errorMessage() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          _error!,
          key: const Key('phoneOtpError'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    final phone = AppState.normalizeIndianMobile(_phoneController.text)!;
    setState(() => _submitting = true);
    try {
      final challenge = await _service.sendCode(phone);
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = AppRuntimeConfig.hasSecureIdentityBackend
            ? error.toString()
            : 'OTP service is not configured yet. No SMS was sent.';
      });
    }
  }

  Future<void> _enterDemoAccount() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    await ref.read(appStateProvider).enterDemoAccount();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _verifyCode(PhoneOtpChallenge challenge) async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_otpFormKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    bool verified;
    try {
      verified = await _service.verifyCode(
        challenge: challenge,
        code: _otpController.text,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
      return;
    }
    if (!mounted) return;
    if (!verified) {
      setState(() {
        _submitting = false;
        _error = 'That OTP is incorrect. Check the code and try again.';
      });
      return;
    }

    final error = await ref
        .read(appStateProvider)
        .completePhoneVerification(challenge.phoneNumber);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  String _maskedPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '${AppState.indiaDialCode} ••••••${digits.substring(digits.length - 4)}';
  }
}

class _OtpDisclosure extends StatelessWidget {
  const _OtpDisclosure({required this.isPreview});

  final bool isPreview;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isPreview
                ? 'Sandbox preview: the code is shown on screen and no SMS is sent.'
                : AppRuntimeConfig.hasSecureIdentityBackend
                    ? 'A time-limited verification code will be sent by the secure VoltMapEV identity service.'
                    : 'Real SMS verification is unavailable until the production identity service is configured.',
          ),
        ),
      ],
    );
  }
}
