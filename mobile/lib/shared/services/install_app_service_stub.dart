import 'install_app_models.dart';

Future<InstallAppStatus> getInstallStatus() async =>
    const InstallAppStatus.native();

Future<InstallActionResult> promptInstall() async =>
    InstallActionResult.unavailable;
