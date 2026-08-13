enum InstallAppPlatform { ios, android, desktop, nativeApp, other }

enum InstallActionResult { accepted, dismissed, unavailable }

class InstallAppStatus {
  const InstallAppStatus({
    required this.platform,
    required this.installed,
    required this.canPrompt,
  });

  const InstallAppStatus.native()
      : platform = InstallAppPlatform.nativeApp,
        installed = true,
        canPrompt = false;

  final InstallAppPlatform platform;
  final bool installed;
  final bool canPrompt;
}
