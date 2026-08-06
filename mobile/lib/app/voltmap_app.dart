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
      title: 'VoltMap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: appState.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AppShell(),
    );
  }
}
