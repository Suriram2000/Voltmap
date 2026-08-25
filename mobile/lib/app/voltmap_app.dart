import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/branding/app_brand.dart';
import '../core/theme/app_theme.dart';
import '../features/discovery/data/official_charger_search_service.dart';
import '../features/shell/presentation/app_shell.dart';
import '../shared/state/app_state.dart';

class VoltMapApp extends ConsumerWidget {
  const VoltMapApp({
    super.key,
    this.chargerDataService = const OfficialChargerSearchService(),
    this.autoLocateDiscoverOnOpen = true,
  });

  final OfficialChargerSearchService chargerDataService;
  final bool autoLocateDiscoverOnOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(
      appStateProvider.select(
        (state) => (isReady: state.isReady, darkMode: state.darkMode),
      ),
    );
    return MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      scrollBehavior: const VoltMapScrollBehavior(),
      home: !settings.isReady
          ? const _AppLoadingScreen()
          : AppShell(
              chargerDataService: chargerDataService,
              autoLocateDiscoverOnOpen: autoLocateDiscoverOnOpen,
            ),
    );
  }
}

class VoltMapScrollBehavior extends MaterialScrollBehavior {
  const VoltMapScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return switch (getPlatform(context)) {
      TargetPlatform.iOS || TargetPlatform.macOS => const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
      _ => const ClampingScrollPhysics(),
    };
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.brandNavy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.brandLime,
                borderRadius: BorderRadius.all(Radius.circular(22)),
              ),
              child: SizedBox.square(
                dimension: 72,
                child: Icon(
                  Icons.bolt_rounded,
                  color: AppTheme.brandNavy,
                  size: 44,
                ),
              ),
            ),
            SizedBox(height: 18),
            Text(
              AppBrand.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              AppBrand.tagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.brandLime,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 18),
            SizedBox(
              width: 130,
              child: LinearProgressIndicator(
                color: AppTheme.brandLime,
                backgroundColor: Color(0x3344D99A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
