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

  static const monitoringDsn = String.fromEnvironment(
    'VOLTMAP_MONITORING_DSN',
  );

  static bool get isSandbox => environment == AppEnvironment.sandbox;

  static bool get hasSecurePaymentBackend {
    if (isSandbox || paymentApiBaseUrl.isEmpty) return false;
    final uri = Uri.tryParse(paymentApiBaseUrl);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
