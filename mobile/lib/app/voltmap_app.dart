import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../features/shell/presentation/app_shell.dart';
import '../shared/state/app_state.dart';

class VoltMapApp extends ConsumerWidget {
  const VoltMapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    return MaterialApp(
      title: 'VoltMapEV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: appState.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: !appState.isReady ? const _AppLoadingScreen() : const AppShell(),
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox.square(
          dimension: 34,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
