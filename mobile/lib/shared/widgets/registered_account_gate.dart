import 'package:flutter/material.dart';

import '../../features/auth/presentation/phone_verification_screen.dart';
import '../state/app_state.dart';

Future<bool> requireRegisteredAccount(
  BuildContext context,
  AppState appState,
  String feature,
) async {
  if (appState.isRegisteredAccount) return true;

  final verified = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => PhoneVerificationScreen(feature: feature),
    ),
  );
  return verified == true && appState.isRegisteredAccount;
}
