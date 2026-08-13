import 'install_app_models.dart';
import 'install_app_service_stub.dart'
    if (dart.library.js_interop) 'install_app_service_web.dart'
    as implementation;

abstract interface class InstallAppController {
  Future<InstallAppStatus> getStatus();

  Future<InstallActionResult> promptInstall();
}

class InstallAppService implements InstallAppController {
  const InstallAppService();

  @override
  Future<InstallAppStatus> getStatus() => implementation.getInstallStatus();

  @override
  Future<InstallActionResult> promptInstall() => implementation.promptInstall();
}
