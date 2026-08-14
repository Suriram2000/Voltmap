import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voltmap/features/install/presentation/install_app_screen.dart';
import 'package:voltmap/features/shell/presentation/app_shell.dart';
import 'package:voltmap/shared/services/install_app_models.dart';
import 'package:voltmap/shared/services/install_app_service.dart';

void main() {
  testWidgets('iPhone users receive accurate Safari home-screen steps', (
    tester,
  ) async {
    final controller = _FakeInstallController(
      const InstallAppStatus(
        platform: InstallAppPlatform.ios,
        installed: false,
        canPrompt: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: InstallAppScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Install on iPhone or iPad'), findsOneWidget);
    expect(find.textContaining('Share button'), findsOneWidget);
    expect(find.textContaining('Add to Home Screen'), findsOneWidget);
    expect(find.textContaining('Open as Web App'), findsOneWidget);
    expect(find.byKey(const Key('installVoltMapEVButton')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('checkInstallAvailabilityButton')),
      220,
    );
    expect(
      find.byKey(const Key('checkInstallAvailabilityButton')),
      findsOneWidget,
    );
  });

  testWidgets('Android install prompt reports acceptance and installed state', (
    tester,
  ) async {
    final controller = _FakeInstallController(
      const InstallAppStatus(
        platform: InstallAppPlatform.android,
        installed: false,
        canPrompt: true,
      ),
      result: InstallActionResult.accepted,
    );

    await tester.pumpWidget(
      MaterialApp(home: InstallAppScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Install on Android'), findsOneWidget);
    await tester.tap(find.byKey(const Key('installVoltMapEVButton')));
    await tester.pumpAndSettle();

    expect(controller.promptCount, 1);
    expect(find.text('VoltMapEV installation started.'), findsOneWidget);
    expect(find.byKey(const Key('voltmapevInstalledBadge')), findsOneWidget);
  });

  testWidgets('native app correctly reports that it is already installed', (
    tester,
  ) async {
    final controller = _FakeInstallController(
      const InstallAppStatus.native(),
    );

    await tester.pumpWidget(
      MaterialApp(home: InstallAppScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('voltmapevInstalledBadge')), findsOneWidget);
    expect(find.byKey(const Key('installVoltMapEVButton')), findsNothing);
    expect(
      find.byKey(const Key('checkInstallAvailabilityButton')),
      findsNothing,
    );
  });

  testWidgets('install suggestion appears at the bottom after startup', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = _FakeInstallController(
      const InstallAppStatus(
        platform: InstallAppPlatform.android,
        installed: false,
        canPrompt: true,
      ),
      result: InstallActionResult.accepted,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: AppShell(installController: controller)),
      ),
    );
    expect(find.byKey(const Key('installAppBottomBanner')), findsNothing);

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('installAppBottomBanner')), findsOneWidget);
    expect(find.text('Faster access from your home screen'), findsOneWidget);

    await tester.tap(find.byKey(const Key('installAppBottomButton')));
    await tester.pumpAndSettle();
    expect(controller.promptCount, 1);
    expect(find.byKey(const Key('installAppBottomBanner')), findsNothing);
  });
}

class _FakeInstallController implements InstallAppController {
  _FakeInstallController(
    this.status, {
    this.result = InstallActionResult.unavailable,
  });

  InstallAppStatus status;
  final InstallActionResult result;
  int promptCount = 0;

  @override
  Future<InstallAppStatus> getStatus() async => status;

  @override
  Future<InstallActionResult> promptInstall() async {
    promptCount += 1;
    if (result == InstallActionResult.accepted) {
      status = InstallAppStatus(
        platform: status.platform,
        installed: true,
        canPrompt: false,
      );
    }
    return result;
  }
}
