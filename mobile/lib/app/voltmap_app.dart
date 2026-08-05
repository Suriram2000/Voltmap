import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../features/shell/presentation/app_shell.dart';

class VoltMapApp extends StatelessWidget {
  const VoltMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoltMap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}
