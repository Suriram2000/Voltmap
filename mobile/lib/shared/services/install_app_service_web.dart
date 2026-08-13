import 'dart:convert';
import 'dart:js_interop';

import 'install_app_models.dart';

@JS('voltMapEVInstallStatus')
external JSString _installStatus();

@JS('voltMapEVPromptInstall')
external JSPromise<JSString> _promptInstall();

Future<InstallAppStatus> getInstallStatus() async {
  final value = jsonDecode(_installStatus().toDart) as Map<String, dynamic>;
  return InstallAppStatus(
    platform: switch (value['platform']) {
      'ios' => InstallAppPlatform.ios,
      'android' => InstallAppPlatform.android,
      'desktop' => InstallAppPlatform.desktop,
      _ => InstallAppPlatform.other,
    },
    installed: value['installed'] == true,
    canPrompt: value['canPrompt'] == true,
  );
}

Future<InstallActionResult> promptInstall() async {
  final value = (await _promptInstall().toDart).toDart;
  return switch (value) {
    'accepted' => InstallActionResult.accepted,
    'dismissed' => InstallActionResult.dismissed,
    _ => InstallActionResult.unavailable,
  };
}
