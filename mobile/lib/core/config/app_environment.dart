enum AppEnvironment { sandbox, production }

abstract final class AppRuntimeConfig {
  static const _configuredEnvironment = String.fromEnvironment(
    'VOLTMAP_ENV',
  );

  /// Debug and test builds use the visibly labelled sandbox. Release builds
  /// default to production and therefore cannot expose simulated payments.
  static const environment = _configuredEnvironment == 'sandbox'
      ? AppEnvironment.sandbox
      : _configuredEnvironment == 'production'
          ? AppEnvironment.production
          : bool.fromEnvironment('dart.vm.product')
              ? AppEnvironment.production
              : AppEnvironment.sandbox;

  static const paymentApiBaseUrl = String.fromEnvironment(
    'VOLTMAP_PAYMENT_API_BASE_URL',
  );

  static const identityApiBaseUrl = String.fromEnvironment(
    'VOLTMAP_IDENTITY_API_BASE_URL',
  );

  static const realtimeChargerApiBaseUrl = String.fromEnvironment(
    'VOLTMAP_REALTIME_CHARGER_API_BASE_URL',
  );

  static const monitoringDsn = String.fromEnvironment(
    'VOLTMAP_MONITORING_DSN',
  );

  static bool get isSandbox => environment == AppEnvironment.sandbox;

  static bool get hasSecurePaymentBackend {
    return !isSandbox && _isSecureApiUrl(paymentApiBaseUrl);
  }

  static bool get hasSecureIdentityBackend {
    return !isSandbox && _isSecureApiUrl(identityApiBaseUrl);
  }

  static bool get hasRealtimeChargerBackend {
    return !isSandbox && _isSecureApiUrl(realtimeChargerApiBaseUrl);
  }

  static bool _isSecureApiUrl(String value) {
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host.endsWith('.localhost') ||
        host.endsWith('.test') ||
        host.endsWith('.example') ||
        host.endsWith('.invalid')) {
      return false;
    }
    return true;
  }
}
